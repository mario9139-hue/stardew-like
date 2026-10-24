class_name MonsterSpawner
extends Node2D
## モンスターを出す場所。生成したモンスターはこのノードの子になる。
## - 夜(GameClock.night_started = 21:00)になると、spawn_interval_seconds ごとに自動で出現する
##   (同時に場にいるのは max_monsters 体まで)
## - 日の終わり(26:00)・就寝・気絶(= 日が替わる)で、場にいる敵を全部消して、出現も止める
## - 夜以外は自動では一体も出ない(出た敵が作物を荒らす処理は Monster 側)
## - F7(debug_spawn_monster)は、時間に関係なく1体出すデバッグ用

@export var monster_scene: PackedScene
## 出現させるモンスターの候補(MonsterData の配列)。今はスライムだけ
@export var monster_pool: Array = []

@export_group("夜のスポーン")
## 出現の間隔・同時数・プレイヤーからの最小距離は Balance(data/balance.tres)で調整する
## 出現できるエリア(Rect2 の配列)。空のときは、マップの外周の幅2マスで、農地の外側(GameConfig から計算)
@export var spawn_areas: Array = []

@export_group("デバッグ")
@export var player_path: NodePath = ^"../Player"
## F7 の出現: プレイヤーから離れる距離(px)。検知範囲(150px)内に入る距離にしてある
@export var debug_spawn_distance: float = 100.0
## 動作確認用: 出現・消滅のログを Output へ出す(不要になったら false に)
@export var debug_log: bool = true

## 位置を選ぶときに、ランダムな点を試す回数
const SPAWN_POSITION_ATTEMPTS: int = 30

var _player: Player
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 夜のスポーン中か
var _night_active: bool = false
var _spawn_timer: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null(player_path) as Player
	if _player == null:
		push_warning("MonsterSpawner: Player を取得できません(F7 の出現位置は画面中央、夜の出現距離は判定しません)")
	GameClock.night_started.connect(_on_night_started)
	# 26:00 の日の終わり、および就寝・気絶(どちらも日が替わる)で全消滅させる
	GameClock.day_ended.connect(_on_day_over)
	GameClock.day_started.connect(_on_day_started)


func _physics_process(delta: float) -> void:
	if not _night_active:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = Balance.data.spawn_interval_seconds
	_spawn_at_night()


func _unhandled_input(event: InputEvent) -> void:
	if DebugFlags.DEBUG_ENABLED and event.is_action_pressed(&"debug_spawn_monster"):
		spawn_monster(_pick_monster_data(), _pick_debug_position())


## モンスターを1体出す。出せたら Monster、出せなければ null
func spawn_monster(data: MonsterData, spawn_position: Vector2) -> Monster:
	if monster_scene == null or data == null:
		push_error("MonsterSpawner: monster_scene / MonsterData が未設定です")
		return null
	var monster: Monster = monster_scene.instantiate() as Monster
	if monster == null:
		push_error("MonsterSpawner: monster_scene のルートが Monster ではありません")
		return null
	# add_child の前に data と位置を渡す(_ready で data から初期化される)
	monster.data = data
	monster.position = spawn_position
	add_child(monster)
	if debug_log:
		print("[MonsterSpawner] %s を出現 位置=%s 場の数=%d" % [data.display_name, spawn_position, get_monster_count()])
		monster.died.connect(_on_monster_died)
	return monster


## デバッグ用: 時間に関係なく1体出す(F7・タッチの召喚ボタン共通)
func debug_spawn() -> void:
	if DebugFlags.DEBUG_ENABLED:
		spawn_monster(_pick_monster_data(), _pick_debug_position())


## 場にいる敵を全部消す(倒したのではないので、ドロップはしない)
func clear_monsters() -> void:
	var removed: int = 0
	for child in get_children():
		var monster: Monster = child as Monster
		if monster != null and not monster.is_queued_for_deletion():
			monster.queue_free()
			removed += 1
	if debug_log and removed > 0:
		print("[MonsterSpawner] 場の敵を全消滅(%d体)" % removed)


## 場にいる敵の数
func get_monster_count() -> int:
	var count: int = 0
	for child in get_children():
		var monster: Monster = child as Monster
		if monster != null and not monster.is_queued_for_deletion():
			count += 1
	return count


func _on_night_started() -> void:
	_night_active = true
	_spawn_timer = Balance.data.spawn_interval_seconds
	if debug_log:
		print("[MonsterSpawner] 夜のスポーン開始(%.0f秒ごと、最大%d体)" % [Balance.data.spawn_interval_seconds, Balance.data.max_monsters])


func _on_day_over() -> void:
	_stop_night()


func _on_day_started(_day: int) -> void:
	_stop_night()


func _stop_night() -> void:
	_night_active = false
	clear_monsters()


func _on_monster_died(monster: Monster) -> void:
	print("[MonsterSpawner] %s を倒した" % monster.data.display_name)


## 夜の出現: 上限に達していなければ、有効な位置に1体出す
func _spawn_at_night() -> void:
	if get_monster_count() >= Balance.data.max_monsters:
		return
	var spawn_position: Vector2 = _pick_night_position()
	if not spawn_position.is_finite():
		if debug_log:
			print("[MonsterSpawner] 出現位置なし(プレイヤーから%.0fpx以上離れた出現エリアがない)" % Balance.data.min_player_distance)
		return
	spawn_monster(_pick_monster_data(), spawn_position)


## 出現させるモンスターを選ぶ。今は monster_pool から一様に選ぶ。
## 重み付けを入れるときは、この関数だけを差し替えればよい
## (例: MonsterData に spawn_weight を足して、重みつき抽選にする)
func _pick_monster_data() -> MonsterData:
	var candidates: Array[MonsterData] = []
	for entry in monster_pool:
		var data: MonsterData = entry as MonsterData
		if data != null:
			candidates.append(data)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi() % candidates.size()]


## spawn_areas の中から、プレイヤーから min_player_distance 以上離れた位置をランダムに選ぶ。
## 見つからなければ Vector2.INF を返す
func _pick_night_position() -> Vector2:
	var areas: Array[Rect2] = _get_spawn_areas()
	if areas.is_empty():
		return Vector2.INF
	for i: int in SPAWN_POSITION_ATTEMPTS:
		var area: Rect2 = _pick_area(areas)
		var candidate: Vector2 = Vector2(
			_rng.randf_range(area.position.x, area.end.x),
			_rng.randf_range(area.position.y, area.end.y)
		)
		if _player == null or candidate.distance_to(_player.global_position) >= Balance.data.min_player_distance:
			return candidate
	return Vector2.INF


## マップの外周の幅2マスを4つの帯に分けたもの(上・下・左・右)
func _default_spawn_areas() -> Array[Rect2]:
	var map_size: Vector2 = GameConfig.map_pixel_size()
	var band: float = float(GameConfig.TILE_SIZE) * 2.0
	var areas: Array[Rect2] = []
	areas.append(Rect2(0.0, 0.0, map_size.x, band))
	areas.append(Rect2(0.0, map_size.y - band, map_size.x, band))
	areas.append(Rect2(0.0, band, band, map_size.y - band * 2.0))
	areas.append(Rect2(map_size.x - band, band, band, map_size.y - band * 2.0))
	return areas


func _get_spawn_areas() -> Array[Rect2]:
	if spawn_areas.is_empty():
		return _default_spawn_areas()
	var areas: Array[Rect2] = []
	for entry in spawn_areas:
		if typeof(entry) == TYPE_RECT2:
			var rect: Rect2 = entry
			if rect.has_area():
				areas.append(rect)
	return areas


## 面積に比例してエリアを選ぶ(広いエリアほど選ばれやすい)
func _pick_area(areas: Array[Rect2]) -> Rect2:
	var total: float = 0.0
	for area in areas:
		total += area.get_area()
	var roll: float = _rng.randf() * total
	for area in areas:
		roll -= area.get_area()
		if roll <= 0.0:
			return area
	return areas[areas.size() - 1]


## F7 の出現: プレイヤーから debug_spawn_distance 離れた、マップ内の位置を選ぶ
func _pick_debug_position() -> Vector2:
	var map_size: Vector2 = Vector2(GridUtils.MAP_SIZE * GridUtils.TILE_SIZE)
	if _player == null:
		return map_size * 0.5
	var map_rect: Rect2 = Rect2(Vector2.ZERO, map_size).grow(-float(GridUtils.TILE_SIZE))
	for i: int in 12:
		var candidate: Vector2 = _player.global_position + Vector2.from_angle(_rng.randf() * TAU) * debug_spawn_distance
		if map_rect.has_point(candidate):
			return candidate
	# どの向きもマップの外になる場合は、マップ内に押し込む
	var fallback: Vector2 = _player.global_position + Vector2.RIGHT * debug_spawn_distance
	return fallback.clamp(map_rect.position, map_rect.end)
