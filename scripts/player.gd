class_name Player
extends CharacterBody2D
## 4方向移動するプレイヤー。
## facing は「最後に入力した方向」を保持する。
## タッチ操作用に、指定した位置へ歩く「タップ移動」もできる(キー入力があればそちらが優先)。

## 移動速度(ピクセル/秒)
@export var speed: float = 80.0
## 画面上にfacingのデバッグ表示を出すか
@export var show_debug: bool = true

## 「使用」アクション(use_tool)が押されたときに、向いているマスの座標とともに発行される
signal used_tool(target_cell: Vector2i)

## 入力アクションと方向の対応
const DIRECTIONS: Dictionary = {
	&"move_up": Vector2.UP,
	&"move_down": Vector2.DOWN,
	&"move_left": Vector2.LEFT,
	&"move_right": Vector2.RIGHT,
}

## 現在向いている方向(最後に入力した方向)
var facing: Vector2 = Vector2.DOWN

## タップ移動の目的地に着いたとみなす距離(px)
const ARRIVE_DISTANCE: float = 2.0

var _move_target: Vector2 = Vector2.ZERO
var _has_move_target: bool = false
## タッチの長押しフリックによる移動方向(押している間、その方向へ歩き続ける)。ゼロなら無効
var _touch_direction: Vector2 = Vector2.ZERO

@onready var _debug_label: Label = $DebugLabel


func _ready() -> void:
	_update_debug_label()


func _physics_process(delta: float) -> void:
	_update_facing()
	if Input.is_action_just_pressed(&"use_tool"):
		use_tool()
	var input_dir: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	var move_speed: float = speed
	if input_dir != Vector2.ZERO:
		# キー入力が優先。タップ移動はやめる
		_has_move_target = false
	elif _touch_direction != Vector2.ZERO:
		# 長押しフリック入力: 指を離すまで、その方向へ歩き続ける
		input_dir = _touch_direction
		_face_direction(input_dir)
	elif _has_move_target:
		var to_target: Vector2 = _move_target - global_position
		var distance: float = to_target.length()
		if distance <= ARRIVE_DISTANCE:
			_has_move_target = false
		else:
			input_dir = to_target / distance
			# 目的地を行き過ぎないよう、最後の1フレームは速度を落とす
			move_speed = minf(speed, distance / delta)
			_face_direction(input_dir)
	velocity = input_dir.normalized() * move_speed
	move_and_slide()
	# 何かにぶつかって進めないときは、タップ移動をあきらめる
	if _has_move_target and get_real_velocity().length() < move_speed * 0.2:
		_has_move_target = false
	_update_debug_label()


## 最後に押された方向をfacingにする。
## 向いている方向のキーが離され、別の方向が押されたままなら、そちらに切り替える。
func _update_facing() -> void:
	for action: StringName in DIRECTIONS:
		if Input.is_action_just_pressed(action):
			facing = DIRECTIONS[action]

	if not _is_facing_held():
		for action: StringName in DIRECTIONS:
			if Input.is_action_pressed(action):
				facing = DIRECTIONS[action]
				break


func _is_facing_held() -> bool:
	for action: StringName in DIRECTIONS:
		if DIRECTIONS[action] == facing:
			return Input.is_action_pressed(action)
	return false


func _facing_name() -> String:
	match facing:
		Vector2.UP:
			return "up"
		Vector2.DOWN:
			return "down"
		Vector2.LEFT:
			return "left"
		Vector2.RIGHT:
			return "right"
	return "?"


func _update_debug_label() -> void:
	_debug_label.visible = show_debug
	if show_debug:
		_debug_label.text = "facing: %s" % _facing_name()


## 「使用」を実行する(向いているマスに道具を使う)。クリック・キー・タッチ共通の入口
func use_tool() -> void:
	used_tool.emit(GridUtils.get_facing_cell(global_position, facing))


## タップ移動: world_position(ワールド座標)へ歩いていく
func set_move_target(world_position: Vector2) -> void:
	_move_target = world_position
	_has_move_target = true


func clear_move_target() -> void:
	_has_move_target = false


## フリック入力: direction の方向へ歩き続ける(clear_move_direction で止める)。タップ移動は解除される
func set_move_direction(direction: Vector2) -> void:
	_touch_direction = direction.normalized()
	_has_move_target = false


func clear_move_direction() -> void:
	_touch_direction = Vector2.ZERO


func has_move_target() -> bool:
	return _has_move_target


func get_move_target() -> Vector2:
	return _move_target


## 進行方向に最も近い4方向を facing にする
func _face_direction(direction: Vector2) -> void:
	if absf(direction.x) >= absf(direction.y):
		facing = Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if direction.y > 0.0 else Vector2.UP
