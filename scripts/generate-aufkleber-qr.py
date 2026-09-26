#!/usr/bin/env python3
"""Druckfertiger Luckys-Taxi-Aufkleber: Logo-Text, 5 Sterne, QR → scan.html."""
from __future__ import annotations

from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "web" / "luckys-taxi-aufkleber-qr.png"
SCAN_URL = "https://luckystaxiapp.de/scan.html"

YELLOW = (255, 204, 0)
YELLOW_SOFT = (255, 230, 100)
NAVY = (12, 28, 52)
GOLD = (212, 160, 23)
WHITE = (255, 255, 255)


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        if Path(path).is_file():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def draw_star(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill) -> None:
    import math

    pts = []
    for i in range(10):
        ang = math.radians(-90 + i * 36)
        rad = r if i % 2 == 0 else r * 0.4
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    draw.polygon(pts, fill=fill)


def main() -> None:
    size = 1500
    img = Image.new("RGB", (size, size), YELLOW)
    draw = ImageDraw.Draw(img)

    # Rahmen
    draw.rounded_rectangle((36, 36, size - 36, size - 36), radius=72, outline=NAVY, width=14)

    # 5 goldene Sterne
    star_y = 140
    gap = 88
    start_x = size / 2 - 2 * gap
    for i in range(5):
        draw_star(draw, start_x + i * gap, star_y, 34, GOLD)

    f_label = font(42)
    f_title = font(92)
    f_lead = font(48)
    f_scan = font(64)
    f_en = font(40, bold=False)
    f_url = font(36, bold=False)

    def center_text(text: str, y: int, fnt, fill=NAVY) -> None:
        bbox = draw.textbbox((0, 0), text, font=fnt)
        tw = bbox[2] - bbox[0]
        draw.text(((size - tw) / 2, y), text, font=fnt, fill=fill)

    center_text("5 Sterne · Sehr gut", 200, f_label)
    center_text("Lucky's Taxi App", 270, f_title)
    center_text("Taxi online bestellen", 390, f_lead)

    # QR → scan.html (gelber Sofort-Einstieg, weniger Render-Zwischenseite)
    qr = qrcode.QRCode(version=None, error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=14, border=2)
    qr.add_data(SCAN_URL)
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color=NAVY, back_color=WHITE).convert("RGB")
    qr_side = 620
    qr_img = qr_img.resize((qr_side, qr_side), Image.Resampling.NEAREST)
    qx = (size - qr_side) // 2
    qy = 480
    pad = 28
    draw.rounded_rectangle(
        (qx - pad, qy - pad, qx + qr_side + pad, qy + qr_side + pad),
        radius=28,
        fill=YELLOW_SOFT,
        outline=NAVY,
        width=6,
    )
    img.paste(qr_img, (qx, qy))

    center_text("Bitte scannen", 1160, f_scan)
    center_text("Please scan me", 1240, f_en)
    center_text("luckystaxiapp.de/scan.html", 1360, f_url)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT} → {SCAN_URL}")


if __name__ == "__main__":
    main()
