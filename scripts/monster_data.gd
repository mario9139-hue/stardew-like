class_name MonsterData
extends Resource
## モンスター1種類分のデータ。data/monsters/*.tres として定義する。
## 1つの monster.tscn に MonsterData を渡して、複数種のモンスターを作る。

@export var id: StringName = &""
@export var display_name: String = ""
## 素材名。空なら id を使う(素材は assets/art/monsters/<素材名>.png)
@export var sprite_id: StringName = &""
## 最大HP
@export var max_hp: int = 10
## 追跡するときの移動速度(px/秒)
@export var move_speed: float = 40.0
## プレイヤーに触れたときのダメージ
@export var contact_damage: int = 5
## 仮の見た目の色(色付き四角)
@export var body_color: Color = Color(0.3, 0.75, 0.3, 1.0)
## ドロップ表(DropEntry の配列)。倒したとき、各エントリを独立に抽選する
## ※ 型付き配列(Array[DropEntry])にすると .tres の書式が壊れやすいため、普通の配列にして
##   Monster 側で DropEntry かどうかを確認している
@export var drops: Array = []


## 素材ID(例: monsters/slime)
func get_sprite_id() -> StringName:
	return StringName("monsters/%s" % (sprite_id if sprite_id != &"" else id))


## 素材が無いときの仮素材(body_color の色付き四角)
func get_placeholder_spec() -> Dictionary:
	return SpriteProvider.solid_spec(body_color)
