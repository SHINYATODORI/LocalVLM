#!/bin/bash
set -e

APP_NAME="VLM Analyzer"
BINARY_NAME="VLMAnalyzer"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"

echo "▶ ビルド中..."
swift build -c release 2>&1

BINARY=".build/release/${BINARY_NAME}"
if [ ! -f "$BINARY" ]; then
    echo "❌ バイナリが見つかりません: $BINARY"
    exit 1
fi

echo "▶ .app バンドルを作成中..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

cp "$BINARY" "${CONTENTS}/MacOS/${BINARY_NAME}"
cp "Info.plist" "${CONTENTS}/Info.plist"

echo "▶ アイコンを生成中..."
python3 make_icon.py
cp "AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"

echo "▶ コード署名中..."
xattr -cr "${APP_BUNDLE}"
codesign --force --deep --sign - "${APP_BUNDLE}" 2>&1 || {
    echo "⚠️  署名をスキップ（開発用として実行可能です）"
}

echo ""
echo "✅ 完成: $(pwd)/${APP_BUNDLE}"
echo ""
echo "起動方法:"
echo "  open \"${APP_BUNDLE}\""
