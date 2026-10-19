class_name InteractionController
extends Node
## 範囲内で最も近い Interactable(家・売却箱・井戸など)を実行する。
## Eキー(interact)と、タッチ操作の共通アクションボタン(try_interact)から呼ばれる。

@export var player_path: NodePath = ^"../Player"
@export var tool_controller_path: NodePath = ^"../ToolController"

var _player: Player
var _tool_controller: ToolController


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_tool_controller = get_node_or_null(tool_controller_path) as ToolController
	if _player == null:
		push_error("InteractionController: Player を取得できません")


func _unhandled_input(event: InputEvent) -> void:
	if _player != null and event.is_action_pressed(&"interact"):
		# 強化素材を選択中の E は、施設ではなく向いている作物マスに使用する。
		if _tool_controller != null and _tool_controller.use_selected_enhancement_on_facing_cell():
			get_viewport().set_input_as_handled()
			return
		try_interact()


## 範囲内で最も近い Interactable を実行する。実行して処理されたら true
## (近くに何もない・実行しても何も起きなかったときは false)
func try_interact() -> bool:
	if _player == null:
		return false
	var best: Interactable = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var target: Interactable = node as Interactable
		if target == null:
			continue
		if not target.can_interact(_player.global_position):
			continue
		var distance: float = _player.global_position.distance_to(target.get_interact_position())
		if distance < best_distance:
			best = target
			best_distance = distance
	return best != null and best.interact()
