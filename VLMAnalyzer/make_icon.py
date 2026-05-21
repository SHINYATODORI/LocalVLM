#!/usr/bin/env python3
"""VLM Analyzer アイコン生成スクリプト"""
import os, math, subprocess
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024

def make_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size

    # 背景: ダークネイビー→ディープブルーグラデーション
    for y in range(s):
        t = y / s
        r = int(10 + t * 15)
        g = int(15 + t * 25)
        b = int(50 + t * 80)
        d.line([(0, y), (s, y)], fill=(r, g, b, 255))

    # 角丸マスク
    mask = Image.new("L", (s, s), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, s-1, s-1], radius=int(s * 0.18), fill=255)
    img.putalpha(mask)
    d = ImageDraw.Draw(img)

    cx, cy = s // 2, s // 2

    # --- カメラボディ ---
    cw, ch = int(s * 0.62), int(s * 0.46)
    cx0, cy0 = cx - cw // 2, cy - ch // 2 + int(s * 0.04)
    cr = int(s * 0.06)

    # 影
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        [cx0 + int(s*0.02), cy0 + int(s*0.025),
         cx0 + cw + int(s*0.02), cy0 + ch + int(s*0.025)],
        radius=cr, fill=(0, 0, 0, 100)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=int(s * 0.03)))
    img = Image.alpha_composite(img, shadow)
    d = ImageDraw.Draw(img)

    # ボディ
    d.rounded_rectangle([cx0, cy0, cx0 + cw, cy0 + ch], radius=cr,
                         fill=(30, 35, 70, 255))
    d.rounded_rectangle([cx0 + 3, cy0 + 3, cx0 + cw - 3, cy0 + ch - 3], radius=cr,
                         outline=(70, 90, 180, 120), width=2)

    # ファインダー出っ張り (上部)
    fw, fh = int(cw * 0.28), int(s * 0.07)
    fx0 = cx - fw // 2
    fy0 = cy0 - fh
    d.rounded_rectangle([fx0, fy0, fx0 + fw, cy0 + 4],
                         radius=int(s * 0.025), fill=(30, 35, 70, 255))

    # --- レンズ外枠 ---
    lr = int(s * 0.19)
    d.ellipse([cx - lr, cy - lr + int(s*0.04),
               cx + lr, cy + lr + int(s*0.04)],
              fill=(15, 20, 50, 255))
    # レンズリング
    for i, (col, thick) in enumerate([
        ((80, 110, 220, 200), int(s*0.018)),
        ((50, 70, 160, 150), int(s*0.010)),
    ]):
        rr = lr - int(s * 0.01) - i * int(s * 0.022)
        d.ellipse([cx - rr, cy - rr + int(s*0.04),
                   cx + rr, cy + rr + int(s*0.04)],
                  outline=col, width=thick)

    # レンズ内 グラデーション風
    for step in range(20):
        t = step / 20
        rr = int((lr - int(s*0.045)) * (1 - t * 0.85))
        alpha = int(180 * (1 - t))
        col_r = int(20 + t * 60)
        col_g = int(30 + t * 80)
        col_b = int(100 + t * 120)
        d.ellipse([cx - rr, cy - rr + int(s*0.04),
                   cx + rr, cy + rr + int(s*0.04)],
                  fill=(col_r, col_g, col_b, alpha))

    # レンズ中心の光点
    hr = int(s * 0.025)
    d.ellipse([cx - hr, cy - hr + int(s*0.04),
               cx + hr, cy + hr + int(s*0.04)],
              fill=(200, 220, 255, 200))

    # --- AI スパークルバッジ (右上) ---
    bx = int(s * 0.73)
    by = int(s * 0.24)
    br = int(s * 0.115)

    badge_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge_layer)
    bd.ellipse([bx - br, by - br, bx + br, by + br],
               fill=(80, 200, 255, 255))
    img = Image.alpha_composite(img, badge_layer)
    d = ImageDraw.Draw(img)

    # 星型スパーク (4点)
    spark_color = (255, 255, 255, 255)
    sw = max(2, int(s * 0.016))
    sr = int(br * 0.62)
    for angle in [0, 90, 180, 270]:
        rad = math.radians(angle)
        ex = bx + int(sr * math.cos(rad))
        ey = by + int(sr * math.sin(rad))
        d.line([(bx, by), (ex, ey)], fill=spark_color, width=sw)
    for angle in [45, 135, 225, 315]:
        rad = math.radians(angle)
        ex = bx + int(sr * 0.55 * math.cos(rad))
        ey = by + int(sr * 0.55 * math.sin(rad))
        d.line([(bx, by), (ex, ey)], fill=spark_color, width=max(1, sw - 1))

    # 中心点
    cr2 = int(br * 0.15)
    d.ellipse([bx - cr2, by - cr2, bx + cr2, by + cr2], fill=spark_color)

    # --- 上部 光沢 ---
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([int(s*0.1), int(-s*0.05), int(s*0.9), int(s*0.3)],
               fill=(255, 255, 255, 14))
    img = Image.alpha_composite(img, glow)

    return img


os.makedirs("icon.iconset", exist_ok=True)

base = make_icon(SIZE)
sizes = [16, 32, 64, 128, 256, 512, 1024]
for sz in sizes:
    resized = base.resize((sz, sz), Image.LANCZOS)
    resized.save(f"icon.iconset/icon_{sz}x{sz}.png")
    if sz <= 512:
        resized.resize((sz * 2, sz * 2), Image.LANCZOS).save(
            f"icon.iconset/icon_{sz}x{sz}@2x.png"
        )

subprocess.run(["iconutil", "-c", "icns", "icon.iconset", "-o", "AppIcon.icns"], check=True)
print("✅ AppIcon.icns を生成しました")
