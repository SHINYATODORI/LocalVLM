# 開発ログ

## 2026-05-21

### セットアップ完了
- ollama インストール済み確認
- `qwen2.5vl:7b`（6GB）のpull完了
- Pythonパッケージ `ollama` インストール完了
- 動作確認: 画像からテキスト読み取り成功（赤背景に「Hello VLM!」を正確に認識）

### 方針決定
- macOSアプリ開発開始
- 技術スタック選定中（SwiftUI / Python+customtkinter）
- 作業はGitHubに常時push
- 仕様・ログはローカルの docs/ logs/ に記録

### 作成ファイル
- `vlm_demo.py` - ollama VLMのPythonサンプルスクリプト
- `docs/spec_app_overview.md` - アプリ仕様書（初版）
- `logs/devlog.md` - このファイル
