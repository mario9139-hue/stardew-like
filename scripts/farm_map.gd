class_name FarmMap
extends TileMapLayer
## 草地・農地予定地・耕地の仮タイルで構成された農場マップと、マスごとの状態管理。
## マスの状態は cells(座標 → CellData)が正。タイルの見た目は状態から更新する。
## マップ内容は起動時に生成する(後でデータ駆動/保存データに置き換える想定)。

## マスの状態が変わったときに発行される
signal cell_changed(cell: Vector2i)
## 日が進んで、全マスの更新が終わったときに発行される
signal day_advanced
## 作物がモンスターに荒らされたときに発行される
signal crop_ruined(cell: Vector2i)

## タイルの種類 = TileSet のソース番号。素材は SpriteProvider の "tiles/<名前>" から取得する
const TILE_GRASS: int = 0
const TILE_FARMLAND: int = 1
const TILE_TILLED: int = 2
const TILE_TILLED_WET: int = 3
const TILE_NAMES: PackedStringArray = ["grass", "farmland", "tilled", "tilled_wet"]

## 農地予定地の見た目の範囲(セル単位)。状態は草地と同じで、耕せる
@export var farmland_rect: Rect2i = Rect2i(11, 3, 6, 5)

## マスごとの状態(座標 → 状態)
## ※Godot 4.3 では型付きDictionaryが使えないため、キーは Vector2i、値は CellData として扱う
var cells: Dictionary = {}


func _ready() -> void:
	add_to_group(&"farm_map")
	_build_tile_set()
	_build_map()


## マスの状態を返す。マップ外なら null
func get_cell_data(cell: Vector2i) -> CellData:
	return cells.get(cell)


## セーブ用: 草地のままで作物もないマスは省いた、マス状態の一覧
func export_state() -> Array:
	var result: Array = []
	for cell_key in cells.keys():
		var cell: Vector2i = cell_key
		var data: CellData = cells[cell]
		if data.soil == CellData.Soil.GRASS and not data.has_crop():
			continue
		result.append({
			"x": cell.x, "y": cell.y, "soil": int(data.soil),
			"crop": String(data.crop.id) if data.has_crop() else "",
			"growth_progress": data.growth_progress, "growth_bonus_days": data.growth_bonus_days,
			"quality": data.quality, "is_watered": data.is_watered,
		})
	return result


## ロード用: export_state の一覧を反映する。未知の作物 id はその作物だけスキップ(警告)
func import_state(entries: Array) -> void:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var cell: Vector2i = Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
		var data: CellData = get_cell_data(cell)
		if data == null:
			push_warning("FarmMap: マップ外のマスをスキップしました: %s" % cell)
			continue
		data.soil = CellData.Soil.TILLED if int(entry.get("soil", 0)) == int(CellData.Soil.TILLED) else CellData.Soil.GRASS
		data.is_watered = bool(entry.get("is_watered", false))
		data.crop = null
		data.growth_progress = 0
		data.growth_bonus_days = 0
		data.quality = 0
		var crop_id: String = String(entry.get("crop", ""))
		if crop_id != "":
			var crop: CropData = ItemRegistry.get_crop(StringName(crop_id))
			if crop == null:
				push_warning("FarmMap: 未知の作物 id をスキップしました: %s %s" % [crop_id, cell])
			else:
				data.crop = crop
				data.growth_progress = int(entry.get("growth_progress", 0))
				data.growth_bonus_days = int(entry.get("growth_bonus_days", 0))
				data.quality = int(entry.get("quality", 0))
		_refresh_cell(cell)
		cell_changed.emit(cell)


## 耕せるか(マップ内の草地状態のマスか)
func can_till(cell: Vector2i) -> bool:
	var data: CellData = get_cell_data(cell)
	return data != null and data.soil == CellData.Soil.GRASS


## 耕地に変更する。変更できたら true
func till(cell: Vector2i) -> bool:
	if not can_till(cell):
		return false
	cells[cell].soil = CellData.Soil.TILLED
	_refresh_cell(cell)
	cell_changed.emit(cell)
	return true


## 水やりできるか(耕地で、まだ水やり済みでないマスか)
func can_water(cell: Vector2i) -> bool:
	var data: CellData = get_cell_data(cell)
	return data != null and data.soil == CellData.Soil.TILLED and not data.is_watered


## 水やり済みにする。変更できたら true
func water(cell: Vector2i) -> bool:
	if not can_water(cell):
		return false
	cells[cell].is_watered = true
	_refresh_cell(cell)
	cell_changed.emit(cell)
	return true


## 種をまけるか(耕地で、まだ作物がないマスか)
func can_plant(cell: Vector2i) -> bool:
	var data: CellData = get_cell_data(cell)
	return data != null and data.soil == CellData.Soil.TILLED and not data.has_crop()


## 種をまく。まけたら true
func plant(cell: Vector2i, crop: CropData) -> bool:
	if crop == null or not can_plant(cell):
		return false
	var data: CellData = cells[cell]
	data.crop = crop
	data.growth_progress = 0
	data.growth_bonus_days = 0
	data.quality = 0
	cell_changed.emit(cell)
	return true


## モンスターに作物を荒らされる。マスは耕地(水やり前)に戻り、成長日数・成長ボーナス・品質は全て消える。
## 種は戻らない。荒らせたら true(作物がなければ false)
func ruin_crop(cell: Vector2i) -> bool:
	var data: CellData = get_cell_data(cell)
	if data == null or not data.has_crop():
		return false
	data.crop = null
	data.growth_progress = 0
	data.growth_bonus_days = 0
	data.quality = 0
	data.is_watered = false
	SeasonStats.add_ruined_crop()
	_refresh_cell(cell)
	cell_changed.emit(cell)
	crop_ruined.emit(cell)
	DebugFlags.log_effect("作物が荒らされた cell=%s / 今シーズンの荒らされた作物数: %d" % [cell, SeasonStats.ruined_crops])
	return true


## 収穫できるか(成長完了した作物があるマスか)
func can_harvest(cell: Vector2i) -> bool:
	var data: CellData = get_cell_data(cell)
	return data != null and data.is_harvestable()


## 収穫する。収穫した作物(CropData)を返し、収穫できなければ null
## - 単発の作物: 作物が消えて耕地に戻る
## - 再収穫の作物: 成長日数が「再収穫間隔の日数分だけ足りない状態」に戻る
func harvest(cell: Vector2i) -> CropData:
	if not can_harvest(cell):
		return null
	var data: CellData = cells[cell]
	var crop: CropData = data.crop
	if crop.regrow_days > 0:
		data.growth_progress = maxi(crop.growth_days - crop.regrow_days, 0)
	else:
		data.crop = null
		data.growth_progress = 0
	# 成長ボーナスと品質は収穫1回ぶん。再収穫作物にも持ち越さない。
	data.growth_bonus_days = 0
	data.quality = 0
	cell_changed.emit(cell)
	return crop


## 指定マスの次の日替わり1回だけ、成長を前倒しする。作物がないマスや成長効果付与済みのマスには付与しない。
## 品質効果とは併用できるが、成長効果そのものの重複付与はできない。
func apply_growth_boost(cell: Vector2i, days: int) -> bool:
	var data: CellData = get_cell_data(cell)
	if data == null or not data.has_crop() or days <= 0:
		return false
	if data.growth_bonus_days > 0:
		return false
	data.growth_bonus_days = days
	cell_changed.emit(cell)
	return true


## 指定マスの作物に高品質(quality=1)を付与する。成長効果とは併用できるが、品質効果の重複付与はできない。
func apply_quality(cell: Vector2i) -> bool:
	var data: CellData = get_cell_data(cell)
	if data == null or not data.has_crop():
		return false
	if data.quality > 0:
		return false
	data.quality = 1
	cell_changed.emit(cell)
	return true


## 日が進んだときの農地の更新(DayManager.next_day から呼ばれる)
## - 水やり済みの作物だけ成長日数 +(1 + ボーナス日数)。未水やりは成長停止
## - 成長ボーナスは水やりの有無・成熟状態に関わらず、この日替わりで消費する
## - その後、全マスの水やり済みフラグをリセットする
func advance_day() -> void:
	for cell_key in cells.keys():
		var cell: Vector2i = cell_key
		var data: CellData = cells[cell]
		if data.has_crop():
			var progress_before: int = data.growth_progress
			if data.is_watered and not data.is_harvestable():
				data.growth_progress += 1 + data.growth_bonus_days
			if data.growth_bonus_days > 0:
				DebugFlags.log_effect("成長効果 cell=%s %s: 成長 %d→%d / %d日(ボーナス+%d日%s)" % [
					cell, data.crop.id, progress_before, data.growth_progress, data.crop.growth_days,
					data.growth_bonus_days, "" if data.growth_progress > progress_before else "・未水やりのため不発"])
			data.growth_bonus_days = 0
		else:
			# 作物のないマスには一時効果を持ち越さない
			data.growth_bonus_days = 0
			data.quality = 0
		if data.is_watered:
			data.is_watered = false
			_refresh_cell(cell)
	day_advanced.emit()


## TileSet を GameConfig のタイルサイズと SpriteProvider の素材から作る(1種類 = 1ソース、タイルは1枚)
func _build_tile_set() -> void:
	var new_tile_set: TileSet = TileSet.new()
	var tile_size: Vector2i = Vector2i(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)
	new_tile_set.tile_size = tile_size
	for i: int in TILE_NAMES.size():
		var source: TileSetAtlasSource = TileSetAtlasSource.new()
		source.texture = SpriteProvider.get_texture(StringName("tiles/%s" % TILE_NAMES[i]))
		source.texture_region_size = tile_size
		source.create_tile(Vector2i.ZERO)
		new_tile_set.add_source(source, i)
	tile_set = new_tile_set


func _build_map() -> void:
	clear()
	cells.clear()
	for y: int in GridUtils.MAP_SIZE.y:
		for x: int in GridUtils.MAP_SIZE.x:
			var cell: Vector2i = Vector2i(x, y)
			cells[cell] = CellData.new()
			_refresh_cell(cell)


## 状態に合わせてタイルの見た目を更新する(作物の見た目は CropRenderer が描く)
func _refresh_cell(cell: Vector2i) -> void:
	var data: CellData = cells[cell]
	var tile_kind: int
	if data.soil == CellData.Soil.TILLED:
		tile_kind = TILE_TILLED_WET if data.is_watered else TILE_TILLED
	elif farmland_rect.has_point(cell):
		tile_kind = TILE_FARMLAND
	else:
		tile_kind = TILE_GRASS
	set_cell(cell, tile_kind, Vector2i.ZERO)
