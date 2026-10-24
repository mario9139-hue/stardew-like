class_name TitleScreen
extends CanvasLayer
## タイトル画面(仮デザイン: 色付き四角+Label)。起動時はここから始まる。
## 「はじめから」: 初期状態で1日目から / 「つづきから」: セーブデータがあるときだけ有効 / 「終了」: ゲームを閉じる。
## 部品の見た目は UiTheme(共通スタイル)を使う。

const COLOR_BACKGROUND: Color = Color(0.12, 0.2, 0.14, 1.0)
const GAME_TITLE: String = "農場ゲーム(仮)"
const LICENSE_PATH: String = "res://assets/fonts/FONT_LICENSE.txt"
const CREDITS_HEADER: String = "【フォント】Noto Sans CJK JP(一部の文字のみ使用)\nライセンス: SIL Open Font License 1.1\n\n"
const CREDITS_LICENSE_FALLBACK: String = "(ライセンス全文は https://openfontlicense.org を参照)"
const CREDITS_SIZE: Vector2 = Vector2(270.0, 100.0)

var _root: Control
var _start_button: Button
var _continue_button: Button
var _quit_button: Button
var _credits_button: Button
var _error_label: Label
var _credits_layer: Control
var _credits_scroll: ScrollContainer
var _credits_close_button: Button


func _ready() -> void:
	_build_ui()
	_start_button.grab_focus()


## タッチ操作: エミュレーションを切っているので、ボタンの範囲を自前で判定する
func _input(event: InputEvent) -> void:
	if _credits_layer.visible:
		_input_credits(event)
		return
	if not (event is InputEventScreenTouch):
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if not touch.pressed:
		return
	if _credits_button.get_global_rect().has_point(touch.position):
		_open_credits()
	elif _start_button.get_global_rect().has_point(touch.position):
		_on_start_pressed()
	elif not _continue_button.disabled and _continue_button.get_global_rect().has_point(touch.position):
		_on_continue_pressed()
	elif _quit_button.get_global_rect().has_point(touch.position):
		_on_quit_pressed()


## クレジット表示中の入力: 閉じる(タッチ/ESC)、ドラッグでスクロール
func _input_credits(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _credits_close_button.get_global_rect().has_point(touch.position):
			_close_credits()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_credits_scroll.scroll_vertical -= int(drag.relative.y)
	elif event.is_action_pressed("ui_cancel"):
		_close_credits()


func _open_credits() -> void:
	_credits_layer.visible = true
	_credits_scroll.scroll_vertical = 0
	_credits_close_button.grab_focus()


func _close_credits() -> void:
	_credits_layer.visible = false
	_credits_button.grab_focus()


func _on_start_pressed() -> void:
	GameFlow.start_new_game()


func _on_continue_pressed() -> void:
	if not GameFlow.continue_game():
		_error_label.text = "セーブデータを読み込めませんでした"


func _on_quit_pressed() -> void:
	get_tree().quit()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.create()
	add_child(_root)

	var background: ColorRect = ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)

	var title: Label = Label.new()
	title.text = GAME_TITLE
	title.theme_type_variation = UiTheme.VARIATION_LARGE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 12.0)
	column.add_child(spacer)

	_start_button = _make_button("はじめから")
	_continue_button = _make_button("つづきから(準備中)")
	_continue_button.disabled = not SaveManager.has_save()
	_continue_button.text = "つづきから" if SaveManager.has_save() else "つづきから(データなし)"
	_quit_button = _make_button("終了")
	column.add_child(_start_button)
	column.add_child(_continue_button)
	column.add_child(_quit_button)
	_credits_button = _make_button("クレジット")
	column.add_child(_credits_button)
	_credits_button.pressed.connect(_open_credits)
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_error_label = Label.new()
	_error_label.theme_type_variation = UiTheme.VARIATION_DIM
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_error_label)
	_build_credits()


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110.0, 20.0)
	return button


## クレジット画面(フォントの著作権表記とライセンス全文)。最初は非表示
func _build_credits() -> void:
	_credits_layer = Control.new()
	_credits_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_layer.visible = false
	_root.add_child(_credits_layer)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_layer.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_layer.add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	center.add_child(column)

	var heading: Label = Label.new()
	heading.text = "クレジット"
	heading.theme_type_variation = UiTheme.VARIATION_LARGE
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	_credits_scroll = ScrollContainer.new()
	_credits_scroll.custom_minimum_size = CREDITS_SIZE
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_credits_scroll)

	var body: Label = Label.new()
	body.custom_minimum_size = Vector2(CREDITS_SIZE.x - 12.0, 0.0)
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.text = CREDITS_HEADER + _load_license_text()
	_credits_scroll.add_child(body)

	_credits_close_button = _make_button("閉じる")
	column.add_child(_credits_close_button)
	_credits_close_button.pressed.connect(_close_credits)


func _load_license_text() -> String:
	if FileAccess.file_exists(LICENSE_PATH):
		return FileAccess.get_file_as_string(LICENSE_PATH)
	return CREDITS_LICENSE_FALLBACK
