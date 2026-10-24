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
	# E キーは施設(家・売却箱・井戸・店)の操作。アイテムの使用はクリック(use_tool)で行う
	if _player != null and event.is_action_pressed(&"interact"):
		if try_interact():
			get_viewport().set_input_as_handled()


## 強化素材を選択中でも、家・店が使用対象と重なる場合は施設操作を優先する。
## 家と店の両方が候補なら、操作位置が最も近い施設を選ぶ。
func _try_interact_priority_facility() -> bool:
	if _player == null:
		return false
	var best: Interactable = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var target: Interactable = node as Interactable
		if target == null or not (target is House or target is Shop):
			continue
		if not _is_facility_in_access_range(target):
			continue
		var distance: float = _player.global_position.distance_to(target.get_interact_position())
		if distance < best_distance:
			best = target
			best_distance = distance
	if best == null:
		return false
	# 施設が操作対象として優先されたら、強化素材の使用へ流さない。
	best.interact()
	return true


## 通常の距離判定に加え、向いている隣接マスの中心が施設の操作範囲内なら候補とする。
## キャラクター前面のマスで作物操作と施設アクセスが競合するケースを吸収する。
func _is_facility_in_access_range(target: Interactable) -> bool:
	if target.can_interact(_player.global_position):
		return true
	var facing_cell: Vector2i = GridUtils.get_facing_cell(_player.global_position, _player.facing)
	var facing_cell_center: Vector2 = GridUtils.cell_to_world_center(facing_cell)
	return facing_cell_center.distance_to(target.get_interact_position()) <= target.interact_range


## 範囲内で最も近い Interactable を実行する。実行して処理されたら true
## (近くに何もない・実行しても何も起きなかったときは false)
func try_interact(prefer_item_use: bool = false) -> bool:
	if _player == null:
		return false
	# タッチのアクションボタン用: 強化素材を選択中は、家・店だけを優先し、それ以外は呼び出し側が
	# アイテムの使用(use_tool)へ進める。E キーは常に false のまま(施設の操作のみ)
	if prefer_item_use and _tool_controller != null and _tool_controller.is_enhancement_selected():
		return _try_interact_priority_facility()
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
