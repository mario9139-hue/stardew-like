class_name ResultScreen
extends CanvasLayer
## 結果画面(仮デザイン)。シーズン終了(SeasonStats.season_finished)で表示し、ゲームを止める。
## ランク(大きく)/ 累計売上 / 撃破数 / 荒らされた作物数 / 獲得ボーナス と、2つのボタンを出す。
## 「次のシーズンへ」「タイトルへ」は GameFlow(Autoload)に画面遷移を頼む。
## 部品の見た目は UiTheme(共通スタイル)を使う。

## 「次のシーズンへ」が押された
signal next_season_requested
## 「タイトルへ」が押された
signal title_requested

const RANK_COLORS: Dictionary = {
	"S": Color(1.0, 0.85, 0.2, 1.0),
	"A": Color(1.0, 0.45, 0.35, 1.0),
	"B": Color(0.45, 0.75, 1.0, 1.0),
	"C": Color(0.75, 0.75, 0.75, 1.0),
}
const COLOR_DIM_BACKGROUND: Color = Color(0.0, 0.0, 0.0, 0.7)

var _root: Control
var _rank_label: Label
var _sales_label: Label
var _kills_label: Label
var _ruined_label: Label
var _bonus_label: Label
var _note_label: Label
var _next_button: Button
var _title_button: Button


func _ready() -> void:
	# ポーズ中も動く(シーズン終了でゲームを止めるため)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_build_ui()
	_root.visible = false
	SeasonStats.season_finished.connect(_on_season_finished)


## タッチ操作: エミュレーションを切っているので、ボタンの範囲を自前で判定する
func _input(event: InputEvent) -> void:
	if not _root.visible or not (event is InputEventScreenTouch):
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if not touch.pressed:
		return
	if _next_button.get_global_rect().has_point(touch.position):
		_on_next_pressed()
	elif _title_button.get_global_rect().has_point(touch.position):
		_on_title_pressed()


func _on_season_finished(rank: String, summary: Dictionary) -> void:
	_rank_label.text = rank
	_rank_label.add_theme_color_override("font_color", RANK_COLORS.get(rank, Color.WHITE))
	_sales_label.text = "累計売上: %dG" % int(summary["total_sales"])
	_kills_label.text = "撃破数: %d" % int(summary["kills"])
	_ruined_label.text = "荒らされた作物数: %d" % int(summary["ruined_crops"])
	_bonus_label.text = _format_bonus()
	_note_label.text = ""
	_root.visible = true
	get_tree().paused = true
	_next_button.grab_focus()


func _format_bonus() -> String:
	if CarryOver.bonus_items.is_empty():
		return "なし"
	var lines: PackedStringArray = []
	for entry in CarryOver.bonus_items:
		lines.append("%s x%d" % [BonusTable.get_item_name(entry["id"]), int(entry["count"])])
	return "\n".join(lines)


func _on_next_pressed() -> void:
	next_season_requested.emit()
	GameFlow.start_next_season()


func _on_title_pressed() -> void:
	title_requested.emit()
	GameFlow.go_title()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.create()
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.color = COLOR_DIM_BACKGROUND
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	column.add_child(_make_label("シーズン終了", UiTheme.VARIATION_LARGE, HORIZONTAL_ALIGNMENT_CENTER))

	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)

	_rank_label = _make_label("C", UiTheme.VARIATION_HUGE, HORIZONTAL_ALIGNMENT_CENTER)
	_rank_label.custom_minimum_size = Vector2(56.0, 0.0)
	_rank_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(_rank_label)

	var stats: VBoxContainer = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 1)
	stats.custom_minimum_size = Vector2(130.0, 0.0)
	body.add_child(stats)
	_sales_label = _make_label("", &"", HORIZONTAL_ALIGNMENT_LEFT)
	_kills_label = _make_label("", &"", HORIZONTAL_ALIGNMENT_LEFT)
	_ruined_label = _make_label("", &"", HORIZONTAL_ALIGNMENT_LEFT)
	stats.add_child(_sales_label)
	stats.add_child(_kills_label)
	stats.add_child(_ruined_label)
	stats.add_child(_make_label("獲得ボーナス", UiTheme.VARIATION_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_bonus_label = _make_label("", &"", HORIZONTAL_ALIGNMENT_LEFT)
	stats.add_child(_bonus_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_next_button = _make_button("次のシーズンへ")
	_title_button = _make_button("タイトルへ")
	buttons.add_child(_next_button)
	buttons.add_child(_title_button)
	_next_button.pressed.connect(_on_next_pressed)
	_title_button.pressed.connect(_on_title_pressed)

	_note_label = _make_label("", UiTheme.VARIATION_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_note_label)


func _make_label(text: String, variation: StringName, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80.0, 18.0)
	return button
