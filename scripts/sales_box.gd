class_name SalesBox
extends Interactable
## 売却箱(仮の色付きオブジェクト)。
## - Eキーで、ホットバーで選択中の「作物」アイテムを1個ずつ入れる(道具・種・素材は入れられない)
## - 入れた物は日替わり処理(DayManager.day_finished)で精算する:
##   売値の合計を所持金(Money)に加算し、その日の売上として SalesLedger に記録して、箱を空にする

## 精算したとき(箱が空でなければ)に発行される。lines は「カブ x3 = 135G」形式
signal settled(lines: PackedStringArray, total: int)

@export var hotbar_path: NodePath = ^"../Hotbar"
@export var inventory_path: NodePath = ^"../Inventory"
@export var day_manager_path: NodePath = ^"../DayManager"
## 動作確認用: 箱に入れたとき・精算したときに Output へログを出す(不要になったら false に)
@export var debug_log: bool = true

## アイテムID → { "item": ItemData, "count": int }
var _entries: Dictionary = {}

var _hotbar: Hotbar
var _inventory: Inventory

@onready var _count_label: Label = $CountLabel


func _ready() -> void:
	_hotbar = get_node_or_null(hotbar_path) as Hotbar
	_inventory = get_node_or_null(inventory_path) as Inventory
	var day_manager: DayManager = get_node_or_null(day_manager_path) as DayManager
	if _hotbar == null or _inventory == null or day_manager == null:
		push_error("SalesBox: Hotbar / Inventory / DayManager を取得できません")
		return
	day_manager.day_finished.connect(_on_day_finished)
	_refresh_label()


func interact() -> bool:
	if _hotbar == null or _inventory == null:
		return false
	var item: ItemData = _hotbar.get_selected_item()
	if item == null or item.item_type != ItemData.Type.CROP:
		if debug_log:
			print("[SalesBox] 入れられるのは作物だけです(選択中: %s)" % (item.display_name if item != null else "なし"))
		return false
	# 同じ作物の通常品質があっても、高品質品を優先して箱へ入れる。
	var quality: int = 1 if _inventory.get_count(item.id, 1) > 0 else 0
	if not _inventory.remove_item(item.id, 1, quality):
		if debug_log:
			print("[SalesBox] %s を持っていません" % item.display_name)
		return false
	var entry_key: StringName = _entry_key(item.id, quality)
	var entry: Dictionary = _entries.get(entry_key, {"item": item, "quality": quality, "count": 0})
	entry["count"] = int(entry["count"]) + 1
	_entries[entry_key] = entry
	_refresh_label()
	if debug_log:
		print("[SalesBox] %s を箱に入れた(箱の中: %d個)" % [item.display_name, _get_total_count()])
	return true

## 日替わり処理の「終了」で呼ばれる精算
func _on_day_finished(day: int) -> void:
	var lines: PackedStringArray = []
	var total: int = 0
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		var item: ItemData = entry["item"]
		var count: int = int(entry["count"])
		var quality: int = int(entry["quality"])
		var unit_price: int = roundi(float(item.sell_price) * 1.5) if quality == 1 else item.sell_price
		var amount: int = unit_price * count
		total += amount
		var quality_mark: String = "★" if quality == 1 else ""
		lines.append("%s%s x%d = %dG" % [item.display_name, quality_mark, count, amount])
	_entries.clear()
	_refresh_label()

	Money.add(total)
	SalesLedger.record(day, total)
	if debug_log:
		print("[SalesBox] %d日目の精算: 合計 %dG" % [day, total])
	if not lines.is_empty():
		settled.emit(lines, total)


func _entry_key(item_id: StringName, quality: int) -> StringName:
	return item_id if quality <= 0 else StringName("%s#q%d" % [item_id, quality])


func _get_total_count() -> int:
	var total: int = 0
	for key in _entries.keys():
		total += int(_entries[key]["count"])
	return total


func _refresh_label() -> void:
	var count: int = _get_total_count()
	_count_label.text = str(count) if count > 0 else ""
