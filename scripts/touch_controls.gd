class_name TouchControls
extends CanvasLayer
## スマホ用のタッチ操作。
## - 短タップ(約0.1秒未満で指をほぼ動かさずに離す)だけが、その位置への移動になる:
##   プレイヤーが歩いて向かう。プレイヤーとほぼ同じ位置への短タップは「アクション」と同じ動作になる
## - 長押し(指を止めたまま約0.1秒)は、タッチした位置への移動にはならず「フリック入力」になる:
##   押した位置を中心に、指を倒した方向へ歩き続ける。指を離すと止まる
## - タップ位置へ移動中に長押しすると、目的地への移動をキャンセルして、フリック入力に切り替わる
## - 右下の「アクション」ボタン(調べる・使用の共通):
##     近くに調べられるもの(家・売却箱・井戸・店)があればそれを実行し、なければ道具を使う
## - ホットバーのスロットをタップして選択
## タッチ画面がある端末でだけ有効(PCで見た目を試すときは always_show を true にする)。

## PCでの動作確認用: タッチ画面がなくても表示する
@export var always_show: bool = false
@export var player_path: NodePath = ^"../Player"
@export var hotbar_path: NodePath = ^"../Hotbar"
@export var interaction_controller_path: NodePath = ^"../InteractionController"
@export var attack_controller_path: NodePath = ^"../AttackController"
@export var monster_spawner_path: NodePath = ^"../MonsterSpawner"

## 右下のボタン。「アクション」と「攻撃」は同じ大きさで、攻撃をアクションの真上に置く
## 下のアイテム欄(ホットバー: 画面下端から29px、高さ26px)と重ならないよう、その真上に置く
const BUTTON_SIZE: float = 32.0
const BUTTON_GAP: float = 3.0
const BUTTON_FONT_SIZE: int = 6
## 位置は基準解像度(GameConfig)の右端・下端からの距離で決める
const ACTION_BUTTON_RIGHT_MARGIN: float = 6.0
const ACTION_BUTTON_BOTTOM_MARGIN: float = 65.0
## デバッグ用ボタンは画面の上側に横並び(右寄せ)。左上の HUD(y〜52)・右上の金額/装備/精算表示(y〜60)の下に置く
const DEBUG_BUTTON_SIZE: Vector2 = Vector2(22.0, 14.0)
const DEBUG_BUTTON_GAP: float = 2.0
const DEBUG_BUTTON_Y: float = 62.0
const DEBUG_BUTTON_RIGHT_MARGIN: float = 4.0
## 右端から: 召喚、素材
const DEBUG_MATERIAL_COUNT: int = 5

## フリック入力: 中心からこれ以上(px)倒したら歩き始める / 表示上の最大の倒し幅(px)
const FLICK_DEADZONE: float = 6.0
const FLICK_RADIUS: float = 24.0
const FLICK_KNOB_SIZE: float = 16.0

const COLOR_BUTTON: Color = Color(0.2, 0.2, 0.25, 0.55)
const COLOR_BUTTON_PRESSED: Color = Color(0.9, 0.8, 0.2, 0.8)
const COLOR_FLICK_BASE: Color = Color(1.0, 1.0, 1.0, 0.2)
const COLOR_FLICK_KNOB: Color = Color(1.0, 1.0, 1.0, 0.6)

## ボタンの範囲(画面サイズ GameConfig.BASE_RESOLUTION から _compute_layout で決める)
var ACTION_BUTTON_RECT: Rect2
var ATTACK_BUTTON_RECT: Rect2
var SUMMON_BUTTON_RECT: Rect2
var MATERIAL_BUTTON_RECT: Rect2

var _player: Player
var _hotbar: Hotbar
var _interaction: InteractionController
var _attack: AttackController

## 画面(ワールド)を押している指の番号(いなければ -1)
var _move_index: int = -1
var _action_index: int = -1
var _attack_index: int = -1
var _press_start_pos: Vector2 = Vector2.ZERO
var _flick_active: bool = false
var _flick_origin: Vector2 = Vector2.ZERO

var _action_button: ColorRect
var _attack_button: ColorRect
var _summon_button: ColorRect
var _summon_index: int = -1
var _material_button: ColorRect
var _material_index: int = -1
var _spawner: MonsterSpawner
var _flick_base: ColorRect
var _flick_knob: ColorRect


func _ready() -> void:
	# ポーズ中(就寝・ショップなど)に指が離れても取りこぼさないよう、常に入力を受け取る
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 2
	if not (always_show or DisplayServer.is_touchscreen_available()):
		visible = false
		set_process_input(false)
		set_process(false)
		return
	_player = get_node_or_null(player_path) as Player
	_hotbar = get_node_or_null(hotbar_path) as Hotbar
	_interaction = get_node_or_null(interaction_controller_path) as InteractionController
	_attack = get_node_or_null(attack_controller_path) as AttackController
	_spawner = get_node_or_null(monster_spawner_path) as MonsterSpawner
	if _player == null:
		push_error("TouchControls: Player を取得できません")
	if _hotbar == null:
		push_warning("TouchControls: Hotbar を取得できません(ホットバーのタップ選択は使えません)")
	if _interaction == null:
		push_warning("TouchControls: InteractionController を取得できません(調べる操作は使えません)")
	if _attack == null:
		push_warning("TouchControls: AttackController を取得できません(攻撃ボタンは使えません)")
	_compute_layout()
	_build_ui()


func _process(_delta: float) -> void:
	_summon_button.visible = DebugFlags.DEBUG_ENABLED
	_material_button.visible = DebugFlags.DEBUG_ENABLED
	if _player == null:
		return
	# ポーズ中(就寝の暗転・ショップなど)は、画面を押している操作を打ち切る
	if get_tree().paused:
		_cancel_world_touch()
		return


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_on_touch_pressed(touch.index, touch.position)
		else:
			_on_touch_released(touch.index)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _move_index and _player != null:
			_on_world_drag(drag.position)


func _on_touch_pressed(index: int, pos: Vector2) -> void:
	# ポーズ中は新しい操作を受け付けない
	if get_tree().paused:
		return
	# 1. 「アクション」ボタン
	if ACTION_BUTTON_RECT.has_point(pos):
		_action_index = index
		_action_button.color = COLOR_BUTTON_PRESSED
		_do_action()
		return
	# 1b. 「攻撃」ボタン
	if ATTACK_BUTTON_RECT.has_point(pos):
		_attack_index = index
		_attack_button.color = COLOR_BUTTON_PRESSED
		if _attack != null:
			_attack.try_attack()
		return
	# 1c. 「召喚」ボタン(デバッグ)
	if DebugFlags.DEBUG_ENABLED and SUMMON_BUTTON_RECT.has_point(pos):
		_summon_index = index
		_summon_button.color = COLOR_BUTTON_PRESSED
		if _spawner != null:
			_spawner.debug_spawn()
		return
	# 1d. 「素材」ボタン(デバッグ)
	if DebugFlags.DEBUG_ENABLED and MATERIAL_BUTTON_RECT.has_point(pos):
		_material_index = index
		_material_button.color = COLOR_BUTTON_PRESSED
		_debug_give_materials()
		return
	# 2. ホットバーのスロット
	if _hotbar != null:
		var slot: int = _hotbar.get_slot_index_at(pos)
		if slot >= 0:
			_hotbar.select_slot(slot)
			return
	if _player == null or _move_index != -1:
		return
	# 3. 画面(ワールド)を押したら、時間・指の動きの制限なしで、すぐフリック入力を始める
	#    (タップ位置への移動は廃止)
	_move_index = index
	_press_start_pos = pos
	_begin_flick()


func _on_touch_released(index: int) -> void:
	if index == _move_index:
		_move_index = -1
		if _flick_active:
			# フリック入力中だった: 指を離したら止まる
			_end_flick()
	if index == _action_index:
		_action_index = -1
		_action_button.color = COLOR_BUTTON
	if index == _attack_index:
		_attack_index = -1
		_attack_button.color = COLOR_BUTTON
	if index == _material_index:
		_material_index = -1
		_material_button.color = COLOR_BUTTON
	if index == _summon_index:
		_summon_index = -1
		_summon_button.color = COLOR_BUTTON


func _on_world_drag(pos: Vector2) -> void:
	if _flick_active:
		_update_flick(pos)
		return


## フリック入力を始める(押した位置が中心)
func _begin_flick() -> void:
	_flick_active = true
	_flick_origin = _press_start_pos
	_player.clear_move_target()
	_show_flick(Vector2.ZERO)


func _update_flick(pos: Vector2) -> void:
	var offset: Vector2 = pos - _flick_origin
	if offset.length() < FLICK_DEADZONE:
		_player.clear_move_direction()
	else:
		_player.set_move_direction(offset)
	_show_flick(offset.limit_length(FLICK_RADIUS))


func _end_flick() -> void:
	_flick_active = false
	_player.clear_move_direction()
	_flick_base.visible = false
	_flick_knob.visible = false


func _cancel_world_touch() -> void:
	if _flick_active:
		_end_flick()
	_move_index = -1


func _show_flick(offset: Vector2) -> void:
	_flick_base.visible = true
	_flick_knob.visible = true
	_flick_base.position = _flick_origin - _flick_base.size * 0.5
	_flick_knob.position = _flick_origin + offset - _flick_knob.size * 0.5


## デバッグ: 成長の粉・品質の欠片の所持数を各 DEBUG_MATERIAL_COUNT 個にそろえる(連打しても増えすぎない)
func _debug_give_materials() -> void:
	var inventory: Inventory = get_tree().get_first_node_in_group(&"inventory") as Inventory
	if inventory == null:
		return
	for item_id: StringName in [&"growth_powder", &"quality_shard"]:
		var shortage: int = DEBUG_MATERIAL_COUNT - inventory.get_count(item_id)
		if shortage > 0:
			inventory.add_item(item_id, shortage)
	print("[Debug] 強化素材の所持数: 成長の粉 x%d / 品質の欠片 x%d" % [inventory.get_count(&"growth_powder"), inventory.get_count(&"quality_shard")])


## アクション: 近くに調べられるものがあればそれを実行し、なければ道具を使う
func _do_action() -> void:
	if _interaction != null and _interaction.try_interact(true):
		return
	if _player != null:
		_player.use_tool()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _compute_layout() -> void:
	var screen_width: float = float(GameConfig.BASE_WIDTH)
	var screen_height: float = float(GameConfig.BASE_HEIGHT)
	var action_y: float = screen_height - ACTION_BUTTON_BOTTOM_MARGIN
	var button_x: float = screen_width - ACTION_BUTTON_RIGHT_MARGIN - BUTTON_SIZE
	ACTION_BUTTON_RECT = Rect2(button_x, action_y, BUTTON_SIZE, BUTTON_SIZE)
	ATTACK_BUTTON_RECT = Rect2(button_x, action_y - BUTTON_SIZE - BUTTON_GAP, BUTTON_SIZE, BUTTON_SIZE)
	var material_x: float = screen_width - DEBUG_BUTTON_RIGHT_MARGIN - DEBUG_BUTTON_SIZE.x
	MATERIAL_BUTTON_RECT = Rect2(Vector2(material_x, DEBUG_BUTTON_Y), DEBUG_BUTTON_SIZE)
	SUMMON_BUTTON_RECT = Rect2(Vector2(material_x - DEBUG_BUTTON_SIZE.x - DEBUG_BUTTON_GAP, DEBUG_BUTTON_Y), DEBUG_BUTTON_SIZE)


func _build_ui() -> void:
	_action_button = _make_button(ACTION_BUTTON_RECT, "アクション")
	_attack_button = _make_button(ATTACK_BUTTON_RECT, "攻撃")
	_summon_button = _make_button(SUMMON_BUTTON_RECT, "召喚")
	_material_button = _make_button(MATERIAL_BUTTON_RECT, "素材")

	_flick_base = _make_rect(Vector2.ZERO, Vector2(FLICK_RADIUS * 2.0, FLICK_RADIUS * 2.0), COLOR_FLICK_BASE)
	_flick_base.visible = false
	_flick_knob = _make_rect(Vector2.ZERO, Vector2(FLICK_KNOB_SIZE, FLICK_KNOB_SIZE), COLOR_FLICK_KNOB)
	_flick_knob.visible = false


## 文字入りのボタンを作る
## ※ 先にフォントサイズを設定し、親(ボタン)いっぱいに広げる。
##   先に大きさを決めると、既定の大きいフォントの最小サイズに引き伸ばされて、文字がボタンからずれる
##   clip_text で、文字がボタンより長くても大きさを引き伸ばさない
func _make_button(area: Rect2, text: String, color: Color = COLOR_BUTTON) -> ColorRect:
	var button: ColorRect = _make_rect(area.position, area.size, color)
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.text = text
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button


func _make_rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
