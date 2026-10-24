extends Node
## 起動時の画面設定(Autoload: GameSetup)。基準解像度を GameConfig から反映する。
## project.godot の viewport 設定と GameConfig が食い違っていても、GameConfig が優先される。

func _ready() -> void:
	get_window().content_scale_size = GameConfig.BASE_RESOLUTION
