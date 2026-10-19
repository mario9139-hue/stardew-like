class_name FarmMap
extends TileMapLayer
## 草地・農地予定地・耕地の仮タイルで構成された農場マップと、マスごとの状態管理。
## マスの状態は cells(座標 → CellData)が正。タイルの見た目は状態から更新する。
## マップ内容は起動時に生成する(後でデータ駆動/保存データに置き換える想定)。

## マスの状態が変わったときに発行される
signal cell_changed(cell: Vector2i)
## 日が進んで、全マスの更新が終わったときに発行される
signal day_advanced

const SOURCE_ID: int = 0
const ATLAS_GRASS: Vector2i = Vector2i(0, 0)
const ATLAS_FARMLAND: Vector2i = Vector2i(1, 0)
const ATLAS_TILLED: Vector2i = Vector2i(2, 0)
const ATLAS_TILLED_WET: Vector2i = Vector2i(3, 0)

## 農地予定地の見た目の範囲(セル単位)。状態は草地と同じで、耕せる
@export var farmland_rect: Rect2i = Rect2i(11, 3, 6, 5)

## マスごとの状態(座標 → 状態)
## ※Godot 4.3 では型付きDictionaryが使えないため、キーは Vector2i、値は CellData として扱う
var cells: Dictionary = {}


func _ready() -> void:
	_build_map()


## マスの状態を返す。マップ外なら null
func get_cell_data(cell: Vector2i) -> CellData:
	return cells.get(cell)


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


## 指定マスの次の日替わり1回だけ、成長を前倒しする。作物がないマスには付与しない。
func apply_growth_boost(cell: Vector2i, days: int) -> bool:
	var data: CellData = get_cell_data(cell)
	if data == null or not data.has_crop() or days <= 0:
		return false
	# 1マスに付与できる強化効果は1つだけ。重ね掛けはできない。
	if data.growth_bonus_days > 0 or data.quality > 0:
		return false
	data.growth_bonus_days = days
	cell_changed.emit(cell)
	return true


## 指定マスの作物に高品質(quality=1)を付与する。空マスや効果付与済みのマスには付与しない。
func apply_quality(cell: Vector2i) -> bool:
	var data: CellData = get_cell_data(cell)
	if data == null or not data.has_crop():
		return false
	if data.growth_bonus_days > 0 or data.quality > 0:
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
			if data.is_watered and not data.is_harvestable():
				data.growth_progress += 1 + data.growth_bonus_days
			data.growth_bonus_days = 0
		else:
			# 作物のないマスには一時効果を持ち越さない
			data.growth_bonus_days = 0
			data.quality = 0
		if data.is_watered:
			data.is_watered = false
			_refresh_cell(cell)
	day_advanced.emit()


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
	var atlas: Vector2i
	if data.soil == CellData.Soil.TILLED:
		atlas = ATLAS_TILLED_WET if data.is_watered else ATLAS_TILLED
	elif farmland_rect.has_point(cell):
		atlas = ATLAS_FARMLAND
	else:
		atlas = ATLAS_GRASS
	set_cell(cell, SOURCE_ID, atlas)
