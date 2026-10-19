class_name DayManager
extends Node
## 日替わり処理の集約。
## - next_day(): 終了(精算など) → 作物の成長・水やりリセット → 日数+1・時刻を6:00に戻す
## - sleep(): 暗転 → next_day() → 家の前にリスポーン → 明転。家のEキーと26:00の強制就寝から呼ぶ
## - F1(debug_next_day): デバッグ用。同じ next_day() を呼ぶ(暗転・リスポーンなし)
## 作物の成長・水やりリセットは、next_day() の中だけで行う。

## 日替わりの最初に発行される。終了処理(売却箱の精算など)が受け取る。引数は終わる日
signal day_finished(day: int)
## 日替わりが完了したときに発行される。引数は新しい日
signal day_changed(day: int)
## 就寝が完了したときに発行される。forced は 26:00 の強制就寝か(false なら任意の就寝)
signal slept(forced: bool)

@export var farm_map_path: NodePath = ^"../FarmMap"
@export var player_path: NodePath = ^"../Player"
@export var house_path: NodePath = ^"../House"
@export var fader_path: NodePath = ^"../ScreenFader"
## 動作確認用: 日が進む/夜の開始/日の終わりのたびに Output へログを出す(不要になったら false に)
@export var debug_log: bool = true

## 現在の日(1日目から)。実体は GameClock が持つ
var day: int:
	get:
		return GameClock.day

var _farm_map: FarmMap
var _player: Player
var _house: House
var _fader: ScreenFader
var _is_sleeping: bool = false


func _ready() -> void:
	_farm_map = get_node_or_null(farm_map_path) as FarmMap
	_player = get_node_or_null(player_path) as Player
	_house = get_node_or_null(house_path) as House
	_fader = get_node_or_null(fader_path) as ScreenFader
	var missing: PackedStringArray = []
	if _farm_map == null:
		missing.append("farm_map")
	if _player == null:
		missing.append("player")
	if _house == null:
		missing.append("house")
	if _fader == null:
		missing.append("fader")
	if not missing.is_empty():
		push_error("DayManager: 参照を取得できません / " + ", ".join(missing))

	GameClock.night_started.connect(_on_night_started)
	GameClock.day_ended.connect(_on_day_ended)
	if _house != null:
		_house.sleep_requested.connect(sleep)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_next_day") and not GameClock.is_season_over:
		next_day()


## 日替わり処理本体
func next_day() -> void:
	# 1. 終了: 売却箱の精算など
	day_finished.emit(GameClock.day)
	# 2. 作物の成長(水やり済みのみ)と水やりフラグのリセット
	if _farm_map != null:
		_farm_map.advance_day()
	# 3. 日数+1、時刻を6:00に戻す(28日を超えたら season_ended)
	GameClock.start_new_day()
	day_changed.emit(GameClock.day)
	if debug_log:
		print("[DayManager] %d日目になった" % GameClock.day)


## 就寝する: 暗転 → 日替わり → 体力回復 → 家の前にリスポーン → 明転
## forced が true なら 26:00 の強制就寝(翌朝の体力は半分)、false なら任意の就寝(全回復)
func sleep(forced: bool = false) -> void:
	if _is_sleeping or GameClock.is_season_over:
		return
	_is_sleeping = true
	get_tree().paused = true
	if _fader != null:
		await _fader.fade_out()
	next_day()
	PlayerStats.restore_on_sleep(forced)
	_respawn_player()
	slept.emit(forced)
	if _fader != null:
		await _fader.fade_in()
	if not GameClock.is_season_over:
		get_tree().paused = false
	_is_sleeping = false


func _respawn_player() -> void:
	if _player == null or _house == null:
		return
	_player.global_position = _house.get_spawn_position()
	_player.velocity = Vector2.ZERO
	_player.clear_move_target()
	_player.clear_move_direction()
	_player.facing = Vector2.DOWN


func _on_night_started() -> void:
	if debug_log:
		print("[DayManager] 夜の開始(%s)" % GameClock.get_time_text())


func _on_day_ended() -> void:
	# 26:00 に到達: 強制的に就寝する
	if debug_log:
		print("[DayManager] 日の終わり(%s)→強制就寝" % GameClock.get_time_text())
	sleep(true)
