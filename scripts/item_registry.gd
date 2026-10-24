extends Node
## データ(.tres)の索引(Autoload: ItemRegistry)。data/ 配下を起動時に走査して、id で引けるようにする。
## セーブデータは ItemData / CropData / MonsterData を id で保存し、ロード時にここで復元する。
## 書き出し後(Web など)は、リソース名が「xxx.tres.remap」になるので、その場合も読めるようにしている。
## ※Autoload 名と衝突するため、このスクリプトには class_name を付けない。

const DATA_ROOT: String = "res://data"

var _items: Dictionary = {}
var _crops: Dictionary = {}
var _monsters: Dictionary = {}


func _ready() -> void:
	_scan(DATA_ROOT)


## id から ItemData を返す(なければ null)
func get_item(id: StringName) -> ItemData:
	return _items.get(id)


## id から CropData を返す(なければ null)
func get_crop(id: StringName) -> CropData:
	return _crops.get(id)


## id から MonsterData を返す(なければ null)
func get_monster(id: StringName) -> MonsterData:
	return _monsters.get(id)


func _scan(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub_dir: String in dir.get_directories():
		_scan(dir_path.path_join(sub_dir))
	for file_name: String in dir.get_files():
		var resource_name: String = file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		_register(load(dir_path.path_join(resource_name)))


func _register(resource: Resource) -> void:
	if resource is ItemData:
		_items[(resource as ItemData).id] = resource
	elif resource is CropData:
		_crops[(resource as CropData).id] = resource
	elif resource is MonsterData:
		_monsters[(resource as MonsterData).id] = resource
