class_name House
extends Interactable
## 家(仮の色付きオブジェクト)。Eキーで就寝を要求する。
## このノードの位置は「玄関の下端」。プレイヤーはその直下のマスにリスポーンする。

## 就寝が要求されたときに発行される(DayManager が受け取る)
signal sleep_requested


func interact() -> bool:
	sleep_requested.emit()
	return true


## 就寝後にプレイヤーが現れる位置(玄関の前のマスの中心)
func get_spawn_position() -> Vector2:
	return GridUtils.cell_to_world_center(GridUtils.world_to_cell(global_position))
