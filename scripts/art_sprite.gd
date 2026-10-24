class_name ArtSprite
extends Sprite2D
## SpriteProvider から素材を取得して表示するだけの Sprite2D。
## シーンに置いて sprite_id("カテゴリ/名前")を指定する。素材が無ければ仮の色付き四角になる。

@export var sprite_id: StringName = &""


func _ready() -> void:
	if sprite_id == &"":
		push_warning("ArtSprite: sprite_id が未設定です (%s)" % get_path())
		return
	SpriteProvider.apply(self, sprite_id)
