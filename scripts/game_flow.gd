extends Node
## 画面の流れ(Autoload: GameFlow)。タイトル → ゲーム → 結果 → 次のシーズン / タイトル。
## 新しいシーズンは、状態を初期化してメインシーンを読み込み直すことで始める(畑・作物・設置物は自然にリセットされる)。
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

const TITLE_SCENE: String = "res://scenes/title.tscn"
const MAIN_SCENE: String = "res://scenes/main.tscn"

var _changing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## はじめから: 初期状態(所持金500G・カブの種10個)で1年目の春・1日目から
func start_new_game() -> void:
	if _changing:
		return
	CarryOver.reset_all()
	_reset_season_state()
	print("[GameFlow] はじめから → %s 1日目" % CarryOver.get_season_label())
	_change_scene(MAIN_SCENE)


## 次のシーズンへ: 引き継ぎ項目を保存し、畑と日数などを初期化してメインシーンを読み込み直す
func start_next_season() -> void:
	if _changing:
		return
	CarryOver.capture_for_next_season(self)
	_reset_season_state()
	print("[GameFlow] 次のシーズンへ → %s 1日目" % CarryOver.get_season_label())
	_change_scene(MAIN_SCENE)


## つづきから: セーブデータを読み、メインシーンを読み込み直して反映する。読めなければ false(何も変えない)
func continue_game() -> bool:
	if _changing:
		return false
	var data: Dictionary = SaveManager.read_save()
	if data.is_empty():
		return false
	SaveManager.set_pending_load(data)
	CarryOver.reset_all()
	_reset_season_state()
	print("[GameFlow] つづきから → ロード")
	_change_scene(MAIN_SCENE)
	return true


## タイトルへ戻る
func go_title() -> void:
	if _changing:
		return
	_change_scene(TITLE_SCENE)


## シーズンごとに初期化する状態(所持金・引き継ぎ品は CarryOver が新しいシーンへ反映する)
func _reset_season_state() -> void:
	GameClock.reset_for_new_season()
	Money.reset()
	SalesLedger.reset()
	SeasonStats.reset()
	PlayerStats.reset()


func _change_scene(path: String) -> void:
	_changing = true
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)
	# 読み込みが終わるまで、次の遷移(ボタンの連打)を受け付けない
	await get_tree().create_timer(0.3).timeout
	_changing = false
