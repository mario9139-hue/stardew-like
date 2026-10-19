extends Node
## プレイヤーの体力とじょうろの残量(Autoload: PlayerStats)。
## 現在値が変わるたびにシグナルを発行する。値は export 変数で調整できる
## (scenes/player_stats.tscn を開いてインスペクタで変更)。
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

signal stamina_changed(current: int, maximum: int)
signal water_changed(current: int, maximum: int)

@export var max_stamina: int = 100
## じょうろの最大容量
@export var max_water: int = 20

@export_group("体力の消費量")
@export var stamina_cost_till: int = 3
@export var stamina_cost_seed: int = 1
@export var stamina_cost_water: int = 2
@export var stamina_cost_harvest: int = 0

@export_group("就寝")
## 26:00 の強制就寝時に、翌朝の体力を最大値の何割にするか(任意の就寝は全回復)
@export_range(0.0, 1.0) var forced_sleep_stamina_ratio: float = 0.5

## 現在の体力
var stamina: int = 0
## じょうろの現在の残量
var water: int = 0


func _ready() -> void:
	stamina = max_stamina
	water = max_water


## 体力を amount 消費する。足りなければ何も変えず false を返す
func consume_stamina(amount: int) -> bool:
	if amount <= 0:
		return true
	if amount > stamina:
		return false
	_set_stamina(stamina - amount)
	return true


## 就寝時の体力回復。任意の就寝は全回復、26:00 の強制就寝は最大値の forced_sleep_stamina_ratio
## (じょうろの残量は就寝しても変わらない)
func restore_on_sleep(forced: bool) -> void:
	if forced:
		_set_stamina(roundi(max_stamina * forced_sleep_stamina_ratio))
	else:
		_set_stamina(max_stamina)


func get_stamina_ratio() -> float:
	return float(stamina) / float(maxi(max_stamina, 1))


## じょうろの水を amount 使う。足りなければ何も変えず false を返す
func consume_water(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if amount > water:
		return false
	_set_water(water - amount)
	return true


## じょうろを満タンにする
func refill_water() -> void:
	_set_water(max_water)


func _set_stamina(value: int) -> void:
	var clamped: int = clampi(value, 0, max_stamina)
	if clamped == stamina:
		return
	stamina = clamped
	stamina_changed.emit(stamina, max_stamina)


func _set_water(value: int) -> void:
	var clamped: int = clampi(value, 0, max_water)
	if clamped == water:
		return
	water = clamped
	water_changed.emit(water, max_water)
