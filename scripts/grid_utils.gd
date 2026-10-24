class_name GridUtils
extends RefCounted
## マップ座標(セル)とワールド座標の変換ユーティリティ。
## 前提: TileMapLayer はワールド原点 (0, 0) に置く(スケール・回転なし)。
## 使用対象マスは、プレイヤー中心ではなく、向いている方向の前面の辺を基準に決める。

## タイルサイズ・マップサイズは GameConfig で決める
const TILE_SIZE: int = GameConfig.TILE_SIZE
## マップのサイズ(マス数)
const MAP_SIZE: Vector2i = GameConfig.MAP_SIZE


## セルの左上のワールド座標
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE)


## セルの中心のワールド座標(TileMapLayer.map_to_local と同じ値)
static func cell_to_world_center(cell: Vector2i) -> Vector2:
	return cell_to_world(cell) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


## ワールド座標が属するセル
static func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / float(TILE_SIZE)).floor())


## プレイヤーの向いている方向の前面の辺から、直近のセルを取得する。
## 前面の辺がセル境界上にある場合も、向いている側のセルを選べるよう微小量だけ押し出す。
static func get_facing_cell(world_pos: Vector2, facing: Vector2) -> Vector2i:
	var direction: Vector2i
	if absf(facing.x) >= absf(facing.y):
		direction = Vector2i.RIGHT if facing.x >= 0.0 else Vector2i.LEFT
	else:
		direction = Vector2i.DOWN if facing.y >= 0.0 else Vector2i.UP
	var edge_distance: float = float(TILE_SIZE) * 0.5 + 0.001
	var leading_edge: Vector2 = world_pos + Vector2(direction.x, direction.y) * edge_distance
	return world_to_cell(leading_edge)


## セルがマップ範囲内か
static func is_in_bounds(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, MAP_SIZE).has_point(cell)
