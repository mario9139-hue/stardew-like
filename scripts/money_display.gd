class_name MoneyDisplay
extends CanvasLayer
## 画面右上に所持金と装備中の武器名を表示する。

@export var player_path: NodePath = ^"../Player"

var _player: Player
@onready var _label: Label = $Label
@onready var _weapon_label: Label = $WeaponLabel


func _ready() -> void:
	Money.changed.connect(_on_money_changed)
	_player = get_node_or_null(player_path) as Player
	if _player == null:
		push_error("MoneyDisplay: Player を取得できません")
	else:
		_player.weapon_changed.connect(_on_weapon_changed)
	_refresh()


func _on_money_changed(_amount: int) -> void:
	_refresh()


func _on_weapon_changed(_weapon: ItemData) -> void:
	_refresh()


func _refresh() -> void:
	_label.text = "%04dG" % Money.amount
	var weapon_name: String = "素手"
	if _player != null and _player.equipped_weapon != null:
		weapon_name = _player.equipped_weapon.display_name
	_weapon_label.text = "装備: %s" % weapon_name
