extends Node
## 次のシーズンへ持ち越すもの(Autoload: CarryOver)。
## シーズン終了時に、ランクに応じたクリアボーナス(BonusTable)を決めて保持する。
## 次のシーズンの開始時、引き継ぎ項目(data/carry_over_rules.tres)に従って、所持金・武器・所持品・
## ボーナスを新しいシーンへ反映する(apply_to_scene)。シーズン番号(春→夏→秋→冬→春…)もここで持つ。
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

## ボーナスが決まったときに発行される
signal bonus_decided(rank: String, items: Array)

const BONUS_TABLE_PATH: String = "res://data/bonus/default.tres"
const RULES_PATH: String = "res://data/carry_over_rules.tres"
## 季節の名前(表示のみ。作物の季節制限はない)
const SEASON_NAMES: PackedStringArray = ["春", "夏", "秋", "冬"]

## 動作確認用: ボーナスのログを Output へ出す(不要になったら false に)
var debug_log: bool = true

## 今シーズンのランク(シーズン終了前は空)
var rank: String = ""
## 次シーズン開始時に所持品へ足すボーナス。[ {"id": StringName, "count": int}, ... ]
var bonus_items: Array = []
## 何シーズン目か(0 = 春・1年目。次のシーズンへ進むたびに +1)
var season_index: int = 0

## 次のシーズンへ引き継ぐ内容(capture で作り、apply_to_scene で反映して空にする)
var _pending: Dictionary = {}


func _ready() -> void:
	SeasonStats.season_finished.connect(_on_season_finished)


## シーズン番号・ランク・ボーナスを復元する(ロード用)
func restore_state(season: int, saved_rank: String, bonus: Array) -> void:
	season_index = maxi(season, 0)
	rank = saved_rank
	bonus_items.clear()
	for entry in bonus:
		if typeof(entry) == TYPE_DICTIONARY and ItemRegistry.get_item(StringName(String(entry.get("id", "")))) != null:
			bonus_items.append({"id": StringName(String(entry["id"])), "count": int(entry.get("count", 0))})
		else:
			push_warning("CarryOver: 未知のボーナス id をスキップしました: %s" % str(entry))


## 現在のシーズン名(例: 春・1年目)
func get_season_label() -> String:
	return "%s・%d年目" % [SEASON_NAMES[season_index % SEASON_NAMES.size()], season_index / SEASON_NAMES.size() + 1]


## 新規開始: シーズン番号とボーナス・引き継ぎ待ちを全て初期に戻す
func reset_all() -> void:
	season_index = 0
	_pending = {}
	clear()


## 次のシーズンへ進む準備: 今のシーン(root)から引き継ぐ内容を集め、シーズン番号を進める
## 反映は、次のシーンの Main が apply_to_scene で行う
func capture_for_next_season(root: Node) -> void:
	var inventory: Inventory = root.get_tree().get_first_node_in_group(&"inventory") as Inventory
	var player: Player = root.get_tree().get_first_node_in_group(&"player") as Player
	_pending = {
		"money": Money.amount,
		"items": inventory.get_all_items() if inventory != null else {},
		"weapon_id": player.equipped_weapon_id if player != null else &"",
		"bonus": bonus_items.duplicate(true),
	}
	season_index += 1
	if debug_log:
		print("[CarryOver] 引き継ぎを保存: 所持金=%dG 武器=%s 所持品=%d種類 ボーナス=%d種類 → %s" % [
			int(_pending["money"]), _pending["weapon_id"], (_pending["items"] as Dictionary).size(),
			(_pending["bonus"] as Array).size(), get_season_label()])


## 新しいシーン(Main)に、引き継ぎを反映する。引き継ぎ待ちが無ければ何もしない
func apply_to_scene(root: Node) -> void:
	if _pending.is_empty():
		return
	var rules: CarryOverRules = load(RULES_PATH) as CarryOverRules
	if rules == null:
		push_error("CarryOver: 引き継ぎ設定を読み込めません: %s" % RULES_PATH)
		rules = CarryOverRules.new()
	var inventory: Inventory = root.get_tree().get_first_node_in_group(&"inventory") as Inventory
	var player: Player = root.get_tree().get_first_node_in_group(&"player") as Player
	if rules.keep_money:
		Money.set_amount(int(_pending["money"]))
	if rules.keep_inventory and inventory != null:
		inventory.replace_items(_pending["items"])
	if rules.keep_weapons and player != null and StringName(_pending["weapon_id"]) != &"":
		var weapon: ItemData = BonusTable.find_item(StringName(_pending["weapon_id"]))
		if weapon != null:
			player.purchase_and_equip_weapon(weapon)
	if rules.keep_bonus_items and inventory != null:
		for entry in _pending["bonus"]:
			inventory.add_item(StringName(entry["id"]), int(entry["count"]))
	if debug_log:
		print("[CarryOver] 引き継ぎを反映: %s 所持金=%dG" % [get_season_label(), Money.amount])
	_pending = {}
	clear()


## 持ち越しの内容を空にする(次シーズンへ追加し終えたあとに呼ぶ)
func clear() -> void:
	rank = ""
	bonus_items.clear()


func _on_season_finished(season_rank: String, _summary: Dictionary) -> void:
	rank = season_rank
	bonus_items.clear()
	var table: BonusTable = load(BONUS_TABLE_PATH) as BonusTable
	if table == null:
		push_error("CarryOver: ボーナス表を読み込めません: %s" % BONUS_TABLE_PATH)
	else:
		bonus_items = table.get_rewards(rank)
	if debug_log:
		var parts: PackedStringArray = []
		for entry in bonus_items:
			parts.append("%s x%d" % [entry["id"], int(entry["count"])])
		print("[CarryOver] ランク%s のボーナス: %s" % [rank, ", ".join(parts) if not parts.is_empty() else "なし"])
	bonus_decided.emit(rank, bonus_items)
