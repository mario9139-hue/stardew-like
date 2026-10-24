class_name ToolController
extends Node
## 「使用」アクションの受け取り。向いているマスに対して、ホットバーで選択中のアイテムの効果を適用する。
## - 収穫できるマスなら、選択中のアイテムに関わらず収穫を優先する
## - 道具: クワ(耕す)・じょうろ(水やり) / 種: 種まき(種を1個消費)
## - 実行できると分かった時点で体力を消費する。体力が足りなければ何もせず「体力が足りない」を表示する
##   消費量は PlayerStats の export 変数で調整する

## 参照先ノードのパス(このノードからの相対パス)
@export var player_path: NodePath = ^"../Player"
@export var farm_map_path: NodePath = ^"../FarmMap"
@export var hotbar_path: NodePath = ^"../Hotbar"
@export var inventory_path: NodePath = ^"../Inventory"
@export var message_display_path: NodePath = ^"../MessageDisplay"
## 動作確認用: 使用時に Output へログを出す(不要になったら false に)
@export var debug_log: bool = true

var _player: Player
var _farm_map: FarmMap
var _hotbar: Hotbar
var _inventory: Inventory
var _messages: MessageDisplay


func _ready() -> void:
	var player_node: Node = get_node_or_null(player_path)
	var map_node: Node = get_node_or_null(farm_map_path)
	var hotbar_node: Node = get_node_or_null(hotbar_path)
	var inventory_node: Node = get_node_or_null(inventory_path)
	_player = player_node as Player
	_farm_map = map_node as FarmMap
	_hotbar = hotbar_node as Hotbar
	_inventory = inventory_node as Inventory
	_messages = get_node_or_null(message_display_path) as MessageDisplay

	var missing: PackedStringArray = []
	if _player == null:
		missing.append("player=%s (%s)" % [player_node, _script_info(player_node)])
	if _farm_map == null:
		missing.append("farm_map=%s (%s)" % [map_node, _script_info(map_node)])
	if _hotbar == null:
		missing.append("hotbar=%s (%s)" % [hotbar_node, _script_info(hotbar_node)])
	if _inventory == null:
		missing.append("inventory=%s (%s)" % [inventory_node, _script_info(inventory_node)])
	if not missing.is_empty():
		push_error("ToolController: 参照を取得できません / " + " / ".join(missing))
		return
	if _messages == null:
		push_warning("ToolController: MessageDisplay を取得できません(メッセージは表示されません)")

	_player.used_tool.connect(_on_player_used_tool)
	if debug_log:
		print("[ToolController] 準備完了(use_tool待機中)")


func _unhandled_input(event: InputEvent) -> void:
	if not DebugFlags.DEBUG_ENABLED or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var cell: Vector2i = GridUtils.get_facing_cell(_player.global_position, _player.facing) if _player != null else Vector2i(-1, -1)
	if key_event.keycode == KEY_F3 or key_event.physical_keycode == KEY_F3:
		var growth_applied: bool = _farm_map != null and _farm_map.apply_growth_boost(cell, Balance.data.growth_powder_effect_days)
		print("[Debug] F3 成長ボーナス +1: cell=%s 適用=%s" % [cell, growth_applied])
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F4 or key_event.physical_keycode == KEY_F4:
		var quality_applied: bool = _farm_map != null and _farm_map.apply_quality(cell)
		print("[Debug] F4 高品質付与: cell=%s 適用=%s" % [cell, quality_applied])
		get_viewport().set_input_as_handled()


func _on_player_used_tool(target_cell: Vector2i) -> void:
	if _farm_map.can_harvest(target_cell):
		_harvest(target_cell)
		return
	var item: ItemData = _hotbar.get_selected_item()
	if item == null:
		return
	match item.item_type:
		ItemData.Type.TOOL:
			_use_tool_item(item, target_cell)
		ItemData.Type.SEED:
			_use_seed(item, target_cell)
		ItemData.Type.ENHANCEMENT:
			# 強化素材も他のアイテムと同じく「使用(クリック)」で、向いているマスの作物に使う
			use_selected_enhancement_on_facing_cell()
		_:
			# 作物・素材は、使用しても今は何も起きない
			pass


## 選択中のホットバーアイテムが強化素材か。
func is_enhancement_selected() -> bool:
	if _hotbar == null:
		return false
	var item: ItemData = _hotbar.get_selected_item()
	return item != null and item.item_type == ItemData.Type.ENHANCEMENT


## 使用(クリック)から呼び出す。選択中が強化素材なら True を返す(成功/失敗に関わらず、メッセージを出して終わる)。
func use_selected_enhancement_on_facing_cell() -> bool:
	if _hotbar == null or _farm_map == null or _inventory == null or _player == null:
		return false
	var item: ItemData = _hotbar.get_selected_item()
	if item == null or item.item_type != ItemData.Type.ENHANCEMENT:
		return false
	var cell: Vector2i = GridUtils.get_facing_cell(_player.global_position, _player.facing)
	var data: CellData = _farm_map.get_cell_data(cell)
	if data == null or not data.has_crop():
		_show_message("作物がないマスには使えません")
		return true
	match item.effect_type:
		ItemData.EffectType.GROWTH:
			if data.growth_bonus_days > 0:
				_show_message("このマスには成長効果が付いています")
				return true
		ItemData.EffectType.QUALITY:
			if data.quality > 0:
				_show_message("このマスには品質効果が付いています")
				return true
		_:
			_show_message("この強化素材の効果は未設定です")
			return true
	if not _inventory.has_item(item.id):
		_show_message("%sを持っていません" % item.display_name)
		return true

	var applied: bool = false
	match item.effect_type:
		ItemData.EffectType.GROWTH:
			applied = _farm_map.apply_growth_boost(cell, Balance.data.growth_powder_effect_days)
		ItemData.EffectType.QUALITY:
			applied = _farm_map.apply_quality(cell)
		_:
			_show_message("この強化素材の効果は未設定です")
			return true
	if not applied:
		_show_message("このマスには強化素材を使えません")
		return true
	if _inventory.remove_item(item.id, 1):
		_show_message("%sを使用しました" % item.display_name)
		var detail: String = "成長+%d日(次の日替わり)" % Balance.data.growth_powder_effect_days if item.effect_type == ItemData.EffectType.GROWTH else "高品質★付与(売値x%.2f)" % Balance.data.quality_sell_multiplier
		DebugFlags.record_enhancement_use(item.id, cell, detail)
	else:
		push_warning("ToolController: 効果を適用しましたが強化素材を消費できませんでした")
	return true


func _use_tool_item(item: ItemData, cell: Vector2i) -> void:
	match item.id:
		&"hoe":
			_use_hoe(cell)
		&"watering_can":
			_use_watering_can(cell)
		_:
			push_warning("ToolController: 未対応の道具です: %s" % item.id)


func _use_hoe(cell: Vector2i) -> void:
	var ok: bool = _farm_map.can_till(cell)
	_log_use("クワ", cell, ok)
	if not ok:
		return
	if not _try_consume_stamina(PlayerStats.stamina_cost_till):
		return
	_farm_map.till(cell)


func _use_watering_can(cell: Vector2i) -> void:
	var ok: bool = _farm_map.can_water(cell)
	_log_use("じょうろ 残量=%d" % PlayerStats.water, cell, ok)
	if not ok:
		return
	# 水がないときは体力を消費せずに中断する
	if PlayerStats.water <= 0:
		_show_message("水がない")
		return
	if not _try_consume_stamina(PlayerStats.stamina_cost_water):
		return
	PlayerStats.consume_water(1)
	_farm_map.water(cell)


func _use_seed(seed_item: ItemData, cell: Vector2i) -> void:
	var crop: CropData = seed_item.crop
	if crop == null:
		push_warning("ToolController: %s に crop(作物)が設定されていません" % seed_item.id)
		return
	var has_seed: bool = _inventory.get_count(seed_item.id) > 0
	var ok: bool = has_seed and _farm_map.can_plant(cell)
	_log_use("種(%s) 所持=%d" % [seed_item.display_name, _inventory.get_count(seed_item.id)], cell, ok)
	if not ok:
		return
	if not _try_consume_stamina(PlayerStats.stamina_cost_seed):
		return
	if _farm_map.plant(cell, crop):
		_inventory.remove_item(seed_item.id)


func _harvest(cell: Vector2i) -> void:
	var crop: CropData = _farm_map.get_cell_data(cell).crop
	if crop.harvest_item == null:
		push_warning("ToolController: %s に harvest_item が設定されていません" % crop.id)
		return
	if not _try_consume_stamina(PlayerStats.stamina_cost_harvest):
		return
	var quality: int = _farm_map.get_cell_data(cell).quality
	_farm_map.harvest(cell)
	_inventory.add_item(crop.harvest_item.id, 1, quality)
	SeasonStats.add_harvest()
	if debug_log:
		var quality_mark: String = "★" if quality == 1 else ""
		print(
			"[ToolController] 収穫 cell=%s %s%s 所持=%d"
			% [cell, quality_mark, crop.harvest_item.display_name, _inventory.get_count(crop.harvest_item.id, quality)]
		)


## 体力を消費する。足りなければ「体力が足りない」を表示して false を返す
func _try_consume_stamina(cost: int) -> bool:
	if PlayerStats.consume_stamina(cost):
		if debug_log and cost > 0:
			print("[ToolController] 体力 -%d → %d/%d" % [cost, PlayerStats.stamina, PlayerStats.max_stamina])
		return true
	if debug_log:
		print("[ToolController] 体力が足りない(必要=%d 現在=%d)" % [cost, PlayerStats.stamina])
	_show_message("体力が足りない")
	return false


func _show_message(text: String) -> void:
	if _messages != null:
		_messages.show_message(text, 1.0)



func _log_use(label: String, cell: Vector2i, ok: bool) -> void:
	if debug_log:
		print("[ToolController] %s cell=%s 実行できる=%s" % [label, cell, ok])


func _script_info(node: Node) -> String:
	if node == null:
		return "ノードが見つからない"
	var script: Script = node.get_script()
	if script == null:
		return "スクリプトなし(読み込み失敗の可能性)"
	return script.resource_path
