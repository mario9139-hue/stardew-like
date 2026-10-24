class_name DropEntry
extends Resource
## ドロップ表の1行。MonsterData.drops に並べる。各行は独立に抽選される。

## 落とすアイテム
@export var item: ItemData
## 落とす確率(0〜1)。Balance.drop_chances に同じアイテムの設定があれば、そちらが優先される
@export_range(0.0, 1.0) var chance: float = 1.0
## 落ちたときの個数の最小・最大
@export var min_count: int = 1
@export var max_count: int = 1


## 抽選して、落とす個数を返す(落とさないときは 0)
func roll(rng: RandomNumberGenerator) -> int:
	if item == null or min_count <= 0 and max_count <= 0:
		return 0
	if rng.randf() >= Balance.data.get_drop_chance(item.id, chance):
		return 0
	var low: int = maxi(mini(min_count, max_count), 1)
	var high: int = maxi(max_count, low)
	return rng.randi_range(low, high)
