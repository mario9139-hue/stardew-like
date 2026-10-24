class_name ShopScreen
extends CanvasLayer
## 購入画面。開いている間はツリーをポーズする(プレイヤー操作と時間が止まる)。
## 操作: 上下(↑↓ / W S)で選択、Eで1個購入、Escで閉じる。
## タッチ/クリック: 行をタップで選択、「購入」「閉じる」ボタン。
## 見た目は仮デザイン(色付き四角 + Label)で、コードで生成する。

const PANEL_RECT: Rect2 = Rect2(40.0, 20.0, 240.0, 140.0)
const ROW_START_Y: float = 52.0
const ROW_HEIGHT: float = 16.0
const BUY_BUTTON_RECT: Rect2 = Rect2(176.0, 134.0, 44.0, 20.0)
const CLOSE_BUTTON_RECT: Rect2 = Rect2(226.0, 134.0, 48.0, 20.0)
const MESSAGE_SECONDS: float = 1.0

const COLOR_PANEL: Color = Color(0.08, 0.08, 0.12, 0.95)
const COLOR_HIGHLIGHT: Color = Color(1.0, 0.9, 0.2, 0.3)
const COLOR_BUTTON: Color = Color(0.25, 0.3, 0.45, 1.0)
const COLOR_TEXT: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_DIM: Color = Color(0.7, 0.7, 0.75, 1.0)

@export var inventory_path: NodePath = ^"../Inventory"
@export var player_path: NodePath = ^"../Player"

var _inventory: Inventory
var _player: Player
## 売る商品(ShopEntry)。item が設定されているものだけ
var _entries: Array = []
var _selected: int = 0
var _open_frame: int = -1
var _message_id: int = 0

var _rows_root: Control
var _highlight: ColorRect
var _money_label: Label
var _message_label: Label
## 行ごとの表示部品: { "owned": Label }
var _row_views: Array = []


func _ready() -> void:
	# ポーズ中でも動く(開いている間、ツリーはポーズされる)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6
	visible = false
	_inventory = get_node_or_null(inventory_path) as Inventory
	if _inventory == null:
		push_error("ShopScreen: Inventory を取得できません")
	else:
		_inventory.item_changed.connect(_on_item_changed)
	_player = get_node_or_null(player_path) as Player
	if _player == null:
		push_error("ShopScreen: Player を取得できません")
	else:
		_player.weapon_changed.connect(_on_weapon_changed)
	Money.changed.connect(_on_money_changed)
	_build_static_ui()


## 購入画面を開く(entries は ShopEntry の配列)
func open(entries: Array) -> void:
	_entries = []
	for entry in entries:
		var shop_entry: ShopEntry = entry as ShopEntry
		if shop_entry != null and shop_entry.item != null:
			_entries.append(shop_entry)
	_selected = 0
	_message_label.text = ""
	_rebuild_rows()
	_refresh()
	_open_frame = Engine.get_process_frames()
	visible = true
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	# 開いた瞬間に押されていたEキーで、そのまま購入しないようにする
	if not visible or Engine.get_process_frames() == _open_frame:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"move_up"):
		_move_selection(-1)
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"move_down"):
		_move_selection(1)
	elif event.is_action_pressed(&"interact"):
		_buy_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _open_frame:
		return
	var pos: Vector2
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	):
		pos = (event as InputEventMouseButton).position
	else:
		return
	_on_pointer_pressed(pos)
	get_viewport().set_input_as_handled()


func _on_pointer_pressed(pos: Vector2) -> void:
	if CLOSE_BUTTON_RECT.has_point(pos):
		close()
	elif BUY_BUTTON_RECT.has_point(pos):
		_buy_selected()
	else:
		for i: int in _entries.size():
			var row: Rect2 = Rect2(PANEL_RECT.position.x + 8.0, ROW_START_Y + i * ROW_HEIGHT, PANEL_RECT.size.x - 16.0, ROW_HEIGHT)
			if row.has_point(pos):
				_selected = i
				_refresh()
				return


func _move_selection(delta: int) -> void:
	if _entries.is_empty():
		return
	_selected = posmod(_selected + delta, _entries.size())
	_refresh()


## 選択中の商品を1個買う
func _buy_selected() -> void:
	if _entries.is_empty() or _inventory == null:
		return
	var entry: ShopEntry = _entries[_selected]
	var is_weapon: bool = entry.item.item_type == ItemData.Type.WEAPON
	if is_weapon:
		if _player == null:
			_show_message("装備先がありません")
			return
		if _player.owns_weapon(entry.item.id):
			_show_message("購入済みです")
			return
		if _player.has_any_owned_weapon():
			_show_message("武器は1個までです")
			return
	if not Money.can_afford(entry.price):
		_show_message("お金が足りない")
		return
	if not Money.spend(entry.price):
		_show_message("購入できませんでした")
		return
	if is_weapon:
		if not _player.purchase_and_equip_weapon(entry.item):
			# 予期しない装備状態の変化があった場合は代金を返す。
			Money.add(entry.price)
			_show_message("武器を装備できませんでした")
			return
		_show_message("%s を購入・装備した" % entry.item.display_name)
	else:
		_inventory.add_item(entry.item.id, 1)
		_show_message("%s を買った" % entry.item.display_name)


func _on_item_changed(_item_id: StringName, _new_count: int) -> void:
	if visible:
		_refresh()


func _on_money_changed(_amount: int) -> void:
	if visible:
		_refresh()


func _on_weapon_changed(_weapon: ItemData) -> void:
	if visible:
		_refresh()


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_id += 1
	var my_id: int = _message_id
	# このノードはポーズ中も動くので、タイマーもポーズ中に進む
	await get_tree().create_timer(MESSAGE_SECONDS).timeout
	if my_id == _message_id:
		_message_label.text = ""


## 所持金・所持数・選択枠を更新する
func _refresh() -> void:
	_money_label.text = "所持金 %04dG" % Money.amount
	for i: int in _row_views.size():
		var entry: ShopEntry = _entries[i]
		var owned: Label = _row_views[i]["owned"]
		if entry.item.item_type == ItemData.Type.WEAPON:
			if _player != null and _player.owns_weapon(entry.item.id):
				owned.text = "購入済み"
			elif _player != null and _player.has_any_owned_weapon():
				owned.text = "購入不可"
			else:
				owned.text = ""
		else:
			owned.text = "x%d" % (_inventory.get_count(entry.item.id) if _inventory != null else 0)
	_highlight.visible = not _entries.is_empty()
	_highlight.position = Vector2(PANEL_RECT.position.x + 8.0, ROW_START_Y + _selected * ROW_HEIGHT)


func _build_static_ui() -> void:
	_make_rect(self, PANEL_RECT, COLOR_PANEL)
	var origin: Vector2 = PANEL_RECT.position
	_make_label(self, "ショップ", Rect2(origin.x + 8, origin.y + 4, 100, 14), HORIZONTAL_ALIGNMENT_LEFT, 10, COLOR_TEXT)
	_money_label = _make_label(
		self, "", Rect2(origin.x + 112, origin.y + 4, 120, 14), HORIZONTAL_ALIGNMENT_RIGHT, 10, COLOR_TEXT
	)
	# 見出し
	_make_label(self, "商品", Rect2(origin.x + 12, ROW_START_Y - 14, 100, 12), HORIZONTAL_ALIGNMENT_LEFT, 8, COLOR_DIM)
	_make_label(self, "価格", Rect2(origin.x + 124, ROW_START_Y - 14, 50, 12), HORIZONTAL_ALIGNMENT_RIGHT, 8, COLOR_DIM)
	_make_label(self, "所持", Rect2(origin.x + 180, ROW_START_Y - 14, 52, 12), HORIZONTAL_ALIGNMENT_RIGHT, 8, COLOR_DIM)

	_highlight = _make_rect(self, Rect2(0, 0, PANEL_RECT.size.x - 16.0, ROW_HEIGHT), COLOR_HIGHLIGHT)
	_rows_root = Control.new()
	_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows_root)

	_message_label = _make_label(
		self, "", Rect2(origin.x + 8, origin.y + 96, 224, 14), HORIZONTAL_ALIGNMENT_LEFT, 10, Color(1.0, 0.85, 0.4, 1.0)
	)
	_make_label(
		self, "↑↓:選択  E:購入  Esc:閉じる", Rect2(origin.x + 8, origin.y + 118, 130, 12), HORIZONTAL_ALIGNMENT_LEFT, 8, COLOR_DIM
	)
	_make_button("購入", BUY_BUTTON_RECT)
	_make_button("閉じる", CLOSE_BUTTON_RECT)


## 商品の行を作り直す
func _rebuild_rows() -> void:
	for child in _rows_root.get_children():
		child.queue_free()
	_row_views.clear()
	for i: int in _entries.size():
		var entry: ShopEntry = _entries[i]
		var y: float = ROW_START_Y + i * ROW_HEIGHT
		var x: float = PANEL_RECT.position.x
		_make_label(_rows_root, entry.item.display_name, Rect2(x + 12, y + 1, 110, 14), HORIZONTAL_ALIGNMENT_LEFT, 10, COLOR_TEXT)
		_make_label(_rows_root, "%dG" % entry.price, Rect2(x + 124, y + 1, 50, 14), HORIZONTAL_ALIGNMENT_RIGHT, 10, COLOR_TEXT)
		var owned: Label = _make_label(_rows_root, "", Rect2(x + 180, y + 1, 52, 14), HORIZONTAL_ALIGNMENT_RIGHT, 10, COLOR_TEXT)
		_row_views.append({"owned": owned})


func _make_rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var node: ColorRect = ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


## ※ テーマの上書き(フォントサイズ)を先に設定してから大きさを決める
## (先に大きさを決めると、既定の大きいフォントの最小サイズに引き伸ばされて位置がずれる)
func _make_label(
	parent: Node, text: String, rect: Rect2, align: HorizontalAlignment, font_size: int, color: Color
) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text = text
	label.horizontal_alignment = align
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_button(text: String, rect: Rect2) -> void:
	var button: ColorRect = _make_rect(self, rect, COLOR_BUTTON)
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
