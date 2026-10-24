extends Node
## ゲーム内時間の管理(Autoload: GameClock)。
## 1日は 6:00 に始まり、26:00(24時以降も連続表記)で「日の終わり」。
## 時間は _process の delta で進めるので、ツリーがポーズ中は止まる。
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

## 21:00 に1回発行される(後で敵の出現に使う)
signal night_started
## 26:00 に到達したときに発行される。発行後、新しい日が始まるまで時計は止まる
signal day_ended
## ゲーム内の表示時刻(分)が変わるたびに発行される
signal time_changed(hour: int, minute: int)
## start_new_day() で新しい日が始まったときに発行される
signal day_started(day: int)
## 日数が SEASON_DAYS を超えたとき(シーズンの最終日が終わったとき)に発行される
signal season_ended

## シーズン(春)の日数
const SEASON_DAYS: int = 28
const DAY_START_HOUR: int = 6
const NIGHT_START_HOUR: int = 21
const DAY_END_HOUR: int = 26

## 現実の何秒でゲーム内の1時間が進むか
@export var real_seconds_per_game_hour: float = 10.0
## デバッグ用(F2)の倍速時の倍率
@export var debug_speed_multiplier: float = 40.0

## 現在の日(1日目から)
var day: int = 1
## デバッグ用の倍速中か
var is_fast: bool = false
## シーズンが終了したか(終了後は時計が止まる)
var is_season_over: bool = false

## 0:00 からの経過ゲーム内分(6:00 = 360.0、26:00 = 1560.0)
var _minutes: float = float(DAY_START_HOUR * 60)
var _last_minute: int = DAY_START_HOUR * 60
var _running: bool = true
var _night_emitted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if not _running or real_seconds_per_game_hour <= 0.0:
		return
	var speed: float = debug_speed_multiplier if is_fast and DebugFlags.DEBUG_ENABLED else 1.0
	_minutes += delta * 60.0 / real_seconds_per_game_hour * speed

	if not _night_emitted and _minutes >= float(NIGHT_START_HOUR * 60):
		_night_emitted = true
		night_started.emit()

	var day_ended_now: bool = _minutes >= float(DAY_END_HOUR * 60)
	if day_ended_now:
		_minutes = float(DAY_END_HOUR * 60)
		_running = false
	_emit_time_if_changed()
	if day_ended_now:
		day_ended.emit()


func _unhandled_input(event: InputEvent) -> void:
	if DebugFlags.DEBUG_ENABLED and event.is_action_pressed(&"debug_toggle_speed"):
		toggle_debug_speed()


## 次の日を始める(日数+1、時刻を 6:00 に戻し、時計が再び動く)
## 日数が SEASON_DAYS を超えたら、時計を止めて season_ended を発行する
func start_new_day() -> void:
	day += 1
	_minutes = float(DAY_START_HOUR * 60)
	_night_emitted = false
	_running = true
	_last_minute = -1
	_emit_time_if_changed()
	day_started.emit(day)
	if day > SEASON_DAYS:
		is_season_over = true
		_running = false
		season_ended.emit()


## 経過ゲーム内分(6:00 = 360.0)。セーブ用
func get_minutes() -> float:
	return _minutes


## 日と時刻を復元する(ロード用)。夜(21:00以降)なら night_started が次のフレームで再び発行される
func restore_state(day_value: int, minutes: float) -> void:
	day = clampi(day_value, 1, SEASON_DAYS)
	_minutes = clampf(minutes, float(DAY_START_HOUR * 60), float(DAY_END_HOUR * 60 - 1))
	is_fast = false
	is_season_over = false
	_night_emitted = false
	_running = true
	_last_minute = -1
	_emit_time_if_changed()


## 1日目の 6:00 に戻す(新規開始・次のシーズン用。シグナルは発行しない。シーンを読み込み直す前提)
func reset_for_new_season() -> void:
	day = 1
	is_fast = false
	is_season_over = false
	_minutes = float(DAY_START_HOUR * 60)
	_last_minute = DAY_START_HOUR * 60
	_running = true
	_night_emitted = false


## デバッグ用: 倍速 / 通常 を切り替える
func toggle_debug_speed() -> void:
	is_fast = not is_fast
	print("[GameClock] 速度 x%d" % (int(debug_speed_multiplier) if is_fast else 1))


## 時(24以降も連続。26:00 まで)
func get_hour() -> int:
	return floori(_minutes / 60.0)


func get_minute() -> int:
	return int(_minutes) % 60


## "HH:MM" 形式の時刻(例: 06:00 / 26:00)
func get_time_text() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


func _emit_time_if_changed() -> void:
	var current: int = int(_minutes)
	if current == _last_minute:
		return
	_last_minute = current
	time_changed.emit(get_hour(), get_minute())
