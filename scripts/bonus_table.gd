class_name BonusTable
extends Resource
## クリアボーナス表。ランクごとに「アイテムid・個数」の配列を持つ(data/bonus/default.tres)。
## ボーナスの追加・変更は .tres のデータだけで済む(レア種を足すときも、行を足すだけ)。
## 例: rewards = { "S": [ {"id": &"turnip_seed", "count": 10}, ... ] }

## ランク("S" / "A" / "B" / "C")→ [ {"id": StringName, "count": int}, ... ]
@export var rewards: Dictionary = {}

## アイテムの .tres の置き場所(ファイル名 = アイテムid)
const ITEM_DIR: String = "res://data/items"


## そのランクのボーナス一覧(コピー)。表にないランクは空
func get_rewards(rank: String) -> Array:
	var result: Array = []
	for entry in rewards.get(rank, []):
		var item_id: StringName = StringName(String(entry.get("id", "")))
		var count: int = int(entry.get("count", 0))
		if item_id != &"" and count > 0:
			result.append({"id": item_id, "count": count})
	return result


## アイテムidから ItemData を取得する(見つからなければ null)
static func find_item(item_id: StringName) -> ItemData:
	var path: String = "%s/%s.tres" % [ITEM_DIR, String(item_id)]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ItemData


## 表示用の名前(ItemData が見つからなければ id)
static func get_item_name(item_id: StringName) -> String:
	var item: ItemData = find_item(item_id)
	return item.display_name if item != null else String(item_id)
