class_name SeasonEndOverlay
extends CanvasLayer
## シーズン終了時に「シーズン終了」を表示し、操作を止める(ツリーをポーズする)。
## 仮: クリアボーナスなどは後で実装する。

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameClock.season_ended.connect(_on_season_ended)


func _on_season_ended() -> void:
	visible = true
	get_tree().paused = true
