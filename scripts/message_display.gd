class_name MessageDisplay
extends CanvasLayer
## 画面下部(ホットバーの上)に短いメッセージを数秒間表示する。

@onready var _label: Label = $Label

var _show_id: int = 0


func _ready() -> void:
	add_to_group(&"message_display")
	_label.visible = false


## メッセージを seconds 秒だけ表示する(新しいメッセージが来たら置き換える)
func show_message(text: String, seconds: float = 1.0) -> void:
	_label.text = text
	_label.visible = true
	_show_id += 1
	var my_id: int = _show_id
	await get_tree().create_timer(seconds).timeout
	if my_id == _show_id:
		_label.visible = false
