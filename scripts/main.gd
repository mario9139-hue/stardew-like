extends Node2D
## メインシーンのルート。シーンに置いた位置は「基準タイル(16px)」で書かれているので、
## GameConfig.TILE_SIZE が違うときだけ、建物・プレイヤーの位置を拡大縮小して合わせる。
## あわせて、次のシーズン・ロードの反映と、日替わり後の自動セーブをつなぐ。

const SCALED_NODES: PackedStringArray = ["House", "SalesBox", "Well", "Shop", "Player"]


func _ready() -> void:
	_scale_positions()
	# 次のシーズンの開始なら、引き継ぎ内容を反映する(新規開始なら何もしない)
	CarryOver.apply_to_scene(self)
	# ロード(つづきから / F12)なら、セーブデータを反映する
	SaveManager.apply_pending_load(self)
	# 日替わり処理が終わった朝に自動セーブする
	var day_manager: DayManager = get_node_or_null("DayManager") as DayManager
	if day_manager != null:
		day_manager.slept.connect(_on_slept)


func _scale_positions() -> void:
	var factor: float = GameConfig.scale()
	if is_equal_approx(factor, 1.0):
		return
	for node_name: String in SCALED_NODES:
		var node: Node2D = get_node_or_null(node_name) as Node2D
		if node != null:
			node.position *= factor


func _on_slept(_reason: int) -> void:
	SaveManager.autosave()
