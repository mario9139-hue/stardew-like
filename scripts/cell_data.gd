class_name CellData
extends RefCounted
## 1マス分の状態。FarmMap が Dictionary(座標 → CellData)で保持する。

enum Soil { GRASS, TILLED }

var soil: Soil = Soil.GRASS
## 植えられている作物。null なら種なし
var crop: CropData = null
## 成長日数(水やりした日だけ進む)
var growth_progress: int = 0
## 次の日替わり1回だけ適用する成長ボーナス日数。日替わり処理後に0へ戻る
var growth_bonus_days: int = 0
## 収穫品質。0=通常 / 1=高品質
var quality: int = 0
## 水やり済みか(日替わりでリセットされる)
var is_watered: bool = false


func has_crop() -> bool:
	return crop != null


## 成長完了(収穫可能)か
func is_harvestable() -> bool:
	return crop != null and crop.is_mature(growth_progress)
