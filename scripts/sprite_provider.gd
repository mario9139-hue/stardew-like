class_name SpriteProvider
extends RefCounted
## スプライト(テクスチャ)取得の共通入口。見た目はここを通して取得する。
## - assets/art/<カテゴリ>/<名前>.png があればそれを使う
## - 無ければ、仮の色付き四角を自動生成して返す(大きさは GameConfig.TILE_SIZE に従う)
## ID は "カテゴリ/名前"(例: tiles/grass, crops/turnip_stage1, monsters/slime)。
## カテゴリ: player / tiles / crops / items / monsters / ui / effects
## 注: 結果はキャッシュされるので、素材を追加・削除したら再起動すると反映される。

const ART_ROOT: String = "res://assets/art"
const CATEGORIES: PackedStringArray = ["player", "tiles", "crops", "items", "monsters", "ui", "effects"]

## 仮素材の仕様: { "size": Vector2(基準タイルでのpx), "rects": [[Rect2, Color], ...],
##   "anchor": Vector2(原点の位置。基準タイルのpx。省略すると下の anchor_mode に従う),
##   "anchor_mode": "feet"(足元: 既定) / "center"(中心) }
## feet: 画像の下端を、ノード位置から見て「マスの下半分」に合わせる(キャラ用。背が高くても足元が変わらない)
static var _cache: Dictionary = {}
static var _registry: Dictionary = {}


## テクスチャを返す。spec を渡すと、登録済みの仮素材より優先する(データごとに色が違うモンスター・作物用)
static func get_texture(id: StringName, spec: Dictionary = {}) -> Texture2D:
	var cache_key: String = String(id) if spec.is_empty() else "%s#%d" % [id, spec.hash()]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var texture: Texture2D = null
	if has_art(id):
		texture = load(_art_path(id)) as Texture2D
	if texture == null:
		texture = _make_placeholder(id, spec)
	_cache[cache_key] = texture
	return texture


## assets/art に本素材の PNG があるか
static func has_art(id: StringName) -> bool:
	return ResourceLoader.exists(_art_path(id))


## Sprite2D に素材を設定し、原点を合わせる。
## fallback_id: id の本素材が無いとき、代わりに使う本素材の ID(向き別が無ければ共通、など)
static func apply(sprite: Sprite2D, id: StringName, spec: Dictionary = {}, fallback_id: StringName = &"") -> void:
	var use_id: StringName = id
	if not has_art(id) and fallback_id != &"" and has_art(fallback_id):
		use_id = fallback_id
	var texture: Texture2D = get_texture(use_id, spec)
	var anchor: Vector2 = _anchor_for(use_id, spec, texture.get_size())
	sprite.texture = texture
	sprite.centered = false
	sprite.position = -anchor


## 単色の仮素材の仕様を作る。inset は四辺の余白(基準タイルのpx)
static func solid_spec(color: Color, size: Vector2 = Vector2(16, 16), inset: float = 0.0, anchor_mode: String = "feet") -> Dictionary:
	return {
		"size": size,
		"rects": [[Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), color]],
		"anchor_mode": anchor_mode,
	}


static func _art_path(id: StringName) -> String:
	return "%s/%s.png" % [ART_ROOT, String(id)]


static func _anchor_for(id: StringName, spec: Dictionary, texture_size: Vector2) -> Vector2:
	var resolved: Dictionary = spec if not spec.is_empty() else _get_registry().get(String(id), {})
	if resolved.has("anchor"):
		return Vector2(resolved["anchor"]) * GameConfig.scale()
	if String(resolved.get("anchor_mode", "feet")) == "center":
		return texture_size * 0.5
	return Vector2(texture_size.x * 0.5, texture_size.y - float(GameConfig.TILE_SIZE) * 0.5)


static func _make_placeholder(id: StringName, spec: Dictionary) -> Texture2D:
	var resolved: Dictionary = spec if not spec.is_empty() else _get_registry().get(String(id), {})
	if resolved.is_empty():
		resolved = solid_spec(Color.MAGENTA)
	var scale: float = GameConfig.scale()
	var ref_size: Vector2 = resolved["size"]
	var width: int = maxi(roundi(ref_size.x * scale), 1)
	var height: int = maxi(roundi(ref_size.y * scale), 1)
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for entry in resolved["rects"]:
		var rect: Rect2 = entry[0]
		var color: Color = entry[1]
		var x0: int = clampi(roundi(rect.position.x * scale), 0, width)
		var y0: int = clampi(roundi(rect.position.y * scale), 0, height)
		var x1: int = clampi(maxi(roundi(rect.end.x * scale), x0 + 1), 0, width)
		var y1: int = clampi(maxi(roundi(rect.end.y * scale), y0 + 1), 0, height)
		if x1 > x0 and y1 > y0:
			image.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), color)
	return ImageTexture.create_from_image(image)


## 登録済みの仮素材(色は従来の仮タイル・仮オブジェクトと同じ)
static func _get_registry() -> Dictionary:
	if not _registry.is_empty():
		return _registry
	var tile_border: Dictionary = {
		"grass": [Color8(76, 145, 66), Color8(89, 166, 77)],
		"farmland": [Color8(120, 82, 46), Color8(140, 97, 56)],
		"tilled": [Color8(74, 48, 28), Color8(102, 70, 42)],
		"tilled_wet": [Color8(44, 29, 19), Color8(66, 45, 30)],
	}
	for tile_name: String in tile_border.keys():
		var colors: Array = tile_border[tile_name]
		var rects: Array = [[Rect2(0, 0, 16, 16), colors[0]], [Rect2(1, 1, 14, 14), colors[1]]]
		if tile_name.begins_with("tilled"):
			# 畝(うね)の線2本
			rects.append([Rect2(2, 5, 12, 1), colors[0]])
			rects.append([Rect2(2, 10, 12, 1), colors[0]])
		_registry["tiles/" + tile_name] = {"size": Vector2(16, 16), "rects": rects}

	var player_spec: Dictionary = solid_spec(Color(0.9, 0.3, 0.3, 1.0))
	for direction: String in ["up", "down", "left", "right"]:
		_registry["player/player_" + direction] = player_spec
	_registry["player/player"] = player_spec

	_registry["effects/hit_flash"] = solid_spec(Color.WHITE)

	# マップ上の建物・設備(原点は従来のノード位置と同じ)
	_registry["tiles/house"] = {
		"size": Vector2(56, 40), "anchor": Vector2(28, 40),
		"rects": [
			[Rect2(4, 8, 48, 32), Color(0.7, 0.35, 0.3, 1)],
			[Rect2(0, 0, 56, 8), Color(0.4, 0.2, 0.2, 1)],
			[Rect2(24, 28, 8, 12), Color(0.25, 0.15, 0.1, 1)],
		],
	}
	_registry["tiles/shop"] = {
		"size": Vector2(48, 32), "anchor": Vector2(24, 32),
		"rects": [
			[Rect2(4, 4, 40, 28), Color(0.3, 0.45, 0.75, 1)],
			[Rect2(0, 0, 48, 8), Color(0.85, 0.3, 0.3, 1)],
			[Rect2(20, 20, 8, 12), Color(0.2, 0.2, 0.3, 1)],
		],
	}
	_registry["tiles/well"] = {
		"size": Vector2(16, 16), "anchor": Vector2(8, 8),
		"rects": [
			[Rect2(0, 0, 16, 16), Color(0.45, 0.5, 0.6, 1)],
			[Rect2(3, 3, 10, 10), Color(0.2, 0.4, 0.8, 1)],
		],
	}
	_registry["tiles/sales_box"] = {
		"size": Vector2(18, 18), "anchor": Vector2(9, 10),
		"rects": [
			[Rect2(1, 2, 16, 16), Color(0.85, 0.65, 0.25, 1)],
			[Rect2(0, 0, 18, 4), Color(0.6, 0.4, 0.15, 1)],
		],
	}
	return _registry
