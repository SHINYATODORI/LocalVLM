# 開発ログ

## 2026-05-21

### セットアップ完了
- ollama インストール済み確認
- `qwen2.5vl:7b`（6GB）のpull完了
- Pythonパッケージ `ollama` インストール完了
- 動作確認: 画像からテキスト読み取り成功（赤背景に「Hello VLM!」を正確に認識）

### 方針決定
- macOSアプリ: SwiftUI (macOS 14+) で実装
- 作業はGitHubに常時push
- 仕様・ログはローカルの docs/ logs/ に記録

### 作成ファイル
- `vlm_demo.py` - ollama VLMのPythonサンプルスクリプト
- `docs/spec_app_overview.md` - アプリ仕様書（初版）
- `logs/devlog.md` - このファイル

## 2026-05-21 (続き)

### SwiftUI macOS アプリ 実装完了

**実装ファイル:**
- `VLMAnalyzer/Package.swift` — Swift Package 設定 (macOS 14+)
- `VLMAnalyzer/Sources/VLMAnalyzer/VLMAnalyzerApp.swift` — `@main` エントリポイント
- `VLMAnalyzer/Sources/VLMAnalyzer/AppViewModel.swift` — `@Observable @MainActor` ViewModel
- `VLMAnalyzer/Sources/VLMAnalyzer/Models/ImageItem.swift` — 画像データモデル
- `VLMAnalyzer/Sources/VLMAnalyzer/Services/OllamaService.swift` — ollama REST API `actor`
- `VLMAnalyzer/Sources/VLMAnalyzer/Views/ContentView.swift` — メイン画面
- `VLMAnalyzer/Sources/VLMAnalyzer/Views/ImageCardView.swift` — 画像カード
- `VLMAnalyzer/Sources/VLMAnalyzer/Views/ReportView.swift` — レポートシート

**ビルド結果:** `Build complete! (33.18s)` — エラーなし

**主要設計:**
- 全件解析: `withTaskGroup` で並列実行、各タスクは OllamaService actor 経由
- 個別解析: 各 ImageCardView の「解析」ボタン
- 共通プロンプト + 個別プロンプトを結合して ollama に送信
- レポート: Markdown形式、NSSavePanel でファイル保存

**起動方法:**
```bash
cd VLMAnalyzer && swift run
# または Xcode で open Package.swift
```
