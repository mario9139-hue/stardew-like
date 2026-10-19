class_name CellHighlight
extends Node2D
## プレイヤーが向いている隣接マスを四角枠でハイライトする。

@export var player: Player
@export var farm_map_path: NodePath = ^"../FarmMap"
@export var color: Color = Color(1.0, 0.9, 0.2, 1.0)

const COLOR_GROWTH: Color = Color(0.25, 0.95, 0.35, 1.0)
const COLOR_QUALITY: Color = Color(1.0, 0.78, 0.18, 1.0)

var _farm_map: FarmMap
var _default_color: Color


func _ready() -> void:
	_default_color = color
	_farm_map = get_node_or_null(farm_map_path) as FarmMap
	# プレイヤーの移動後に位置を更新する(1フレーム遅れ防止)
	process_physics_priority = 1
	_update_highlight()


func _physics_process(_delta: float) -> void:
	_update_highlight()


func _update_highlight() -> void:
	if player == null:
		visible = false
		return
	var cell: Vector2i = GridUtils.get_facing_cell(player.global_position, player.facing)
	visible = GridUtils.is_in_bounds(cell)
	global_position = GridUtils.cell_to_world(cell)
	var next_color: Color = _default_color
	if _farm_map != null:
		var data: CellData = _farm_map.get_cell_data(cell)
		if data != null:
			if data.quality > 0:
				next_color = COLOR_QUALITY
			elif data.growth_bonus_days > 0:
				next_color = COLOR_GROWTH
	if color != next_color:
		color = next_color
		queue_redraw()


func _draw() -> void:
	var size: float = float(GridUtils.TILE_SIZE) - 1.0
	draw_rect(Rect2(Vector2(0.5, 0.5), Vector2(size, size)), color, false, 1.0)
