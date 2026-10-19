class_name CropData
extends Resource
## 作物1種類分のデータ。data/crops/*.tres として定義する。

@export var id: StringName = &""
@export var display_name: String = ""
## 種の価格(G)
@export var seed_price: int = 0
## 収穫可能になるまでの成長日数(水やりした日だけ進む)
@export var growth_days: int = 1
## 収穫後に再び実るまでの日数。0なら単発(収穫すると消える)
@export var regrow_days: int = 0
## 売値(G)
@export var sell_price: int = 0
## 段階ごとの仮色(先頭が種まき直後、末尾が収穫可能)
@export var stage_colors: PackedColorArray = PackedColorArray()
## 収穫すると手に入るアイテム(種アイテムからこの作物へは ItemData.crop で参照する)
@export var harvest_item: ItemData


## 成長日数が成長完了に達しているか
func is_mature(progress: int) -> bool:
	return progress >= growth_days


## 成長日数に応じた段階番号(0 〜 stage_colors.size() - 1)
func get_stage(progress: int) -> int:
	var max_stage: int = stage_colors.size() - 1
	if max_stage <= 0 or growth_days <= 0:
		return maxi(max_stage, 0)
	if progress >= growth_days:
		return max_stage
	return floori(float(progress * max_stage) / float(growth_days))


func get_stage_color(progress: int) -> Color:
	if stage_colors.is_empty():
		return Color.MAGENTA
	return stage_colors[get_stage(progress)]
