extends Node
## セーブとロード(Autoload: SaveManager)。
## - 保存先 user://save.json(JSON、version 付き)。Web 書き出しでも user:// が使われる
## - 安全策: 一時ファイル(.tmp)に書いて検証してからリネーム。直前の1世代を save.json.bak に残す
##   読み込みに失敗したらバックアップを試し、それも失敗ならエラーにして落とさない
## - ItemData / CropData は id で保存し、ロード時は ItemRegistry で復元する。未知の id は警告してスキップ
## - 自動セーブ: 日替わり処理が終わった朝(Main が DayManager.slept から autosave を呼ぶ)
## - ロード: 状態をいったん初期化してメインシーンを読み込み直し、Main が apply_pending_load で反映する
## - デバッグ: F11 セーブ / F12 ロード(DebugFlags.DEBUG_ENABLED のとき)
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

const SAVE_PATH: String = "user://save.json"
const TMP_PATH: String = "user://save.json.tmp"
const BACKUP_PATH: String = "user://save.json.bak"
const SAVE_VERSION: int = 1

## 動作確認用: セーブ・ロードのログを Output へ出す(不要になったら false に)
var debug_log: bool = true

## ロード待ちのセーブデータ(次のメインシーンで反映する)
var _pending_load: Dictionary = {}


func _unhandled_input(event: InputEvent) -> void:
	if not DebugFlags.DEBUG_ENABLED:
		return
	if event.is_action_pressed(&"debug_save"):
		if save_game():
			_show_message("セーブしました")
	elif event.is_action_pressed(&"debug_load"):
		if not GameFlow.continue_game():
			_show_message("セーブデータを読み込めません")


## セーブデータ(またはバックアップ)があるか
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


## 日替わり後の自動セーブ。シーズン終了後は保存しない
func autosave() -> void:
	if GameClock.is_season_over:
		return
	save_game()


## 今の状態を保存する。成功したら true
func save_game() -> bool:
	var data: Dictionary = _collect()
	if data.is_empty():
		return false
	var ok: bool = _write_atomic(JSON.stringify(data, "\t"))
	if ok and debug_log:
		print("[SaveManager] セーブ完了: %s %d日目 所持金=%dG" % [CarryOver.get_season_label(), GameClock.day, Money.amount])
	return ok


## セーブデータを読む(save.json → だめなら save.json.bak)。読めなければ空の Dictionary
func read_save() -> Dictionary:
	var data: Dictionary = _parse_file(SAVE_PATH)
	if not data.is_empty():
		return data
	if FileAccess.file_exists(SAVE_PATH):
		push_warning("SaveManager: save.json を読めません(壊れている可能性)。バックアップを試します")
	data = _parse_file(BACKUP_PATH)
	if not data.is_empty():
		push_warning("SaveManager: バックアップ(save.json.bak)から復元しました")
		DirAccess.copy_absolute(BACKUP_PATH, SAVE_PATH)
		return data
	if has_save():
		push_error("SaveManager: セーブデータもバックアップも読めません")
	return {}


func set_pending_load(data: Dictionary) -> void:
	_pending_load = data


## 新しいメインシーンに、ロード待ちのセーブデータを反映する(なければ何もしない)
func apply_pending_load(root: Node) -> void:
	if _pending_load.is_empty():
		return
	var data: Dictionary = _pending_load
	_pending_load = {}
	var tree: SceneTree = root.get_tree()
	var inventory: Inventory = tree.get_first_node_in_group(&"inventory") as Inventory
	var player: Player = tree.get_first_node_in_group(&"player") as Player
	var farm_map: FarmMap = tree.get_first_node_in_group(&"farm_map") as FarmMap

	var clock: Dictionary = _dict(data, "clock")
	GameClock.restore_state(int(clock.get("day", 1)), float(clock.get("minutes", 360.0)))
	Money.set_amount(int(data.get("money", Money.STARTING_AMOUNT)))

	var carry: Dictionary = _dict(data, "carry_over")
	CarryOver.restore_state(int(carry.get("season_index", 0)), String(carry.get("rank", "")), _array(carry, "bonus_items"))

	var stats: Dictionary = _dict(data, "season_stats")
	SeasonStats.restore_state(int(stats.get("kills", 0)), int(stats.get("ruined_crops", 0)), int(stats.get("harvests", 0)), String(stats.get("rank", "")))
	var ledger: Dictionary = _dict(stats, "daily_sales")
	var daily_sales: Dictionary = {}
	for key in ledger.keys():
		daily_sales[int(key)] = int(ledger[key])
	SalesLedger.restore_state(daily_sales, int(stats.get("total_sales", 0)))

	var player_stats: Dictionary = _dict(data, "player_stats")
	PlayerStats.restore_state(int(player_stats.get("hp", PlayerStats.max_hp)), int(player_stats.get("stamina", PlayerStats.max_stamina)), int(player_stats.get("water", PlayerStats.max_water)))

	if inventory != null:
		inventory.replace_items(_restore_items(_dict(data, "inventory")))
	if player != null:
		_restore_player(player, _dict(data, "player"))
	if farm_map != null:
		farm_map.import_state(_array(data, "cells"))
	if debug_log:
		print("[SaveManager] ロード完了: %s %d日目 所持金=%dG" % [CarryOver.get_season_label(), GameClock.day, Money.amount])


## 今のシーンと各 Autoload から、保存する内容を集める。メインシーンにいなければ空
func _collect() -> Dictionary:
	var tree: SceneTree = get_tree()
	var inventory: Inventory = tree.get_first_node_in_group(&"inventory") as Inventory
	var player: Player = tree.get_first_node_in_group(&"player") as Player
	var farm_map: FarmMap = tree.get_first_node_in_group(&"farm_map") as FarmMap
	if inventory == null or player == null or farm_map == null:
		push_warning("SaveManager: ゲーム中ではないのでセーブできません")
		return {}
	var daily_sales: Dictionary = {}
	for key in SalesLedger.daily_sales.keys():
		daily_sales[str(key)] = SalesLedger.daily_sales[key]
	var bonus: Array = []
	for entry in CarryOver.bonus_items:
		bonus.append({"id": String(entry["id"]), "count": int(entry["count"])})
	var items: Dictionary = {}
	var all_items: Dictionary = inventory.get_all_items()
	for key in all_items.keys():
		items[String(key)] = all_items[key]
	return {
		"version": SAVE_VERSION,
		"clock": {"day": GameClock.day, "minutes": GameClock.get_minutes()},
		"money": Money.amount,
		"inventory": items,
		"player": {
			"weapon_id": String(player.equipped_weapon_id),
			"x": player.global_position.x,
			"y": player.global_position.y,
		},
		"cells": farm_map.export_state(),
		# 設置物は今のところ無い(建物は固定配置)。増えたらここに足す
		"placed_objects": [],
		"season_stats": {
			"kills": SeasonStats.kills,
			"ruined_crops": SeasonStats.ruined_crops,
			"harvests": SeasonStats.harvests,
			"rank": SeasonStats.rank,
			"total_sales": SalesLedger.total_sales,
			"daily_sales": daily_sales,
		},
		"carry_over": {
			"season_index": CarryOver.season_index,
			"rank": CarryOver.rank,
			"bonus_items": bonus,
		},
		"player_stats": {"hp": PlayerStats.hp, "stamina": PlayerStats.stamina, "water": PlayerStats.water},
	}


## 所持品を復元用の Dictionary(キー → 個数)にする。未知の id は警告してスキップ
func _restore_items(items: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in items.keys():
		var key_text: String = String(key)
		var base_id: StringName = StringName(key_text.get_slice("#q", 0))
		if ItemRegistry.get_item(base_id) == null:
			push_warning("SaveManager: 未知のアイテム id をスキップしました: %s" % key_text)
			continue
		result[StringName(key_text)] = int(items[key])
	return result


func _restore_player(player: Player, data: Dictionary) -> void:
	var weapon_id: StringName = StringName(String(data.get("weapon_id", "")))
	if weapon_id != &"":
		var weapon: ItemData = ItemRegistry.get_item(weapon_id)
		if weapon == null:
			push_warning("SaveManager: 未知の武器 id をスキップしました: %s" % weapon_id)
		elif not player.purchase_and_equip_weapon(weapon):
			player.equip_weapon(weapon)
	if data.has("x") and data.has("y"):
		player.global_position = Vector2(float(data["x"]), float(data["y"]))
		player.velocity = Vector2.ZERO


## 一時ファイルに書く → 検証 → 現行を .bak に退避 → リネーム
func _write_atomic(text: String) -> bool:
	var file: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 一時ファイルを開けません: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(text)
	file.close()
	if _parse_file(TMP_PATH).is_empty():
		push_error("SaveManager: 書き込んだデータを検証できません。セーブを中止します")
		return false
	# 現行のセーブが正常なときだけバックアップにする(壊れた物で良いバックアップを潰さない)
	if not _parse_file(SAVE_PATH).is_empty():
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var error: Error = DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if error != OK:
		push_error("SaveManager: リネームに失敗しました: %s" % error_string(error))
		return false
	return true


## ファイルを読んで JSON として検証する。壊れている・version が合わない場合は空
func _parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = json.data
	var version: int = int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		push_warning("SaveManager: 未対応のセーブ version です: %d (%s)" % [version, path])
		return {}
	return data


func _dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if typeof(value) == TYPE_ARRAY else []


func _show_message(text: String) -> void:
	var messages: MessageDisplay = get_tree().get_first_node_in_group(&"message_display") as MessageDisplay
	if messages != null:
		messages.show_message(text, 1.0)
