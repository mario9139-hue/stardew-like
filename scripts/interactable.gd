class_name Interactable
extends Node2D
## 近づいて Eキー(interact)で使えるオブジェクトの基底クラス。
## 家・売却箱などが継承し、interact() を上書きする。

## プレイヤーとの距離(px)がこの値以内なら使える
@export var interact_range: float = 32.0


func _enter_tree() -> void:
	add_to_group(&"interactable")


## 距離を測る基準位置(既定はこのノードの位置)
func get_interact_position() -> Vector2:
	return global_position


## プレイヤーがこの位置にいるとき使えるか(既定は interact_range 以内。継承先で上書きできる)
func can_interact(player_position: Vector2) -> bool:
	return player_position.distance_to(get_interact_position()) <= interact_range


## Eキー(または共通アクションボタン)で使われたときの処理(継承先で上書きする)
## 処理した(効果があった)ときは true、何もしなかったときは false を返す
func interact() -> bool:
	return false
