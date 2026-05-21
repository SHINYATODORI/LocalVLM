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

## 2026-05-21 (続き2)

### UIアップデート完了

**変更内容:**
- 共通プロンプト入力: TextField → TextEditor（高さ64〜120px、リサイズ可）
- 個別プロンプトも TextEditor 化、プレースホルダー付き
- フォントサイズ全体 +2pt（11→13, 12→14, 13→15pt）
- プログレスバー: 全件解析中に下部ステータスバーへ `X/N 解析中` 表示
- メモリグラフ: MemoryMonitor（2秒ポーリング）+ Swift Charts でリアルタイム表示、下部ステータスバーに常駐
- レポート: WKWebView で HTML 表示、写真を base64 埋め込み、カードスタイル
- レポート保存: HTML形式・Markdown形式の両方に対応

**ビルド:** `Build complete! (4.81s)` — エラーなし

### モデル変更履歴
| モデル | サイズ | 変更日 | 理由 |
|--------|--------|--------|------|
| qwen2.5vl:7b | 6GB | 2026-05-21 | 初期導入 |
| qwen2.5vl:32b | 21GB | 2026-05-21 | 空間推論・定量計算の精度向上のため |

### ⚠️ 課題: モデルサイズとメモリ
- `qwen2.5vl:32b`（21GB）使用中にPCが不安定になる事象が発生
- 36GB RAM のうち OS・アプリ分を除くと実質的な余裕が少ない可能性
- **次回セッションでモデルサイズを再検討すること**

**候補モデル（要検討）:**
| モデル | サイズ | 備考 |
|--------|--------|------|
| qwen2.5vl:7b | 6GB | 安定動作確認済み、推論は弱め |
| qwen2.5vl:32b | 21GB | 現在使用中、PC不安定 |
| llava:13b | 8GB | 中間サイズ候補 |
| minicpm-v | 5.5GB | 軽量・高精度VLM |

→ `qwen2.5vl:7b` に戻すか `llava:13b` を試すのが現実的

### 次回TODO
- [ ] モデルをqwen2.5vl:7bかllava:13bに変更して動作確認
- [ ] アプリUIのスクリーンショット確認（メモリグラフ表示位置の確認）
- [ ] 火山灰解析テストの再実施
