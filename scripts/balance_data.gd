class_name BalanceData
extends Resource
## バランス調整用の値を1か所に集めたリソース(data/balance.tres)。
## 夜戦 → 強化素材 → 畑 の流れの数値は、ここだけを触れば調整できる。

@export_group("夜のスポーン")
## 出現の間隔(秒)。夜の開始から数えて、この秒数ごとに1体出す
@export var spawn_interval_seconds: float = 8.0
## 同時に場にいられる最大数
@export var max_monsters: int = 5
## プレイヤーからこの距離(px)以上離れた位置にだけ出す
@export var min_player_distance: float = 200.0

@export_group("夜の暗さ")
## 最も暗いときのワールドの色(白=暗くならない)。暗すぎて見にくいときは明るい色にする
@export var night_color: Color = Color(0.3, 0.35, 0.6, 1.0)
## 暗さの強さ(0=演出なし、1=night_color まで暗くなる)。見にくいときはまずここを下げる
@export_range(0.0, 1.0) var night_strength: float = 1.0
## 最も暗くなる時刻(24以降も連続表記)。21:00 から、この時刻にかけて徐々に暗くなる
@export var night_darkest_hour: float = 24.0
## 日が替わって明るさが戻るまでの秒数
@export var night_fade_seconds: float = 1.0

@export_group("モンスターの行動")
## プレイヤーがこの距離(px)以内にいると、プレイヤーを優先して追う
@export var monster_detection_range: float = 150.0
## 作物マスに到着してから、作物を荒らし終えるまでの秒数(途中で倒されると被害なし)
@export var ruin_seconds: float = 2.0

@export_group("ランク評価")
## 累計売上(G)がこの値以上でランクが上がる(未満は C)。通しプレイで調整する
@export var rank_b_sales: int = 3000
@export var rank_a_sales: int = 6000
@export var rank_s_sales: int = 10000

@export_group("ドロップ")
## アイテムIDごとのドロップ確率(0〜1)。ここに無いアイテムは DropEntry.chance を使う
@export var drop_chances: Dictionary = {
	"growth_powder": 0.5,
	"quality_shard": 0.4,
}

@export_group("強化素材の効果")
## 成長の粉1個で、次の日替わりに前倒しされる成長日数
@export var growth_powder_effect_days: int = 1
## 高品質(★)作物の売値倍率
@export var quality_sell_multiplier: float = 1.5


## アイテムのドロップ確率。登録がなければ fallback を返す
func get_drop_chance(item_id: StringName, fallback: float) -> float:
	var key: String = String(item_id)
	if drop_chances.has(key):
		return clampf(float(drop_chances[key]), 0.0, 1.0)
	return fallback
