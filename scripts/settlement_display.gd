class_name SettlementDisplay
extends CanvasLayer
## 売却箱の精算内容(「カブ x3 = 135G」など)を、数秒間だけ画面に一覧表示する。

@export var sales_box_path: NodePath = ^"../SalesBox"
## 表示している秒数(ポーズ中は進まない)
@export var display_seconds: float = 4.0

var _show_id: int = 0

@onready var _label: Label = $Label


func _ready() -> void:
	var sales_box: SalesBox = get_node_or_null(sales_box_path) as SalesBox
	if sales_box == null:
		push_error("SettlementDisplay: SalesBox を取得できません")
		return
	sales_box.settled.connect(_on_settled)


func _on_settled(lines: PackedStringArray, total: int) -> void:
	_label.text = "\n".join(lines) + "\n合計 %dG" % total
	_label.visible = true
	_show_id += 1
	var my_id: int = _show_id
	# process_always = false: 就寝中のポーズ(暗転)の間は時間が進まず、明けてから表示される
	await get_tree().create_timer(display_seconds, false).timeout
	if my_id == _show_id:
		_label.visible = false
