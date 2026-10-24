class_name Hud
extends CanvasLayer
## 画面左上に、ホットバーで選択中のアイテム名・「Day X  HH:MM」・体力バー・HPバーを表示する。

const STAMINA_BAR_WIDTH: float = 60.0
const STAMINA_LOW_RATIO: float = 0.2
const COLOR_STAMINA: Color = Color(0.35, 0.8, 0.35, 1.0)
const COLOR_STAMINA_LOW: Color = Color(0.9, 0.3, 0.25, 1.0)
const HP_BAR_WIDTH: float = 60.0
const COLOR_HP: Color = Color(0.9, 0.4, 0.65, 1.0)

@export var hotbar_path: NodePath = ^"../Hotbar"

var _selected_name: String = ""

@onready var _label: Label = $Label
@onready var _stamina_fill: ColorRect = $StaminaFill
@onready var _stamina_label: Label = $StaminaLabel
@onready var _hp_fill: ColorRect = $HpFill
@onready var _hp_label: Label = $HpLabel


func _ready() -> void:
	PlayerStats.stamina_changed.connect(_on_stamina_changed)
	_update_stamina(PlayerStats.stamina, PlayerStats.max_stamina)
	PlayerStats.hp_changed.connect(_on_hp_changed)
	_update_hp(PlayerStats.hp, PlayerStats.max_hp)

	var hotbar: Hotbar = get_node_or_null(hotbar_path) as Hotbar
	if hotbar == null:
		push_error("Hud: Hotbar を取得できません")
		return
	hotbar.selection_changed.connect(_on_selection_changed)
	GameClock.time_changed.connect(_on_time_changed)
	GameClock.day_started.connect(_on_day_started)
	var item: ItemData = hotbar.get_selected_item()
	_selected_name = item.display_name if item != null else ""
	_refresh()


func _on_selection_changed(item: ItemData) -> void:
	_selected_name = item.display_name if item != null else ""
	_refresh()


func _on_time_changed(_hour: int, _minute: int) -> void:
	_refresh()


func _on_day_started(_day: int) -> void:
	_refresh()


func _on_stamina_changed(current: int, maximum: int) -> void:
	_update_stamina(current, maximum)


func _on_hp_changed(current: int, maximum: int) -> void:
	_update_hp(current, maximum)


func _refresh() -> void:
	_label.text = "選択: %s\n%s %d日目  %s" % [_selected_name, CarryOver.get_season_label(), GameClock.day, GameClock.get_time_text()]


func _update_stamina(current: int, maximum: int) -> void:
	var ratio: float = float(current) / float(maxi(maximum, 1))
	_stamina_fill.size.x = STAMINA_BAR_WIDTH * ratio
	_stamina_fill.color = COLOR_STAMINA_LOW if ratio <= STAMINA_LOW_RATIO else COLOR_STAMINA
	_stamina_label.text = "体力 %d/%d" % [current, maximum]


func _update_hp(current: int, maximum: int) -> void:
	var ratio: float = float(current) / float(maxi(maximum, 1))
	_hp_fill.size.x = HP_BAR_WIDTH * ratio
	_hp_fill.color = COLOR_HP
	_hp_label.text = "HP %d/%d" % [current, maximum]
