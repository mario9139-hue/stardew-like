class_name Monster
extends CharacterBody2D
## モンスター。MonsterData(data)を渡して初期化する。1つのシーンで複数種に対応する。
## - プレイヤーが検知範囲(Balance)にいれば、プレイヤーを優先して直線で追う
## - いなければ「最寄りの作物マス」へ向かい、到着して ruin_seconds 留まると作物を荒らす
##   (留まっている間にプレイヤーを検知したり倒されたりすると、進行はリセットされ被害なし)
## - 作物がなければ、ゆっくりランダムに歩く(または止まる)
## - プレイヤーに触れると contact_damage の take_damage を呼ぶ(contact_cooldown_seconds に1回まで)
## - 「damageable」グループに所属し、take_damage で HP が減る。被弾で白く点滅し、HP 0 で消える
## - 物理レイヤー 2 に置き、何ともぶつからない(農地・プレイヤー・他のモンスターを通過する)
##   プレイヤーの攻撃範囲(全レイヤーを検出)には当たる

## HP が 0 になって消えるときに発行される(ドロップ処理などが受け取る)
signal died(monster: Monster)

const DAMAGEABLE_GROUP: StringName = &"damageable"
const PLAYER_GROUP: StringName = &"player"
const FARM_MAP_GROUP: StringName = &"farm_map"
const MESSAGE_GROUP: StringName = &"message_display"
const NO_CELL: Vector2i = Vector2i(-1, -1)
## 作物マスの中心にこの距離(基準タイルのpx)まで近づいたら「到着」
const ARRIVE_DISTANCE_PX: float = 4.0
## 「作物が荒らされた!」を表示する秒数
const RUIN_MESSAGE_SECONDS: float = 1.0

## このモンスターの種類のデータ。add_child する前に設定する
@export var data: MonsterData
## プレイヤーに連続でダメージを与えない間隔(秒)
@export var contact_cooldown_seconds: float = 1.0
## 被弾で白く点滅する秒数
@export var flash_seconds: float = 0.1
## 倒したときにドロップアイテムとして出すシーン(Pickup)
@export var pickup_scene: PackedScene
## ドロップアイテムが足元から散らばる最大の距離(px)
@export var drop_scatter_px: float = 12.0
## 検知範囲外でうろうろするときの速さ(移動速度に対する割合)
@export var wander_speed_ratio: float = 0.3
## うろうろの方向を変える間隔(秒)の最小・最大
@export var wander_interval_min: float = 1.5
@export var wander_interval_max: float = 3.0
## うろうろの切り替えで、止まる確率(0〜1)
@export_range(0.0, 1.0) var wander_idle_chance: float = 0.4

var hp: int = 0

var _dead: bool = false
var _player: Node2D = null
var _contact_cooldown_left: float = 0.0
var _flash_left: float = 0.0
var _wander_left: float = 0.0
var _wander_direction: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _farm_map: FarmMap = null
## 荒らし中のマス(なければ NO_CELL)と、そのマスに留まっている秒数
var _ruin_cell: Vector2i = NO_CELL
var _ruin_elapsed: float = 0.0

@onready var _body: Sprite2D = $Body
@onready var _flash: Sprite2D = $Flash
@onready var _hit_area: Area2D = $HitArea


func _ready() -> void:
	add_to_group(DAMAGEABLE_GROUP)
	_rng.randomize()
	if data == null:
		push_error("Monster: data(MonsterData)が未設定です")
		set_physics_process(false)
		return
	hp = data.max_hp
	_setup_visuals()
	_update_color()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_contact_cooldown_left = maxf(_contact_cooldown_left - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_update_color()

	_move(delta)
	_try_contact_damage()


## 被ダメージ。HP が 0 になったら消える
func take_damage(amount: int) -> void:
	if _dead or amount <= 0:
		return
	hp = maxi(hp - amount, 0)
	_flash_left = flash_seconds
	_update_color()
	if hp == 0:
		_die()


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	SeasonStats.add_kill()
	_drop_items()
	died.emit(self)
	queue_free()


## ドロップ表の各エントリを独立に抽選し、当たったものを足元(少し散らして)に出す
func _drop_items() -> void:
	var container: Node2D = get_parent() as Node2D
	if pickup_scene == null or container == null:
		return
	for entry in data.drops:
		var drop: DropEntry = entry as DropEntry
		if drop == null:
			continue
		var count: int = drop.roll(_rng)
		if count <= 0:
			continue
		var pickup: Pickup = pickup_scene.instantiate() as Pickup
		if pickup == null:
			push_error("Monster: pickup_scene のルートが Pickup ではありません")
			return
		pickup.item = drop.item
		pickup.count = count
		var scatter: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, drop_scatter_px)
		pickup.position = container.to_local(global_position + scatter)
		# 物理の処理中に呼ばれることがあるので、追加は後回しにする
		container.add_child.call_deferred(pickup)
		DebugFlags.record_drop(drop.item.id, count)


func _move(delta: float) -> void:
	var player: Node2D = _get_player()
	var direction: Vector2 = Vector2.ZERO
	var speed: float = data.move_speed
	if player != null and global_position.distance_to(player.global_position) <= Balance.data.monster_detection_range:
		# 検知範囲内: プレイヤーを優先して、直線で近づく
		_reset_ruin()
		direction = (player.global_position - global_position).normalized()
	else:
		var crop_cell: Vector2i = _find_nearest_crop_cell()
		if crop_cell != NO_CELL:
			# 最寄りの作物マスへ向かい、到着したら留まって荒らす
			if crop_cell != _ruin_cell:
				_ruin_cell = crop_cell
				_ruin_elapsed = 0.0
			var to_target: Vector2 = GridUtils.cell_to_world_center(crop_cell) - global_position
			if to_target.length() <= GameConfig.px(ARRIVE_DISTANCE_PX):
				_update_ruin(delta)
			else:
				_ruin_elapsed = 0.0
				direction = to_target.normalized()
		else:
			# 作物がない: ゆっくりランダムに歩く(または止まる)
			_reset_ruin()
			_wander_left -= delta
			if _wander_left <= 0.0:
				_pick_wander()
			direction = _wander_direction
			speed *= wander_speed_ratio
	velocity = direction * speed
	move_and_slide()
	_keep_inside_map()


## 作物マスに留まっている間の処理。ruin_seconds 経ったら作物を荒らす
func _update_ruin(delta: float) -> void:
	_ruin_elapsed += delta
	if _ruin_elapsed < Balance.data.ruin_seconds:
		return
	_ruin_elapsed = 0.0
	var farm_map: FarmMap = _get_farm_map()
	if farm_map != null and farm_map.ruin_crop(_ruin_cell):
		var messages: MessageDisplay = get_tree().get_first_node_in_group(MESSAGE_GROUP) as MessageDisplay
		if messages != null:
			messages.show_message("作物が荒らされた!", RUIN_MESSAGE_SECONDS)


func _reset_ruin() -> void:
	_ruin_cell = NO_CELL
	_ruin_elapsed = 0.0


## 作物が植わっているマスのうち、最寄り(中心までの距離)のものを返す。なければ NO_CELL
func _find_nearest_crop_cell() -> Vector2i:
	var farm_map: FarmMap = _get_farm_map()
	if farm_map == null:
		return NO_CELL
	var best: Vector2i = NO_CELL
	var best_distance: float = INF
	for cell_key in farm_map.cells.keys():
		var cell: Vector2i = cell_key
		var cell_data: CellData = farm_map.cells[cell]
		if not cell_data.has_crop():
			continue
		var distance: float = global_position.distance_squared_to(GridUtils.cell_to_world_center(cell))
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


func _get_farm_map() -> FarmMap:
	if _farm_map == null or not is_instance_valid(_farm_map):
		_farm_map = get_tree().get_first_node_in_group(FARM_MAP_GROUP) as FarmMap
	return _farm_map


func _pick_wander() -> void:
	_wander_left = _rng.randf_range(wander_interval_min, wander_interval_max)
	if _rng.randf() < wander_idle_chance:
		_wander_direction = Vector2.ZERO
	else:
		_wander_direction = Vector2.from_angle(_rng.randf() * TAU)


## マップの外へ出ないようにする
func _keep_inside_map() -> void:
	var map_size: Vector2 = Vector2(GridUtils.MAP_SIZE * GridUtils.TILE_SIZE)
	var margin: float = float(GridUtils.TILE_SIZE) * 0.5
	global_position = global_position.clamp(Vector2(margin, margin), map_size - Vector2(margin, margin))


## 触れているプレイヤーにダメージを与える(クールダウン中は与えない)
func _try_contact_damage() -> void:
	if _contact_cooldown_left > 0.0:
		return
	for body in _hit_area.get_overlapping_bodies():
		var target: Player = body as Player
		if target != null:
			target.take_damage(data.contact_damage)
			_contact_cooldown_left = contact_cooldown_seconds
			return


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	return _player


## 見た目と当たり判定を、データとタイルサイズに合わせる
func _setup_visuals() -> void:
	SpriteProvider.apply(_body, data.get_sprite_id(), data.get_placeholder_spec())
	SpriteProvider.apply(_flash, &"effects/hit_flash")
	_flash.position = _body.position
	var body_shape: RectangleShape2D = ($CollisionShape2D as CollisionShape2D).shape as RectangleShape2D
	if body_shape != null:
		body_shape.size = Vector2.ONE * GameConfig.px(14.0)
	var hit_shape: RectangleShape2D = ($HitArea/CollisionShape2D as CollisionShape2D).shape as RectangleShape2D
	if hit_shape != null:
		hit_shape.size = Vector2.ONE * GameConfig.px(16.0)


## 被弾の点滅(白い四角を上に重ねる)
func _update_color() -> void:
	_flash.visible = _flash_left > 0.0
