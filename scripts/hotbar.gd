class_name Hotbar
extends CanvasLayer
## 画面下部のホットバー。道具・所持品を並べ、数字キー(hotbar_1〜hotbar_9)で選択する。
## 選択中のスロットは枠で強調し、個数のあるアイテムは個数を表示する。
## 見た目は仮デザイン(色付き四角 + Label)。スロットはコードで生成する。

## 選択中のアイテムが変わったときに発行される
signal selection_changed(item: ItemData)

const BASE_SLOT_SIZE: Vector2 = Vector2(28, 26)
const SLOT_GAP: float = 2.0
const SIDE_MARGIN: float = 6.0
const BOTTOM_MARGIN: float = 3.0
const MAX_KEY_SLOTS: int = 9
## このアイテムは個数ではなく PlayerStats の残量(例: 12/20)を表示する
const WATERING_CAN_ID: StringName = &"watering_can"
const COLOR_BORDER: Color = Color(0.3, 0.3, 0.35, 1.0)
const COLOR_BORDER_SELECTED: Color = Color(1.0, 0.9, 0.2, 1.0)
const COLOR_FILL: Color = Color(0.12, 0.12, 0.16, 0.9)
const COLOR_TEXT: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_KEY: Color = Color(0.7, 0.7, 0.75, 1.0)

@export var inventory_path: NodePath = ^"../Inventory"
## ホットバーに並べるアイテム(ItemData)。左から 1, 2, 3... のキーに対応する
@export var slot_items: Array = []

var selected_index: int = 0
var _slot_size: Vector2 = BASE_SLOT_SIZE

var _inventory: Inventory
## スロットごとの表示部品: { "index", "item", "root", "border", "count_label" }
var _slot_views: Array = []


func _ready() -> void:
	_inventory = get_node_or_null(inventory_path) as Inventory
	if _inventory == null:
		push_error("Hotbar: Inventory を取得できません")
	else:
		_inventory.item_changed.connect(_on_item_changed)
	PlayerStats.water_changed.connect(_on_water_changed)
	_build_slots()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_wrapped(selected_index - 1)
			get_viewport().set_input_as_handled()
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_wrapped(selected_index + 1)
			get_viewport().set_input_as_handled()
			return
	for i: int in mini(slot_items.size(), MAX_KEY_SLOTS):
		if event.is_action_pressed(StringName("hotbar_%d" % (i + 1))):
			select_slot(i)
			return


func _select_wrapped(index: int) -> void:
	if slot_items.is_empty():
		return
	var next_index: int = posmod(index, slot_items.size())
	if next_index != selected_index:
		select_slot(next_index)


## 選択中のアイテム。スロットが空なら null
func get_selected_item() -> ItemData:
	if selected_index < 0 or selected_index >= slot_items.size():
		return null
	return slot_items[selected_index] as ItemData


## 画面上の位置(基準解像度の座標)にあるスロット番号。なければ -1(タッチ操作用)
func get_slot_index_at(pos: Vector2) -> int:
	for view in _slot_views:
		var root: Control = view["root"]
		if Rect2(root.position, root.size).has_point(pos):
			return view["index"]
	return -1


func select_slot(index: int) -> void:
	if index < 0 or index >= slot_items.size() or index == selected_index:
		return
	selected_index = index
	_refresh()
	selection_changed.emit(get_selected_item())


func _on_item_changed(_item_id: StringName, _new_count: int) -> void:
	_refresh()


func _on_water_changed(_current: int, _maximum: int) -> void:
	_refresh()


func _build_slots() -> void:
	var count: int = slot_items.size()
	if count == 0:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	# スロット数に応じて幅を計算し、左右に最低 SIDE_MARGIN を確保する。
	# 320px幅・10枠の場合は 28px × 10 + 2px × 9 = 298px で中央に収まる。
	var available_slot_width: float = (viewport_size.x - SIDE_MARGIN * 2.0 - (count - 1) * SLOT_GAP) / count
	_slot_size = Vector2(minf(BASE_SLOT_SIZE.x, available_slot_width), BASE_SLOT_SIZE.y)
	var total_width: float = count * _slot_size.x + (count - 1) * SLOT_GAP
	var start: Vector2 = Vector2(
		(viewport_size.x - total_width) / 2.0,
		viewport_size.y - _slot_size.y - BOTTOM_MARGIN
	)
	for i: int in count:
		var item: ItemData = slot_items[i] as ItemData
		if item == null:
			push_warning("Hotbar: slot_items[%d] が ItemData ではありません" % i)
			continue

		var root: Control = Control.new()
		root.position = start + Vector2(i * (_slot_size.x + SLOT_GAP), 0.0)
		root.size = _slot_size
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)

		var border: ColorRect = ColorRect.new()
		border.size = _slot_size
		border.color = COLOR_BORDER
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(border)

		var fill: ColorRect = ColorRect.new()
		fill.position = Vector2(2, 2)
		fill.size = _slot_size - Vector2(4, 4)
		fill.color = COLOR_FILL
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fill)

		if i < MAX_KEY_SLOTS:
			_add_label(root, str(i + 1), Vector2(2, 1), Vector2(10, 9), HORIZONTAL_ALIGNMENT_LEFT, COLOR_KEY, 7)
		_add_label(root, _get_hotbar_name(item), Vector2(0, 9), Vector2(_slot_size.x, 10), HORIZONTAL_ALIGNMENT_CENTER, COLOR_TEXT, 6)
		var count_label: Label = _add_label(
			root, "", Vector2(2, 17), Vector2(_slot_size.x - 4, 10), HORIZONTAL_ALIGNMENT_RIGHT, COLOR_TEXT, 6
		)

		_slot_views.append({
			"index": i,
			"item": item,
			"root": root,
			"border": border,
			"count_label": count_label,
		})


func _add_label(
	parent: Control, text: String, pos: Vector2, label_size: Vector2,
	align: HorizontalAlignment, color: Color, font_size: int = 8
) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


## 1行に10枠を収めるため、ホットバー表示のみ短縮名を使う(アイテム本来の表示名は変更しない)。
func _get_hotbar_name(item: ItemData) -> String:
	match item.id:
		&"turnip_seed": return "カブ種"
		&"potato_seed": return "芋種"
		&"strawberry_seed": return "苺種"
		&"growth_powder": return "成長粉"
		&"quality_shard": return "品質片"
		&"watering_can": return "じょうろ"
	return item.display_name


## 選択枠と個数表示を更新する
func _refresh() -> void:
	for i: int in _slot_views.size():
		var view: Dictionary = _slot_views[i]
		var item: ItemData = view["item"]
		var border: ColorRect = view["border"]
		var root: Control = view["root"]
		var count_label: Label = view["count_label"]

		border.color = COLOR_BORDER_SELECTED if view["index"] == selected_index else COLOR_BORDER

		if item.id == WATERING_CAN_ID:
			count_label.text = "%d/%d" % [PlayerStats.water, PlayerStats.max_water]
			root.modulate.a = 1.0
		elif item.has_count() and _inventory != null:
			var count: int = _inventory.get_count(item.id)
			var high_quality_count: int = _inventory.get_count(item.id, 1) if item.item_type == ItemData.Type.CROP else 0
			count_label.text = "x%d ★%d" % [count, high_quality_count] if high_quality_count > 0 else "x%d" % count
			root.modulate.a = 1.0 if count > 0 or high_quality_count > 0 else 0.45
		else:
			count_label.text = ""
			root.modulate.a = 1.0
