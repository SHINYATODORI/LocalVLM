# VLM Analyzer アプリ仕様書

## 概要
ollamaを使ったローカルVLM画像解析macOSアプリ。

## 使用モデル
- **メインモデル:** qwen2.5vl:7b（ollama経由）
- **環境:** Apple M4 Max / 36GB RAM / macOS

## 機能要件

### 画像管理
- 複数画像の読み込み（ドラッグ&ドロップ or ファイル選択）
- 画像のサムネイル一覧表示

### プロンプト
- 各画像に**個別プロンプト**フィールド
- 全画像に適用される**共通プロンプト**フィールド
- 実行時は `共通プロンプト + 個別プロンプト` を結合して使用

### 解析
- **個別解析:** 特定の画像1枚だけ解析
- **全件解析:** 全画像を同時（並列）に解析
- 解析中はプログレス表示

### 結果・レポート
- 各画像の解析結果をUI上に表示
- レポート生成（Markdown or PDF形式）

## 技術スタック
- **SwiftUI** (macOS 14+) — Swift Package Manager でビルド
- ollama REST API (`http://localhost:11434/api/chat`) を `URLSession` async/await で呼び出し

## アーキテクチャ
```
VLMAnalyzer/
├── Package.swift
└── Sources/VLMAnalyzer/
    ├── VLMAnalyzerApp.swift   # @main エントリポイント
    ├── AppViewModel.swift     # @Observable @MainActor 中央ViewModel
    ├── Models/
    │   └── ImageItem.swift    # 画像1件のデータモデル
    ├── Services/
    │   └── OllamaService.swift # actor: ollama REST API クライアント
    └── Views/
        ├── ContentView.swift   # メイン画面（共通プロンプト・グリッド・ツールバー）
        ├── ImageCardView.swift # 画像カード（サムネイル・個別プロンプト・結果）
        └── ReportView.swift    # レポートシート（Markdown 表示・保存）
```

## ディレクトリ構成
```
LocalVLM/
├── VLMAnalyzer/  # SwiftUI macOS アプリ
├── docs/         # 仕様書・設計メモ
├── logs/         # 作業ログ・変更履歴
└── vlm_demo.py   # Python CLI デモ
```

## 変更履歴
| 日付 | 内容 |
|------|------|
| 2026-05-21 | 初版作成、要件定義 |
| 2026-05-21 | SwiftUI実装完了、ビルド確認済み |
| 2026-05-21 | UIアップデート（プロンプト拡大・フォント+2pt・プログレスバー・メモリグラフ・HTMLレポート） |
| 2026-05-21 | モデルをqwen2.5vl:32bへ変更。PCメモリ不安定のため次回モデルサイズ再検討 |
