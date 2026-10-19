class_name ScreenFader
extends CanvasLayer
## 画面全体の暗転(フェードアウト / フェードイン)。
## ツリーがポーズ中でも動くので、就寝中のポーズと併用できる。

@export var fade_seconds: float = 0.4

@onready var _rect: ColorRect = $ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)


## 暗転する(完了まで await できる)
func fade_out() -> void:
	await _fade_to(1.0)


## 暗転から戻す(完了まで await できる)
func fade_in() -> void:
	await _fade_to(0.0)


func _fade_to(alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_rect, "color:a", alpha, fade_seconds)
	await tween.finished
