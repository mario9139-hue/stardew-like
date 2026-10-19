class_name ShopEntry
extends Resource
## 店の商品1つ分。data/shop/*.tres として定義し、店(Shop)が配列で持つ。

## 売るアイテム
@export var item: ItemData
## 価格(G)
@export var price: int = 0
