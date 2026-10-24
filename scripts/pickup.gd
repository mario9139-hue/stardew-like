class_name Pickup
extends Node2D
## 地面に落ちているドロップアイテム(仮の色付き小四角)。
## - プレイヤーが pickup_radius 以内に近づくと、自動で Inventory に追加されて消える
##   (取得時に「成長の粉 +1」のようなテキストを短く表示する)
## - 日が替わる(就寝・気絶・26:00)と、未回収のものは消える
## 色はアイテムIDから決まるので、種類ごとに見分けられる。

## 落ちているアイテム。add_child する前に設定する
@export var item: ItemData
@export var count: int = 1
## この距離(px)以内にプレイヤーが来たら拾う
@export var pickup_radius: float = 32.0
## 落ちてから拾えるようになるまでの秒数(拾う前に、落ちたことが見えるように)
@export var pickup_delay_seconds: float = 0.5
## 取得メッセージを表示する秒数
@export var message_seconds: float = 0.8

const PLAYER_GROUP: StringName = &"player"
const INVENTORY_GROUP: StringName = &"inventory"
const MESSAGE_GROUP: StringName = &"message_display"

var _delay_left: float = 0.0

@onready var _body: Sprite2D = $Body


func _ready() -> void:
	if item == null:
		push_warning("Pickup: item が未設定です")
		queue_free()
		return
	_delay_left = pickup_delay_seconds
	SpriteProvider.apply(_body, item.get_sprite_id(), SpriteProvider.solid_spec(_color_for(item), Vector2(6, 6), 0.0, "center"))
	# 就寝・気絶・26:00 の強制就寝はどれも日が替わる(day_started)ので、そこで消える
	GameClock.day_started.connect(_on_day_started)


func _physics_process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	var player: Node2D = get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player != null and global_position.distance_to(player.global_position) <= pickup_radius:
		_collect()


func _collect() -> void:
	set_physics_process(false)
	var inventory: Inventory = get_tree().get_first_node_in_group(INVENTORY_GROUP) as Inventory
	if inventory == null:
		push_warning("Pickup: Inventory を取得できません")
		set_physics_process(true)
		return
	inventory.add_item(item.id, count)
	DebugFlags.record_pickup(item.id, count)
	var messages: MessageDisplay = get_tree().get_first_node_in_group(MESSAGE_GROUP) as MessageDisplay
	if messages != null:
		messages.show_message("%s +%d" % [item.display_name, count], message_seconds)
	queue_free()


func _on_day_started(_day: int) -> void:
	queue_free()


## アイテムIDから決まる色(同じアイテムは同じ色)
func _color_for(data: ItemData) -> Color:
	var hue: float = float(absi(hash(String(data.id))) % 360) / 360.0
	return Color.from_hsv(hue, 0.6, 0.95)
