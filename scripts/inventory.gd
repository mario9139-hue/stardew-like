class_name Inventory
extends Node
## 所持品。アイテムID + 品質をキーに個数を管理する。
## 品質0は従来のアイテムIDキーを維持し、既存機能との互換性を保つ。

signal item_changed(item_id: StringName, new_count: int)

## 初期所持品(アイテムID → 個数)。品質は通常(0)として追加する。
@export var starting_items: Dictionary = {}

## アイテムIDまたは「ID + 品質」キー → 個数。0個のキーは保持しない。
var _items: Dictionary = {}


func _ready() -> void:
	add_to_group(&"inventory")
	for key in starting_items.keys():
		add_item(StringName(key), int(starting_items[key]))


## アイテムを amount 個追加する。quality=0 は通常、quality=1 は高品質。
func add_item(item_id: StringName, amount: int = 1, quality: int = 0) -> void:
	if amount <= 0:
		return
	var item_key: StringName = _item_key(item_id, quality)
	var new_count: int = int(_items.get(item_key, 0)) + amount
	_items[item_key] = new_count
	item_changed.emit(item_id, new_count)


## アイテムを amount 個減らす。品質別の所持数が不足していれば何も変更せず false。
func remove_item(item_id: StringName, amount: int = 1, quality: int = 0) -> bool:
	if amount <= 0 or get_count(item_id, quality) < amount:
		return false
	var item_key: StringName = _item_key(item_id, quality)
	var new_count: int = get_count(item_id, quality) - amount
	if new_count == 0:
		_items.erase(item_key)
	else:
		_items[item_key] = new_count
	item_changed.emit(item_id, new_count)
	return true


## 所持品の全部(キー → 個数)のコピー。引き継ぎ用。キーは通常「ID」、高品質は「ID#q1」
func get_all_items() -> Dictionary:
	return _items.duplicate()


## 所持品を丸ごと入れ替える(引き継ぎ用)。入れ替え前後で変わったアイテムの item_changed を発行する
func replace_items(items: Dictionary) -> void:
	var old_items: Dictionary = _items
	_items = {}
	for key in items.keys():
		if int(items[key]) > 0:
			_items[StringName(key)] = int(items[key])
	var changed_keys: Dictionary = {}
	for key in old_items.keys():
		changed_keys[key] = true
	for key in _items.keys():
		changed_keys[key] = true
	for key in changed_keys.keys():
		var key_text: String = String(key)
		var base_id: StringName = StringName(key_text.get_slice("#q", 0))
		item_changed.emit(base_id, get_count(base_id, 0))


func get_count(item_id: StringName, quality: int = 0) -> int:
	return int(_items.get(_item_key(item_id, quality), 0))


func has_item(item_id: StringName, amount: int = 1, quality: int = 0) -> bool:
	return get_count(item_id, quality) >= amount


func _item_key(item_id: StringName, quality: int) -> StringName:
	if quality <= 0:
		return item_id
	return StringName("%s#q%d" % [item_id, quality])
