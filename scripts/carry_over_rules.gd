class_name CarryOverRules
extends Resource
## 次のシーズンへ引き継ぐ項目の定義(data/carry_over_rules.tres)。
## 引き継ぎの内容を変えるときは、このリソースの値だけを変える。

## 所持金を引き継ぐ(false なら初期の所持金に戻る)
@export var keep_money: bool = true
## 武器(所持・装備)を引き継ぐ
@export var keep_weapons: bool = true
## 所持品(収穫物・種・強化素材など)を引き継ぐ(false なら新規開始と同じ初期所持品)
@export var keep_inventory: bool = true
## 結果画面のクリアボーナス(CarryOver.bonus_items)を所持品に追加する
@export var keep_bonus_items: bool = true
