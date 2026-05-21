---
name: macOS VLMアプリ開発
description: ollamaを使った画像解析macOSアプリの開発プロジェクト
type: project
---

macOS向けVLM画像解析アプリを開発中。

**技術スタック:** SwiftUI (macOS 14+) / Swift Package Manager

**GitHubリポジトリ:** https://github.com/SHINYATODORI/LocalVLM

**現在使用モデル:** qwen2.5vl:32b（21GB）
⚠️ PC不安定のため次回モデルサイズ要検討（qwen2.5vl:7bかllava:13bが候補）

**実装済み機能:**
- 複数画像読み込み（ドラッグ&ドロップ / ファイル選択）
- 共通プロンプト（TextEditor、リサイズ可）
- 個別プロンプト（各画像カードにTextEditor）
- 個別解析 / 全件同時解析（withTaskGroup並列）
- プログレスバー（解析中に下部ステータスバーに表示）
- メモリグラフ（Swift Charts、2秒ポーリング、下部ステータスバー常駐）
- HTMLレポート生成（写真base64埋め込み、WKWebView表示）
- .appバンドル化（build_app.sh）

**起動方法:**
```bash
cd /Users/shinyatodori/Documents/LocalVLM/VLMAnalyzer
bash build_app.sh && open "VLM Analyzer.app"
```

**次回TODO:**
- モデルをqwen2.5vl:7b or llava:13bに変更して動作確認
- アプリUIのスクリーンショット確認（メモリグラフ表示位置）
- 火山灰解析テストの実施
