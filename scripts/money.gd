extends Node
## 所持金(Autoload: Money)。変更のたびに changed を発行する。
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

signal changed(amount: int)

const STARTING_AMOUNT: int = 500

var amount: int = STARTING_AMOUNT


## 所持金を増やす(0以下は無視)
func add(value: int) -> void:
	if value <= 0:
		return
	amount += value
	changed.emit(amount)


## 所持金を使う。足りなければ何も変えず false を返す
func spend(value: int) -> bool:
	if value <= 0 or value > amount:
		return false
	amount -= value
	changed.emit(amount)
	return true


func can_afford(value: int) -> bool:
	return value <= amount
