class_name Player
extends CharacterBody2D
## 4方向移動するプレイヤー。
## facing は「最後に入力した方向」を保持する。
## タッチ操作用に、指定した位置へ歩く「タップ移動」もできる(キー入力があればそちらが優先)。

## 移動速度(ピクセル/秒)
@export var speed: float = 80.0
## 画面上にfacingのデバッグ表示を出すか
@export var show_debug: bool = true
## ダメージを受けたあとの無敵時間(秒)。この間は点滅し、ダメージを受けない
@export var invincible_seconds: float = 1.0
## デバッグ(F6)で自分に与えるダメージ
@export var debug_damage_amount: int = 10

## 「使用」アクション(use_tool)が押されたときに、向いているマスの座標とともに発行される
signal used_tool(target_cell: Vector2i)
## 装備武器が変わったときに発行される。
signal weapon_changed(weapon: ItemData)

## 入力アクションと方向の対応
const DIRECTIONS: Dictionary = {
	&"move_up": Vector2.UP,
	&"move_down": Vector2.DOWN,
	&"move_left": Vector2.LEFT,
	&"move_right": Vector2.RIGHT,
}

## 現在向いている方向(最後に入力した方向)
var facing: Vector2 = Vector2.DOWN

## セーブデータに保持しやすい装備武器ID。未装備は空文字列。
@export var equipped_weapon_id: StringName = &""
## 所持している武器ID。現仕様では武器は1個まで。
@export var owned_weapon_ids: Array[StringName] = []
## 現在装備中の武器リソース。武器パラメータへの参照に使う。
var equipped_weapon: ItemData = null

## タップ移動の目的地に着いたとみなす距離(px)
const ARRIVE_DISTANCE: float = 2.0

var _move_target: Vector2 = Vector2.ZERO
var _has_move_target: bool = false
## 無敵時間の残り秒数(0以下なら無敵ではない)
var _invincible_left: float = 0.0
## タッチの長押しフリックによる移動方向(押している間、その方向へ歩き続ける)。ゼロなら無効
var _touch_direction: Vector2 = Vector2.ZERO

@onready var _debug_label: Label = $DebugLabel
@onready var _body: Sprite2D = $Body
## 今の見た目の向き(向きが変わったときだけ素材を差し替える)
var _body_facing_name: String = ""


func _ready() -> void:
	add_to_group(&"player")
	_setup_collision_size()
	_refresh_body_texture()
	_restore_weapon_state()
	_update_debug_label()


## 保存されたIDから装備データを復元する。武器のIDとファイル名を対応させる。
func _restore_weapon_state() -> void:
	if equipped_weapon_id == &"" and not owned_weapon_ids.is_empty():
		equipped_weapon_id = owned_weapon_ids[0]
	if equipped_weapon_id == &"":
		return
	if not owned_weapon_ids.has(equipped_weapon_id):
		owned_weapon_ids.append(equipped_weapon_id)
	var resource_path: String = "res://data/items/%s.tres" % String(equipped_weapon_id)
	if not ResourceLoader.exists(resource_path):
		push_warning("Player: 装備武器のリソースが見つかりません: %s" % resource_path)
		return
	var weapon: ItemData = load(resource_path) as ItemData
	if weapon != null and weapon.item_type == ItemData.Type.WEAPON and weapon.id == equipped_weapon_id:
		equipped_weapon = weapon


## 指定IDの武器を所持しているか。
func owns_weapon(weapon_id: StringName) -> bool:
	return (
		owned_weapon_ids.has(weapon_id)
		or equipped_weapon_id == weapon_id
		or (equipped_weapon != null and equipped_weapon.id == weapon_id)
	)


## 武器を1個でも所持しているか。
func has_any_owned_weapon() -> bool:
	return not owned_weapon_ids.is_empty() or equipped_weapon_id != &"" or equipped_weapon != null


## 購入した武器を所持リストと装備スロットへ登録する。既に武器がある場合は失敗する。
func purchase_and_equip_weapon(weapon: ItemData) -> bool:
	if weapon == null or weapon.item_type != ItemData.Type.WEAPON or has_any_owned_weapon():
		return false
	owned_weapon_ids.append(weapon.id)
	equipped_weapon_id = weapon.id
	equipped_weapon = weapon
	weapon_changed.emit(equipped_weapon)
	return true


## 所持済み武器を装備するための入口(購入時の装備とは別に利用可能)。
func equip_weapon(weapon: ItemData) -> bool:
	if weapon == null or weapon.item_type != ItemData.Type.WEAPON or not owns_weapon(weapon.id):
		return false
	equipped_weapon_id = weapon.id
	equipped_weapon = weapon
	weapon_changed.emit(equipped_weapon)
	return true


func _physics_process(delta: float) -> void:
	_update_invincibility(delta)
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
	_refresh_body_texture()


## 当たり判定の大きさをタイルサイズに合わせる(基準タイルで 16x16)
func _setup_collision_size() -> void:
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is RectangleShape2D:
		(collision.shape as RectangleShape2D).size = Vector2.ONE * GameConfig.px(16.0)


## 向きに合わせて見た目の素材を選ぶ(player/player_<up|down|left|right>、無ければ player/player)
func _refresh_body_texture() -> void:
	var facing_name: String = _facing_name()
	if facing_name == _body_facing_name:
		return
	_body_facing_name = facing_name
	SpriteProvider.apply(_body, StringName("player/player_%s" % facing_name), {}, &"player/player")


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


## ダメージを受ける。無敵時間中は無視する。受けたら invincible_seconds の無敵時間(点滅)に入る
## (ノックバックは未実装)。HP が 0 になると PlayerStats.hp_depleted が発行され、気絶する
func take_damage(amount: int) -> void:
	if amount <= 0 or is_invincible():
		return
	_invincible_left = invincible_seconds
	_update_blink()
	PlayerStats.damage_hp(amount)


func is_invincible() -> bool:
	return _invincible_left > 0.0


## 無敵時間を終わらせる(気絶して目覚めたときなど)
func clear_invincibility() -> void:
	_invincible_left = 0.0
	_update_blink()


func _update_invincibility(delta: float) -> void:
	if _invincible_left <= 0.0:
		return
	_invincible_left = maxf(_invincible_left - delta, 0.0)
	_update_blink()


## 無敵中は体を点滅させる(0.1秒ごとに薄く/通常を切り替え)
func _update_blink() -> void:
	if _invincible_left > 0.0 and int(_invincible_left * 10.0) % 2 == 0:
		_body.modulate.a = 0.3
	else:
		_body.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	# デバッグ: F6 で自分にダメージを与える
	if DebugFlags.DEBUG_ENABLED and event.is_action_pressed(&"debug_damage"):
		take_damage(debug_damage_amount)


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
