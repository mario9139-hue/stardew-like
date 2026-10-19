class_name Shop
extends Interactable
## 店(仮の色付きオブジェクト)。近づいてEキー(または共通アクションボタン)で購入画面を開く。
## 品揃えは ShopEntry(data/shop/*.tres)の配列で持つ。

## 売る商品(ShopEntry の配列)
@export var entries: Array = []
@export var screen_path: NodePath = ^"../ShopScreen"

var _screen: ShopScreen


func _ready() -> void:
	_screen = get_node_or_null(screen_path) as ShopScreen
	if _screen == null:
		push_error("Shop: ShopScreen を取得できません")


func interact() -> bool:
	if _screen == null:
		return false
	_screen.open(entries)
	return true
