class_name MoneyDisplay
extends CanvasLayer
## 画面右上に所持金を「0000G」形式で表示する。

@onready var _label: Label = $Label


func _ready() -> void:
	Money.changed.connect(_on_money_changed)
	_refresh()


func _on_money_changed(_amount: int) -> void:
	_refresh()


func _refresh() -> void:
	_label.text = "%04dG" % Money.amount
