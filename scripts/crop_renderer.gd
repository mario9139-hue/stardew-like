class_name CropRenderer
extends Node2D
## 作物を仮の色付き四角で描く。色は CropData の段階色、成長完了で少し大きく描く。
## 描画対象は FarmMap.cells の状態。FarmMap の変更シグナルで再描画する。

@export var farm_map_path: NodePath = ^"../FarmMap"

var _farm_map: FarmMap


func _ready() -> void:
	_farm_map = get_node_or_null(farm_map_path) as FarmMap
	if _farm_map == null:
		push_error("CropRenderer: FarmMap を取得できません")
		return
	_farm_map.cell_changed.connect(_on_cell_changed)
	_farm_map.day_advanced.connect(queue_redraw)


func _on_cell_changed(_cell: Vector2i) -> void:
	queue_redraw()


func _draw() -> void:
	if _farm_map == null:
		return
	for cell_key in _farm_map.cells.keys():
		var cell: Vector2i = cell_key
		var data: CellData = _farm_map.cells[cell]
		if not data.has_crop():
			continue
		var margin: float = 3.0 if data.is_harvestable() else 4.0
		var side: float = float(GridUtils.TILE_SIZE) - margin * 2.0
		var origin: Vector2 = GridUtils.cell_to_world(cell) + Vector2(margin, margin)
		var color: Color = data.crop.get_stage_color(data.growth_progress)
		draw_rect(Rect2(origin, Vector2(side, side)), color)
		# 効果が付いたマスは、対象を移動しても分かるようにタイル外周を色分けする。
		var effect_color: Color = Color.TRANSPARENT
		if data.quality > 0:
			effect_color = Color(1.0, 0.78, 0.18, 1.0) # 品質=金
		elif data.growth_bonus_days > 0:
			effect_color = Color(0.25, 0.95, 0.35, 1.0) # 成長=緑
		if effect_color.a > 0.0:
			var tile_origin: Vector2 = GridUtils.cell_to_world(cell)
			var tile_side: float = float(GridUtils.TILE_SIZE) - 1.0
			draw_rect(Rect2(tile_origin + Vector2(0.5, 0.5), Vector2(tile_side, tile_side)), effect_color, false, 1.0)
