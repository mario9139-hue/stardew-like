class_name AttackController
extends Node
## プレイヤーの攻撃。入力アクション attack(右クリック)で、facing 方向に攻撃範囲の Area2D を生成し、
## active_seconds だけ有効にして消す。
## - 範囲の大きさ・攻撃力・クールダウンは、装備中の武器(Player.equipped_weapon)の値を使う
## - 武器がない: 攻撃せず「武器がない」を表示 / クールダウン中: 攻撃しない
## - 体力を stamina_cost_attack 消費する。足りなければ攻撃しない
## - 範囲に入った「damageable」グループのノードに take_damage(amount: int) を呼ぶ
##   (1回の攻撃で同じ相手には1度だけ)
## - 攻撃中も移動は止めない(Player 側は何も変えていない)
## ツリーがポーズ中(就寝・ショップなど)は処理が止まる。

## 参照先ノードのパス(このノードからの相対パス)
@export var player_path: NodePath = ^"../Player"
@export var message_display_path: NodePath = ^"../MessageDisplay"
## 攻撃範囲が有効な秒数
@export var active_seconds: float = 0.15
## 攻撃範囲の可視化の色(半透明)
@export var area_color: Color = Color(1.0, 0.3, 0.2, 0.4)
## 攻撃範囲が検出する物理レイヤー(既定は全レイヤー)
@export_flags_2d_physics var detect_mask: int = 0xFFFFF
## 動作確認用: 攻撃・命中時に Output へログを出す(不要になったら false に)
@export var debug_log: bool = true

## プレイヤーの中心から体の端までの距離(px)。攻撃範囲はこの外側から始まる
const PLAYER_HALF_SIZE: float = 8.0
const DAMAGEABLE_GROUP: StringName = &"damageable"

var _player: Player
var _messages: MessageDisplay

## クールダウンの残り秒数
var _cooldown_left: float = 0.0
## 攻撃範囲が有効な残り秒数(0以下なら攻撃範囲はない)
var _active_left: float = 0.0
var _area: Area2D = null
## 今回の攻撃で命中済みのノード(同じ相手に2回当てない)
var _hit_targets: Array = []
## 今回の攻撃の攻撃力(攻撃開始時の武器の値)
var _attack_power: int = 0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_messages = get_node_or_null(message_display_path) as MessageDisplay
	if _player == null:
		push_error("AttackController: Player を取得できません")
	if _messages == null:
		push_warning("AttackController: MessageDisplay を取得できません(メッセージは表示されません)")


# ※ 右クリックがプレイヤーなどの Control(色付き四角)に吸われないよう、_unhandled_input ではなく _input で受ける
func _input(event: InputEvent) -> void:
	if _player != null and event.is_action_pressed(&"attack"):
		try_attack()


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _area != null:
		_active_left -= delta
		if _active_left <= 0.0:
			_end_attack()


## 攻撃を試みる。攻撃を始めたら true
func try_attack() -> bool:
	if _player == null:
		return false
	var weapon: ItemData = _player.equipped_weapon
	if weapon == null:
		_show_message("武器がない")
		return false
	if _cooldown_left > 0.0:
		return false
	if weapon.weapon_attack_range <= 0.0:
		push_warning("AttackController: %s の weapon_attack_range が 0 以下です" % weapon.id)
		return false
	if not PlayerStats.consume_stamina(PlayerStats.stamina_cost_attack):
		_show_message("体力が足りない")
		return false

	_cooldown_left = weapon.weapon_attack_cooldown
	_attack_power = weapon.weapon_attack_power
	_spawn_area(weapon.weapon_attack_range)
	if debug_log:
		print(
			"[AttackController] 攻撃 向き=%s 攻撃力=%d 範囲=%.0f 体力=%d/%d"
			% [_player.facing, _attack_power, weapon.weapon_attack_range, PlayerStats.stamina, PlayerStats.max_stamina]
		)
	return true


## facing 方向に、攻撃範囲(range × range の正方形)の Area2D を生成する
func _spawn_area(side: float) -> void:
	_end_attack()
	_hit_targets.clear()

	var area: Area2D = Area2D.new()
	area.name = "AttackArea"
	area.collision_layer = 0
	area.collision_mask = detect_mask
	# プレイヤーの体の端から facing 方向へ、範囲の半分だけ離れた位置を中心にする
	area.position = _player.facing * (PLAYER_HALF_SIZE + side * 0.5)

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(side, side)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)

	# 仮の可視化(半透明の色付き四角)
	var visual: ColorRect = ColorRect.new()
	visual.size = Vector2(side, side)
	visual.position = -visual.size * 0.5
	visual.color = area_color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(visual)

	area.body_entered.connect(_on_target_entered)
	area.area_entered.connect(_on_target_entered)
	# プレイヤーの子にするので、攻撃中に移動しても範囲がついてくる
	_player.add_child(area)
	_area = area
	_active_left = active_seconds


func _end_attack() -> void:
	if _area != null:
		_area.queue_free()
		_area = null
	_active_left = 0.0


func _on_target_entered(target: Node) -> void:
	var damageable: Node = _find_damageable(target)
	if damageable == null or _hit_targets.has(damageable):
		return
	_hit_targets.append(damageable)
	damageable.call(&"take_damage", _attack_power)
	if debug_log:
		print("[AttackController] 命中 %s ダメージ=%d" % [damageable.name, _attack_power])


## 当たったノード自身、または1つ上の親から、damageable な(take_damage を持つ)ノードを探す
## (敵の本体が CharacterBody2D でも、その子の Area2D でも検出できる)
func _find_damageable(node: Node) -> Node:
	var candidate: Node = node
	for i: int in 2:
		if candidate == null or candidate == _player:
			return null
		if candidate.is_in_group(DAMAGEABLE_GROUP) and candidate.has_method(&"take_damage"):
			return candidate
		candidate = candidate.get_parent()
	return null


func _show_message(text: String) -> void:
	if _messages != null:
		_messages.show_message(text, 1.0)
