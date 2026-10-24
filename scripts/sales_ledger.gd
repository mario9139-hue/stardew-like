extends Node
## 売上の記録(Autoload: SalesLedger)。
## 「その日の売上」と累計売上を保持する。クリアランクなどの評価に後で使う。
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

signal sales_recorded(day: int, amount: int)

## 動作確認用: 記録のたびに Output へログを出す(不要になったら false に)
var debug_log: bool = true

## 日 → その日の売上(G)
var daily_sales: Dictionary = {}
## 累計売上(G)
var total_sales: int = 0


## その日の売上を記録する(同じ日に複数回記録すると加算される)
func record(day: int, amount: int) -> void:
	daily_sales[day] = get_daily_sales(day) + amount
	total_sales += amount
	sales_recorded.emit(day, amount)
	if debug_log:
		print("[SalesLedger] %d日目の売上=%dG 累計売上=%dG" % [day, get_daily_sales(day), total_sales])


## 売上の記録を空にする(新しいシーズン用)
func reset() -> void:
	daily_sales.clear()
	total_sales = 0


## 売上の記録を復元する(ロード用)
func restore_state(daily: Dictionary, total: int) -> void:
	daily_sales = daily
	total_sales = total


func get_daily_sales(day: int) -> int:
	return daily_sales.get(day, 0)
