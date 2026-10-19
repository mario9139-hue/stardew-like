class_name Well
extends Interactable
## 井戸(仮の色付きオブジェクト)。隣接マスでEキーを押すと、じょうろが満タンになる(体力消費なし)。

@export var message_display_path: NodePath = ^"../MessageDisplay"

var _messages: MessageDisplay


func _ready() -> void:
	_messages = get_node_or_null(message_display_path) as MessageDisplay


## 井戸のマスの隣接マス(斜め含む)にいるときだけ使える
func can_interact(player_position: Vector2) -> bool:
	var delta: Vector2i = (GridUtils.world_to_cell(player_position) - GridUtils.world_to_cell(global_position)).abs()
	return maxi(delta.x, delta.y) <= 1


func interact() -> bool:
	var text: String = "じょうろは満タンです"
	if PlayerStats.water < PlayerStats.max_water:
		PlayerStats.refill_water()
		text = "水をくんだ"
	if _messages != null:
		_messages.show_message(text)
	return true
