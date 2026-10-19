class_name TouchControls
extends CanvasLayer
## スマホ用のタッチ操作。
## - 画面をタップすると、その位置へプレイヤーが歩く(押したまま指を動かすと目的地が指に追従する)
## - 長押し(指を止めたまま約0.3秒)すると「フリック入力」に切り替わる:
##   押した位置を中心に、指を倒した方向へ歩き続ける。指を離すと止まる
## - プレイヤーとほぼ同じ位置をタップすると、「アクション」ボタンと同じ動作をする
## - 右下の「アクション」ボタン(調べる・使用の共通):
##     近くに調べられるもの(家・売却箱・井戸・店)があればそれを実行し、なければ道具を使う
## - ホットバーのスロットをタップして選択
## タッチ画面がある端末でだけ有効(PCで見た目を試すときは always_show を true にする)。

## PCでの動作確認用: タッチ画面がなくても表示する
@export var always_show: bool = false
@export var player_path: NodePath = ^"../Player"
@export var hotbar_path: NodePath = ^"../Hotbar"
@export var interaction_controller_path: NodePath = ^"../InteractionController"

## プレイヤーの中心からこの距離(px)以内のタップを「アクション」として扱う
const TAP_ACTION_RADIUS: float = 10.0
const ACTION_BUTTON_RECT: Rect2 = Rect2(266.0, 128.0, 44.0, 44.0)
const MARKER_SIZE: float = 6.0

## 長押しとみなす時間(ミリ秒)と、その間に許容する指の動き(px)
const LONG_PRESS_MSEC: int = 300
const LONG_PRESS_MOVE_TOLERANCE: float = 6.0
## フリック入力: 中心からこれ以上(px)倒したら歩き始める / 表示上の最大の倒し幅(px)
const FLICK_DEADZONE: float = 6.0
const FLICK_RADIUS: float = 24.0
const FLICK_KNOB_SIZE: float = 16.0

const COLOR_BUTTON: Color = Color(0.2, 0.2, 0.25, 0.55)
const COLOR_BUTTON_PRESSED: Color = Color(0.9, 0.8, 0.2, 0.8)
const COLOR_MARKER: Color = Color(1.0, 0.9, 0.2, 0.8)
const COLOR_FLICK_BASE: Color = Color(1.0, 1.0, 1.0, 0.2)
const COLOR_FLICK_KNOB: Color = Color(1.0, 1.0, 1.0, 0.6)

var _player: Player
var _hotbar: Hotbar
var _interaction: InteractionController

## 画面(ワールド)を押している指の番号(いなければ -1)
var _move_index: int = -1
var _action_index: int = -1
var _press_start_pos: Vector2 = Vector2.ZERO
var _press_start_msec: int = 0
var _press_moved: bool = false
var _flick_active: bool = false
var _flick_origin: Vector2 = Vector2.ZERO

var _action_button: ColorRect
var _marker: ColorRect
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
	if _player == null:
		push_error("TouchControls: Player を取得できません")
	if _hotbar == null:
		push_warning("TouchControls: Hotbar を取得できません(ホットバーのタップ選択は使えません)")
	if _interaction == null:
		push_warning("TouchControls: InteractionController を取得できません(調べる操作は使えません)")
	_build_ui()


func _process(_delta: float) -> void:
	if _player == null:
		return
	# ポーズ中(就寝の暗転・ショップなど)は、画面を押している操作を打ち切る
	if get_tree().paused:
		_cancel_world_touch()
		_marker.visible = false
		return
	# 長押しでフリック入力に切り替える
	if (
		_move_index != -1
		and not _flick_active
		and not _press_moved
		and Time.get_ticks_msec() - _press_start_msec >= LONG_PRESS_MSEC
	):
		_begin_flick()
	# 目的地の印(タップ移動で歩いている間だけ表示)
	_marker.visible = _player.has_move_target()
	if _marker.visible:
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * _player.get_move_target()
		_marker.position = screen_pos - _marker.size * 0.5


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
	# 2. ホットバーのスロット
	if _hotbar != null:
		var slot: int = _hotbar.get_slot_index_at(pos)
		if slot >= 0:
			_hotbar.select_slot(slot)
			return
	if _player == null or _move_index != -1:
		return
	# 3. プレイヤーのほぼ真上をタップ → アクションと同じ
	var world_pos: Vector2 = _screen_to_world(pos)
	if _player.global_position.distance_to(world_pos) <= TAP_ACTION_RADIUS:
		_player.clear_move_target()
		_do_action()
		return
	# 4. それ以外 → そこへ歩く(押し続けると、長押しフリックに切り替わる)
	_move_index = index
	_press_start_pos = pos
	_press_start_msec = Time.get_ticks_msec()
	_press_moved = false
	_flick_active = false
	_player.set_move_target(world_pos)


func _on_touch_released(index: int) -> void:
	if index == _move_index:
		# タップ移動中なら、指を離しても最後の目的地までは歩き続ける。フリック中は止まる
		if _flick_active:
			_end_flick()
		_move_index = -1
	if index == _action_index:
		_action_index = -1
		_action_button.color = COLOR_BUTTON


func _on_world_drag(pos: Vector2) -> void:
	if _flick_active:
		_update_flick(pos)
		return
	if pos.distance_to(_press_start_pos) > LONG_PRESS_MOVE_TOLERANCE:
		_press_moved = true
	_player.set_move_target(_screen_to_world(pos))


func _begin_flick() -> void:
	_flick_active = true
	_flick_origin = _press_start_pos
	_player.clear_move_target()
	_marker.visible = false
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


## アクション: 近くに調べられるものがあればそれを実行し、なければ道具を使う
func _do_action() -> void:
	if _interaction != null and _interaction.try_interact():
		return
	if _player != null:
		_player.use_tool()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _build_ui() -> void:
	_action_button = _make_rect(ACTION_BUTTON_RECT.position, ACTION_BUTTON_RECT.size, COLOR_BUTTON)
	# ※ 先にフォントサイズを設定し、親(ボタン)いっぱいに広げる。
	#   先に大きさを決めると、既定の大きいフォントの最小サイズに引き伸ばされて、文字がボタンからずれる
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.text = "アクション"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_marker = _make_rect(Vector2.ZERO, Vector2(MARKER_SIZE, MARKER_SIZE), COLOR_MARKER)
	_marker.visible = false
	_flick_base = _make_rect(Vector2.ZERO, Vector2(FLICK_RADIUS * 2.0, FLICK_RADIUS * 2.0), COLOR_FLICK_BASE)
	_flick_base.visible = false
	_flick_knob = _make_rect(Vector2.ZERO, Vector2(FLICK_KNOB_SIZE, FLICK_KNOB_SIZE), COLOR_FLICK_KNOB)
	_flick_knob.visible = false


func _make_rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
