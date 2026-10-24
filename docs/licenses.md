# 同梱している外部ファイルとライセンス

| ファイル | 内容 | ライセンス | 商用販売 | 義務 |
|---|---|---|---|---|
| assets/fonts/NotoSansJP-Subset.otf | Noto Sans CJK JP Regular から必要な文字だけ抜き出したもの | SIL Open Font License 1.1 | 可・無料 | ライセンス文と著作権表記を同梱する(assets/fonts/FONT_LICENSE.txt)。フォント単体での販売は不可 |

上記以外の画像・音・スクリプトは自作(仮素材)で、外部のものは入っていない。
外部ファイルを追加したら、この表に必ず足す(CLAUDE.md ルール12)。

## 確認記録
- 2026-10-25: Noto Sans CJK 公式リポジトリ(github.com/notofonts/noto-cjk)で最新版が 2.004 であること、ライセンスが SIL OFL 1.1 であることを確認。同梱フォントも 2.004。
- 2026-10-25: タイトル画面に「クレジット」ボタンを追加し、フォントの著作権表記とライセンス全文をゲーム内で表示(export_presets.cfg の include_filter で FONT_LICENSE.txt を書き出しに含める)。
