---
name: macOS VLMアプリ開発
description: ollamaを使った画像解析macOSアプリの開発プロジェクト
type: project
---

macOS向けVLM画像解析アプリを開発中。

**技術スタック:** SwiftUI (macOS 14+) / Swift Package Manager

**GitHubリポジトリ:** https://github.com/SHINYATODORI/LocalVLM

**現在使用モデル:** qwen3-vl:8b（6.1GB、GPT-4o相当、DocVQA 95.3%）
- アプリ内ツールバーでモデル切替可能（ollama APIから自動取得）

**実装済み機能:**
- 複数画像読み込み（ドラッグ&ドロップ / ファイル選択）
- 共通プロンプト（TextEditor、リサイズ可）
- 個別プロンプト（各画像カードにTextEditor）
- 個別解析 / 全件同時解析（withTaskGroup並列）
- プログレスバー（解析中に下部ステータスバーに表示）
- メモリグラフ（Swift Charts、2秒ポーリング、下部ステータスバー常駐）
- HTMLレポート生成（写真base64埋め込み、WKWebView表示）
- .appバンドル化（build_app.sh）
- **ツールバーモデル選択ピッカー**（ollama APIから利用可能モデル自動取得）
- **ollama同時起動制限**（LaunchAgent: OLLAMA_MAX_LOADED_MODELS=1 でフリーズ防止）

**起動方法:**
```bash
cd /Users/shinyatodori/Documents/LocalVLM/VLMAnalyzer
bash build_app.sh && open "VLM Analyzer.app"
```

**次回TODO:**
- 火山灰解析テストの実施（qwen3-vl:8bで試す）
- ファインチューニング用学習データ収集（火山灰画像＋スケール参照物）
- MLX LoRA学習実行（finetune/ ディレクトリ準備済み）
