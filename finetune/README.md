# ファインチューニング

qwen3-vl:8b を MLX (Apple Silicon) で LoRA ファインチューニングする。

## ディレクトリ構成

```
finetune/
├── data/
│   ├── images/        ← 学習用画像をここに置く（例: 火山灰の写真）
│   └── annotations/   ← 正解データ（JSON形式）
├── output/            ← 学習済みLoRAアダプター出力先
└── scripts/           ← 学習・変換スクリプト
```

## 学習データの形式

`data/annotations/train.jsonl` に1行1サンプルのJSONL形式で記述：

```jsonl
{"image": "images/ash_001.jpg", "prompt": "この画像の火山灰の積もった深さを推定してください。ペットボトル（高さ22cm）が写っています。", "response": "ペットボトルの約1/4の高さまで積もっているため、約5〜6cmと推定されます。"}
{"image": "images/ash_002.jpg", "prompt": "火山灰の積載量を推定してください。定規（30cm）が写っています。", "response": "定規の目盛りから約8cmの積雪が確認できます。"}
```

## 学習手順

```bash
# 1. モデルをHugging Face形式でダウンロード
python3 scripts/download_model.py

# 2. LoRAで学習
python3 -m mlx_lm.lora \
  --model ./base_model \
  --train \
  --data data/annotations \
  --iters 500

# 3. アダプターをマージ
python3 -m mlx_lm.fuse \
  --model ./base_model \
  --adapter-path ./output/adapters \
  --save-path ./output/fused_model

# 4. ollama用に変換してインポート
python3 scripts/convert_to_ollama.py
```

## 必要なデータ量の目安

| 用途 | 最小枚数 | 推奨枚数 |
|------|---------|---------|
| 特定物体の認識改善 | 20〜50枚 | 100枚以上 |
| 深さ・計測推定 | 50〜100枚 | 200枚以上 |
| 汎用品質向上 | 200枚以上 | 500枚以上 |

## ステータス
- [x] MLX環境構築完了
- [ ] 学習データ収集
- [ ] LoRA学習実行
- [ ] ollama組み込み
