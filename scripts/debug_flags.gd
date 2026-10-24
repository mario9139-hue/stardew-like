extends Node
## デバッグ機能の一括スイッチと、通し確認用のログ集計(Autoload: DebugFlags)。
## - DEBUG_ENABLED が false の間、デバッグキー(F1〜F7)とこのファイルのログは全部止まる
## - F8 で実行中に切り替える(F8 自体は常に効く)
## - 完全に無効にしたいときは DEFAULT_ENABLED を false にする

const DEFAULT_ENABLED: bool = true

var DEBUG_ENABLED: bool = DEFAULT_ENABLED

## 夜の間の集計(day_started で出力してリセット)
var _night_dropped: Dictionary = {}
var _night_picked: Dictionary = {}
## 昼の間の強化素材の使用(night_started で出力してリセット)
var _day_used: Dictionary = {}


func _ready() -> void:
	GameClock.night_started.connect(_on_night_started)
	GameClock.day_started.connect(_on_day_started)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		DEBUG_ENABLED = not DEBUG_ENABLED
		print("[Debug] デバッグ機能 %s(F8で切替)" % ("ON" if DEBUG_ENABLED else "OFF"))


## モンスターがアイテムを落とした
func record_drop(item_id: StringName, amount: int) -> void:
	if not DEBUG_ENABLED:
		return
	_add(_night_dropped, item_id, amount)
	print("[Debug] ドロップ %s x%d(今夜の合計 %d個)" % [item_id, amount, _sum(_night_dropped)])


## プレイヤーがドロップを拾った
func record_pickup(item_id: StringName, amount: int) -> void:
	if not DEBUG_ENABLED:
		return
	_add(_night_picked, item_id, amount)
	print("[Debug] 拾得 %s x%d(今夜の拾得合計 %d個)" % [item_id, amount, _sum(_night_picked)])


## 強化素材を畑に使った。detail に効果の中身(例: 成長+1日)を入れる
func record_enhancement_use(item_id: StringName, cell: Vector2i, detail: String) -> void:
	if not DEBUG_ENABLED:
		return
	_add(_day_used, item_id, 1)
	print("[Debug] 強化素材を使用 %s cell=%s %s(今日の使用合計 %d個)" % [item_id, cell, detail, _sum(_day_used)])


## 成長・品質効果が日替わりで反映された結果
func log_effect(message: String) -> void:
	if DEBUG_ENABLED:
		print("[Debug] %s" % message)


func _on_night_started() -> void:
	if DEBUG_ENABLED:
		print("[Debug] ===== 夜開始(昼の強化素材使用: %s)=====" % _format(_day_used))
	_day_used.clear()
	_night_dropped.clear()
	_night_picked.clear()


func _on_day_started(day: int) -> void:
	if DEBUG_ENABLED:
		print("[Debug] ===== %d日目開始 / 昨夜の結果: ドロップ %s(%d個) 拾得 %s(%d個) =====" % [
			day, _format(_night_dropped), _sum(_night_dropped), _format(_night_picked), _sum(_night_picked)])
	_night_dropped.clear()
	_night_picked.clear()


func _add(target: Dictionary, item_id: StringName, amount: int) -> void:
	target[item_id] = int(target.get(item_id, 0)) + amount


func _sum(source: Dictionary) -> int:
	var total: int = 0
	for key in source.keys():
		total += int(source[key])
	return total


func _format(source: Dictionary) -> String:
	if source.is_empty():
		return "なし"
	var parts: PackedStringArray = []
	for key in source.keys():
		parts.append("%s x%d" % [key, int(source[key])])
	return ", ".join(parts)
