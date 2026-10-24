class_name ItemData
extends Resource
## アイテム1種類分のデータ。data/items/*.tres として定義する。
## 道具・種・作物のほか、今後モンスターのドロップなども同じ形式で追加する。

## アイテムの種別。
## 新しい種別は必ず末尾に追加すること(.tres には数値で保存されるため、既存の順序は変えない)
enum Type { TOOL, SEED, CROP, MATERIAL, ENHANCEMENT, WEAPON }

## 強化素材の効果種別。効果の処理内容は ToolController が解釈する。
enum EffectType { NONE, GROWTH, QUALITY }

@export var id: StringName = &""
@export var display_name: String = ""
## 素材名。空なら id を使う(素材は assets/art/items/<素材名>.png)
@export var sprite_id: StringName = &""
## 売値(G)。道具など売らないものは 0
@export var sell_price: int = 0
@export var item_type: Type = Type.MATERIAL
## 種アイテムのとき、まいて育てる作物。種以外は未設定
@export var crop: CropData
## 強化素材の効果。item_type が ENHANCEMENT のときに使用する。
@export var effect_type: EffectType = EffectType.NONE
## 武器の仮パラメータ。攻撃処理は後続機能で使用する。
@export var weapon_attack_power: int = 0
@export var weapon_attack_range: float = 0.0
@export var weapon_attack_cooldown: float = 0.0


## 素材ID(例: items/turnip)
func get_sprite_id() -> StringName:
	return StringName("items/%s" % (sprite_id if sprite_id != &"" else id))


## 個数を持つアイテムか(道具・武器は個数スタックを持たない)
func has_count() -> bool:
	return item_type != Type.TOOL and item_type != Type.WEAPON
