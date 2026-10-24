class_name GameConfig
extends RefCounted
## タイルサイズと基準解像度を集約した設定(ここだけを書き換えれば、全体が追従する)。
## 例: タイル 32 / 480x270 にするときは TILE_SIZE と BASE_WIDTH / BASE_HEIGHT だけを変える。
## ※ 定数にしてあるのは、他スクリプトの const や TileSet 生成(起動時)で使うため。
##   起動時に GameSetup(Autoload)が BASE_RESOLUTION をウィンドウのコンテンツサイズへ反映する。

## 1マスの大きさ(px)
const TILE_SIZE: int = 16
## 基準解像度(px)
const BASE_WIDTH: int = 320
const BASE_HEIGHT: int = 180
const BASE_RESOLUTION: Vector2i = Vector2i(BASE_WIDTH, BASE_HEIGHT)
## マップのサイズ(マス数)。基準解像度に収まる最大のマス数
const MAP_SIZE: Vector2i = Vector2i(BASE_WIDTH / TILE_SIZE, BASE_HEIGHT / TILE_SIZE)
## シーン(.tscn)や仮素材の寸法を書くときの基準タイルサイズ。
## 「基準タイルで 16px」の寸法は、TILE_SIZE に合わせて scale() で拡大縮小する
const REFERENCE_TILE_SIZE: int = 16


## 基準タイルサイズに対する倍率(TILE_SIZE=32 なら 2.0)
static func scale() -> float:
	return float(TILE_SIZE) / float(REFERENCE_TILE_SIZE)


## 基準タイルでの寸法(px)を、現在のタイルサイズでの寸法に直す
static func px(reference_px: float) -> float:
	return reference_px * scale()


## マップ全体の大きさ(px)
static func map_pixel_size() -> Vector2:
	return Vector2(MAP_SIZE * TILE_SIZE)
