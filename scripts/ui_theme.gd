class_name UiTheme
extends RefCounted
## UI 部品(Label / Button / パネル)の共通スタイル。仮デザイン(色付き四角+文字)。
## 画面のルートの Control に UiTheme.create() の結果を theme として設定すると、子孫が同じ見た目になる。
## 変更したいときはこのファイルの定数だけを触る。

const COLOR_PANEL: Color = Color(0.08, 0.08, 0.12, 0.95)
const COLOR_PANEL_BORDER: Color = Color(0.45, 0.45, 0.55, 1.0)
const COLOR_TEXT: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TEXT_DIM: Color = Color(0.7, 0.7, 0.75, 1.0)
const COLOR_BUTTON: Color = Color(0.2, 0.22, 0.32, 1.0)
const COLOR_BUTTON_HOVER: Color = Color(0.3, 0.33, 0.46, 1.0)
const COLOR_BUTTON_PRESSED: Color = Color(0.9, 0.8, 0.2, 1.0)
const COLOR_FOCUS: Color = Color(1.0, 0.9, 0.2, 1.0)

const FONT_SIZE: int = 8
const FONT_SIZE_LARGE: int = 10
const FONT_SIZE_HUGE: int = 40

## Label の型バリエーション名(theme_type_variation に設定する)
const VARIATION_DIM: StringName = &"DimLabel"
const VARIATION_LARGE: StringName = &"LargeLabel"
const VARIATION_HUGE: StringName = &"HugeLabel"


static func create() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE

	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	theme.set_constant("outline_size", "Label", 2)
	theme.set_font_size("font_size", "Label", FONT_SIZE)
	_add_label_variation(theme, VARIATION_DIM, FONT_SIZE, COLOR_TEXT_DIM)
	_add_label_variation(theme, VARIATION_LARGE, FONT_SIZE_LARGE, COLOR_TEXT)
	_add_label_variation(theme, VARIATION_HUGE, FONT_SIZE_HUGE, COLOR_TEXT)

	theme.set_stylebox("panel", "PanelContainer", _box(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 6))

	theme.set_font_size("font_size", "Button", FONT_SIZE)
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT)
	theme.set_color("font_pressed_color", "Button", Color.BLACK)
	theme.set_color("font_focus_color", "Button", COLOR_TEXT)
	theme.set_stylebox("normal", "Button", _box(COLOR_BUTTON, COLOR_PANEL_BORDER, 1, 3))
	theme.set_stylebox("hover", "Button", _box(COLOR_BUTTON_HOVER, COLOR_PANEL_BORDER, 1, 3))
	theme.set_stylebox("pressed", "Button", _box(COLOR_BUTTON_PRESSED, COLOR_PANEL_BORDER, 1, 3))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), COLOR_FOCUS, 1, 3))
	theme.set_stylebox("disabled", "Button", _box(Color(0.14, 0.14, 0.18, 1.0), Color(0.3, 0.3, 0.35, 1.0), 1, 3))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55, 1.0))
	return theme


static func _add_label_variation(theme: Theme, variation: StringName, font_size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, color)


static func _box(fill: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_content_margin_all(margin)
	return box
