#!/usr/bin/env python3
"""Druckfertiger Luckys-Taxi-Aufkleber (Neugestaltung): Markenstern, 5 Sterne, QR → scan.html."""
from __future__ import annotations

import math
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "web" / "luckys-taxi-aufkleber-qr.png"
OUT_QR_ONLY = ROOT / "web" / "luckys-taxi-qr-scan.png"
SCAN_URL = "https://luckystaxiapp.de/scan.html"

YELLOW = (255, 204, 0)
YELLOW_LIGHT = (255, 235, 130)
YELLOW_DEEP = (245, 188, 0)
NAVY = (12, 28, 52)
GOLD = (218, 165, 32)
GOLD_EDGE = (150, 105, 8)
WHITE = (255, 255, 255)


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/croscore/Arimo-Bold.ttf" if bold else "/usr/share/fonts/truetype/croscore/Arimo-Regular.ttf",
    ]
    for path in candidates:
        if Path(path).is_file():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def star_points(cx: float, cy: float, r_outer: float, r_inner: float) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    for i in range(10):
        ang = math.radians(-90 + i * 36)
        rad = r_outer if i % 2 == 0 else r_inner
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    return pts


def draw_star(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    r: float,
    fill,
    outline=None,
    width: int = 0,
) -> None:
    pts = star_points(cx, cy, r, r * 0.4)
    draw.polygon(pts, fill=fill)
    if outline and width > 0:
        draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def center_text(draw: ImageDraw.ImageDraw, text: str, y: int, fnt, fill=NAVY, canvas: int = 1500) -> None:
    bbox = draw.textbbox((0, 0), text, font=fnt)
    tw = bbox[2] - bbox[0]
    draw.text(((canvas - tw) / 2, y), text, font=fnt, fill=fill)


def brand_mark(size: int = 320) -> Image.Image:
    """Navy-Stern mit gelbem Markentext — ohne Admin, ohne Sternenkreis."""
    mark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(mark)
    cx = cy = size / 2
    draw_star(d, cx, cy, size * 0.48, NAVY)
    lines = ["Lucky's", "Taxi", "App"]
    f = font(max(26, int(size * 0.14)))
    line_gaps = []
    for line in lines:
        bb = d.textbbox((0, 0), line, font=f)
        line_gaps.append((line, bb[2] - bb[0], bb[3] - bb[1]))
    total_h = sum(h for _, _, h in line_gaps) + 6 * (len(lines) - 1)
    y = cy - total_h / 2 + 4
    for line, tw, th in line_gaps:
        d.text((cx - tw / 2, y), line, font=f, fill=YELLOW)
        y += th + 6
    return mark


def make_qr(side: int) -> Image.Image:
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=16,
        border=3,
    )
    qr.add_data(SCAN_URL)
    qr.make(fit=True)
    raw = qr.make_image(fill_color=NAVY, back_color=WHITE).convert("RGB")
    return raw.resize((side, side), Image.Resampling.NEAREST)


def main() -> None:
    size = 1500
    img = Image.new("RGB", (size, size), YELLOW)
    pix = img.load()
    for y in range(size):
        t = y / (size - 1)
        r = int(YELLOW_LIGHT[0] * (1 - t) + YELLOW_DEEP[0] * t)
        g = int(YELLOW_LIGHT[1] * (1 - t) + YELLOW_DEEP[1] * t)
        b = int(YELLOW_LIGHT[2] * (1 - t) + YELLOW_DEEP[2] * t)
        for x in range(size):
            pix[x, y] = (r, g, b)

    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((28, 28, size - 28, size - 28), radius=80, outline=NAVY, width=16)

    # 5 goldene Sterne oben (kompakter, alles etwas höher)
    star_y = 100
    gap = 90
    start_x = size / 2 - 2 * gap
    for i in range(5):
        draw_star(draw, start_x + i * gap, star_y, 34, GOLD, outline=GOLD_EDGE, width=3)

    f_label = font(38)
    f_lead = font(52)
    f_scan = font(66)
    f_en = font(36, bold=False)
    f_url = font(32, bold=False)

    center_text(draw, "5 Sterne · Sehr gut", 150, f_label)

    # Überschrift WEIT OBEN — klar frei, nicht am QR
    lead = "Taxi online bestellen"
    lead_y = 205
    center_text(draw, lead, lead_y, f_lead)
    lead_bb = draw.textbbox((0, lead_y), lead, font=f_lead)

    # Markenstern darunter
    mark = brand_mark(250)
    mark_y = lead_bb[3] + 12
    img.paste(mark, ((size - mark.width) // 2, mark_y), mark)

    # QR mit großzügigem Abstand unter dem Stern
    qr_side = 500
    qr_img = make_qr(qr_side)
    pad = 26
    qx = (size - qr_side) // 2
    qy = mark_y + mark.height + 28 + pad
    draw.rounded_rectangle(
        (qx - pad, qy - pad, qx + qr_side + pad, qy + qr_side + pad),
        radius=28,
        fill=WHITE,
        outline=NAVY,
        width=8,
    )
    img.paste(qr_img, (qx, qy))

    below = qy + qr_side + pad + 24
    center_text(draw, "Bitte scannen", below, f_scan)
    center_text(draw, "Please scan me", below + 70, f_en)
    center_text(draw, "luckystaxiapp.de/scan.html", below + 125, f_url)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT} → {SCAN_URL}")

    only = make_qr(1200)
    only.save(OUT_QR_ONLY, "PNG", optimize=True)
    print(f"Wrote {OUT_QR_ONLY}")


if __name__ == "__main__":
    main()
