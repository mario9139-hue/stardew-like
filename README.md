# Stardew-like Farm

Godot 4(GDScript)で作る、スタデューバレー風の2D農場ゲーム。

## 動かし方
1. Godot 4.3 以降でこのフォルダを開く(`project.godot` を選択)
2. F5(実行)で、空のウィンドウが表示されれば土台は完了

## フォルダ構成

| フォルダ | 役割 |
|---|---|
| `scenes/` | シーン(`.tscn`)。画面・キャラ・畑タイルなどのノード構成。エントリは `scenes/main.tscn` |
| `scripts/` | GDScript(`.gd`)。シーンにアタッチするロジックと、リソース定義クラス(`class_name`) |
| `data/` | データ駆動用のリソース(`.tres`)。作物・アイテム・武器・モンスターなどの定義 |
| `assets/` | 画像・音などの素材。当面は仮素材(色付き四角)で進める |

## 主要設定
- 基準解像度: 320x180(ウィンドウ初期サイズは 1280x720)
- ストレッチモード: `viewport`
- テクスチャフィルタ: `Nearest`(ピクセルアート用)
- タイルサイズ: 16x16

開発ルールとゲーム仕様は `CLAUDE.md` を参照。

## Web 公開(GitHub Pages)
`main` ブランチに push すると、GitHub Actions(`.github/workflows/deploy.yml`)が Web 版を書き出して GitHub Pages に公開する。

- 使用イメージ: `barichello/godot-ci:4.3`(Godot 4.3 + 書き出しテンプレート入り)。`project.godot` の Godot 4.3 に合わせている。バージョンを上げるときは `deploy.yml` の `image` のタグを変える
- 書き出し設定: `export_presets.cfg` の「Web」プリセット。**シングルスレッド出力**(`variant/thread_support=false`)。GitHub Pages ではレスポンスヘッダ(COOP/COEP)を制御できないため
- レンダラー: Web は互換(`gl_compatibility`)で動く(`project.godot` の `rendering_method.web`)
- 成果物は `build/web/`(`.gitignore` 済み)。手元で試すときは Godot で「プロジェクト → エクスポート → Web」
- 初回だけ GitHub のリポジトリ設定で、Settings → Pages → Build and deployment → Source を **GitHub Actions** にする
- 公開URL: `https://<ユーザー名>.github.io/<リポジトリ名>/`
- ブラウザでセーブが動くかの確認手順: `docs/web_test.md`

### Web 版の注意点
- **初回の読み込みが重い**: Godot のエンジン(wasm)を読み込むため、初回はしばらく待つ。2回目以降はブラウザのキャッシュで速くなる
- **音声はユーザー操作後に鳴る**: ブラウザの制限で、画面をクリック/タップするまで音は鳴らない(今は音声なし。追加したときに備えた注意)
- セーブはブラウザ内(IndexedDB)に保存される。ブラウザのサイトデータを消すとセーブも消える。別のブラウザ・端末とは共有されない
- タイトルの「終了」は、Web ではブラウザのタブを閉じる操作の代わりにはならない(何も起きない)

## フォント
Web 版にはパソコンの日本語フォントがないため、日本語フォントを同梱している(`assets/fonts/NotoSansJP-Subset.otf`、Noto Sans CJK JP の一部を抜き出したもの、約1.5MB)。
全 UI の標準フォントとして `project.godot` の `gui/theme/custom_font` に設定済み。ライセンス(SIL OFL)は `assets/fonts/FONT_LICENSE.txt`。
含まれる文字: ASCII、ひらがな・カタカナ、記号、JIS X 0208 の漢字(第1・第2水準)。それ以外の文字を使うときはフォントを作り直す。
