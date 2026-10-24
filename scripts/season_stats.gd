extends Node
## 今シーズンの統計とランク評価(Autoload: SeasonStats)。
## - 累計売上は SalesLedger(8)から読む。撃破数・荒らされた作物数・収穫数はここで数える
## - 28日目の日替わり(精算のあと)に GameClock.season_ended が来たら、ランクを決めて season_finished を発行する
## - ランクの基準は Balance(data/balance.tres)の rank_*_sales で調整する
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

## シーズン終了時に1回発行される。rank は "S" / "A" / "B" / "C"
signal season_finished(rank: String, summary: Dictionary)

## 動作確認用: 記録・ランクを Output へ出す(不要になったら false に)
var debug_log: bool = true

## 撃破数
var kills: int = 0
## 荒らされた作物数
var ruined_crops: int = 0
## 収穫数
var harvests: int = 0
## 確定したランク(シーズン終了前は空)
var rank: String = ""


func _ready() -> void:
	GameClock.season_ended.connect(_on_season_ended)


## 今シーズンの統計を空にする(新しいシーズン用。累計売上は SalesLedger 側をリセットする)
func reset() -> void:
	kills = 0
	ruined_crops = 0
	harvests = 0
	rank = ""


## 統計を復元する(ロード用)
func restore_state(kill_count: int, ruined_count: int, harvest_count: int, saved_rank: String) -> void:
	kills = kill_count
	ruined_crops = ruined_count
	harvests = harvest_count
	rank = saved_rank


func add_kill() -> void:
	kills += 1
	_log("撃破 累計=%d" % kills)


func add_ruined_crop() -> void:
	ruined_crops += 1
	_log("荒らされた作物 累計=%d" % ruined_crops)


func add_harvest() -> void:
	harvests += 1
	_log("収穫 累計=%d" % harvests)


## 累計売上(G)
func get_total_sales() -> int:
	return SalesLedger.total_sales


## 累計売上からランクを決める(C: B未満 / B / A / S)
func calculate_rank(total_sales: int) -> String:
	if total_sales >= Balance.data.rank_s_sales:
		return "S"
	if total_sales >= Balance.data.rank_a_sales:
		return "A"
	if total_sales >= Balance.data.rank_b_sales:
		return "B"
	return "C"


## 統計のまとめ(結果画面用)
func get_summary() -> Dictionary:
	return {
		"total_sales": get_total_sales(),
		"kills": kills,
		"ruined_crops": ruined_crops,
		"harvests": harvests,
		"rank": rank,
	}


func _on_season_ended() -> void:
	rank = calculate_rank(get_total_sales())
	var summary: Dictionary = get_summary()
	print("[SeasonStats] シーズン終了 ランク=%s 累計売上=%dG 撃破=%d 荒らされた作物=%d 収穫=%d" % [
		rank, summary["total_sales"], kills, ruined_crops, harvests])
	season_finished.emit(rank, summary)


func _log(message: String) -> void:
	if debug_log:
		print("[SeasonStats] %s" % message)
