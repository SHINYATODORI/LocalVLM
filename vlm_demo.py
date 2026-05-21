"""
qwen2.5vl:7b を使った画像処理デモ
Usage:
  python vlm_demo.py <image_path> [prompt]
  python vlm_demo.py photo.jpg "この画像を日本語で説明してください"
"""

import ollama
import sys
import base64
from pathlib import Path


MODEL = "qwen2.5vl:7b"


def image_to_base64(image_path: str) -> str:
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def ask_about_image(image_path: str, prompt: str = "この画像を日本語で詳しく説明してください。") -> str:
    path = Path(image_path)
    if not path.exists():
        raise FileNotFoundError(f"画像が見つかりません: {image_path}")

    print(f"モデル: {MODEL}")
    print(f"画像: {image_path}")
    print(f"質問: {prompt}")
    print("-" * 40)

    response = ollama.chat(
        model=MODEL,
        messages=[
            {
                "role": "user",
                "content": prompt,
                "images": [str(path)],
            }
        ],
    )

    return response["message"]["content"]


def main():
    if len(sys.argv) < 2:
        print("Usage: python vlm_demo.py <image_path> [prompt]")
        print("例: python vlm_demo.py photo.jpg")
        print('例: python vlm_demo.py photo.jpg "この画像の文字を読み取ってください"')
        sys.exit(1)

    image_path = sys.argv[1]
    prompt = sys.argv[2] if len(sys.argv) > 2 else "この画像を日本語で詳しく説明してください。"

    result = ask_about_image(image_path, prompt)
    print(result)


if __name__ == "__main__":
    main()
