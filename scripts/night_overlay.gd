class_name NightOverlay
extends CanvasModulate
## 夜の暗さの演出。ワールド(マップ・キャラ・敵)だけを暗くし、HUD などの CanvasLayer は暗くしない。
## - 暗さは 21:00 に 0 から始まり、night_darkest_hour で最大になる(その後 26:00 まで最大のまま)
## - 日が替わる(就寝・気絶・26:00)と、night_fade_seconds かけて元の明るさに戻る
## - 色・強さ・時刻は Balance(data/balance.tres)で調整する
## ツリーがポーズ中(就寝)でも戻りのフェードが進むよう、常に動かす。

## 現在の暗さ(0=昼の明るさ、1=最大)
var _level: float = 0.0
## 目標の暗さ(時刻から決まる)
var _target: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color.WHITE
	GameClock.time_changed.connect(_on_time_changed)
	GameClock.day_started.connect(_on_day_started)
	_on_time_changed(GameClock.get_hour(), GameClock.get_minute())


func _process(delta: float) -> void:
	var fade_seconds: float = maxf(Balance.data.night_fade_seconds, 0.01)
	_level = move_toward(_level, _target, delta / fade_seconds)
	color = Color.WHITE.lerp(Balance.data.night_color, _level * clampf(Balance.data.night_strength, 0.0, 1.0))


func _on_time_changed(hour: int, minute: int) -> void:
	var now: float = float(hour) + float(minute) / 60.0
	var start: float = float(GameClock.NIGHT_START_HOUR)
	var darkest: float = maxf(Balance.data.night_darkest_hour, start + 0.01)
	_target = clampf((now - start) / (darkest - start), 0.0, 1.0)


## 新しい日: 昼の明るさへ戻す(フェード)
func _on_day_started(_day: int) -> void:
	_target = 0.0
