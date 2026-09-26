#!/usr/bin/env python3
"""Runder Luckys-Taxi-Aufkleber: Sterne im Bogen, QR → scan.html."""
from __future__ import annotations

import math
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "web" / "luckys-taxi-aufkleber-qr.png"
OUT_V2 = ROOT / "web" / "luckys-taxi-aufkleber-v2.png"
OUT_ROUND = ROOT / "web" / "luckys-taxi-aufkleber-rund.png"
OUT_QR_ONLY = ROOT / "web" / "luckys-taxi-qr-scan.png"
SCAN_URL = "https://luckystaxiapp.de/scan.html"

YELLOW = (255, 204, 0, 255)
YELLOW_LIGHT = (255, 236, 140, 255)
YELLOW_DEEP = (245, 188, 0, 255)
NAVY = (12, 28, 52, 255)
GOLD = (218, 165, 32, 255)
GOLD_EDGE = (150, 105, 8, 255)
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/croscore/Arimo-Bold.ttf" if bold else "/usr/share/fonts/truetype/croscore/Arimo-Regular.ttf",
    ):
        if Path(path).is_file():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def star_points(cx: float, cy: float, r_outer: float, r_inner: float):
    pts = []
    for i in range(10):
        ang = math.radians(-90 + i * 36)
        rad = r_outer if i % 2 == 0 else r_inner
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    return pts


def draw_star(draw, cx, cy, r, fill, outline=None, width=0):
    pts = star_points(cx, cy, r, r * 0.4)
    draw.polygon(pts, fill=fill)
    if outline and width:
        draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def center_text(draw, text, y, fnt, fill=NAVY, canvas=1500):
    bb = draw.textbbox((0, 0), text, font=fnt)
    tw = bb[2] - bb[0]
    x = (canvas - tw) / 2
    draw.text((x, y), text, font=fnt, fill=fill)
    return draw.textbbox((x, y), text, font=fnt)


def brand_mark(size=200) -> Image.Image:
    mark = Image.new("RGBA", (size, size), TRANSPARENT)
    d = ImageDraw.Draw(mark)
    cx = cy = size / 2
    draw_star(d, cx, cy, size * 0.48, NAVY)
    lines = ["Lucky's", "Taxi", "App"]
    f = font(max(22, int(size * 0.13)))
    gaps = []
    for line in lines:
        bb = d.textbbox((0, 0), line, font=f)
        gaps.append((line, bb[2] - bb[0], bb[3] - bb[1]))
    total_h = sum(h for _, _, h in gaps) + 4 * (len(lines) - 1)
    y = cy - total_h / 2 + 3
    for line, tw, th in gaps:
        d.text((cx - tw / 2, y), line, font=f, fill=YELLOW)
        y += th + 4
    return mark


def make_qr(side: int) -> Image.Image:
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=16, border=3)
    qr.add_data(SCAN_URL)
    qr.make(fit=True)
    raw = qr.make_image(fill_color=(12, 28, 52), back_color=(255, 255, 255)).convert("RGBA")
    return raw.resize((side, side), Image.Resampling.NEAREST)


def draw_star_rotated(draw, cx, cy, r, angle_deg, fill, outline=None, width=0):
    """Stern um eigene Mitte gedreht (folgt dem Bogen)."""
    pts = []
    rot = math.radians(angle_deg)
    for i in range(10):
        ang = math.radians(-90 + i * 36) + rot
        rad = r if i % 2 == 0 else r * 0.4
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    draw.polygon(pts, fill=fill)
    if outline and width:
        draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def draw_stars_arc(draw, cx: float, cy_apex: float, half_width: float, bulge: float, r: float):
    """5 Sterne deutlich im Bogen (Mitte höher); äußere leicht mitgedreht."""
    for i in range(5):
        t = (i - 2) / 2  # -1 … +1
        x = cx + t * half_width
        y = cy_apex + bulge * (t * t)
        # Tangente der Parabel y = bulge * t^2 → äußere Sterne kippen nach außen
        angle = t * 22  # Grad
        draw_star_rotated(draw, x, y, r, angle, GOLD, outline=GOLD_EDGE, width=3)


def main() -> None:
    size = 1500
    cx = cy = size / 2
    radius = size // 2 - 18

    # Transparent außerhalb des Kreises
    img = Image.new("RGBA", (size, size), TRANSPARENT)
    # Gelber Verlauf nur im Kreis
    base = Image.new("RGBA", (size, size), TRANSPARENT)
    bp = base.load()
    for y in range(size):
        t = y / (size - 1)
        r = int(YELLOW_LIGHT[0] * (1 - t) + YELLOW_DEEP[0] * t)
        g = int(YELLOW_LIGHT[1] * (1 - t) + YELLOW_DEEP[1] * t)
        b = int(YELLOW_LIGHT[2] * (1 - t) + YELLOW_DEEP[2] * t)
        for x in range(size):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius**2:
                bp[x, y] = (r, g, b, 255)
    img = Image.alpha_composite(img, base)
    draw = ImageDraw.Draw(img)

    # Navy-Ring
    ring_w = 18
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        outline=NAVY,
        width=ring_w,
    )
    # Innerer feiner Ring
    draw.ellipse(
        (cx - radius + 28, cy - radius + 28, cx + radius - 28, cy + radius - 28),
        outline=NAVY,
        width=4,
    )

    # 5 Sterne deutlich im Bogen oben (Mitte höher)
    draw_stars_arc(draw, cx=cx, cy_apex=130, half_width=250, bulge=95, r=32)

    center_text(draw, "5 Sterne · Sehr gut", 230, font(34))
    lead_bb = center_text(draw, "Taxi online bestellen", 285, font(48))

    # Markenstern
    mark = brand_mark(200)
    mark_y = lead_bb[3] + 16
    img.paste(mark, ((size - mark.width) // 2, mark_y), mark)

    # QR zentriert
    qr_side = 420
    pad = 20
    qx = (size - qr_side) // 2
    qy = mark_y + mark.height + 22
    # weißer Kreis-tauglicher Rahmen (abgerundet)
    draw.rounded_rectangle(
        (qx - pad, qy - pad, qx + qr_side + pad, qy + qr_side + pad),
        radius=36,
        fill=WHITE,
        outline=NAVY,
        width=7,
    )
    qr_img = make_qr(qr_side)
    img.paste(qr_img, (qx, qy), qr_img)

    below = qy + qr_side + pad + 18
    center_text(draw, "Bitte scannen", below, font(52))
    center_text(draw, "Please scan me", below + 58, font(30, bold=False))
    center_text(draw, "luckystaxiapp.de/scan.html", below + 100, font(26, bold=False))

    # Nochmal Kreis-Maske (alles außerhalb transparent)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=255,
    )
    out = Image.new("RGBA", (size, size), TRANSPARENT)
    out.paste(img, (0, 0), mask)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT, "PNG", optimize=True)
    out.save(OUT_V2, "PNG", optimize=True)
    out.save(OUT_ROUND, "PNG", optimize=True)
    make_qr(1200).save(OUT_QR_ONLY, "PNG", optimize=True)
    print(f"Wrote round sticker → {OUT_ROUND}")
    print(f"Also → {OUT}, {OUT_V2}")
    print(f"QR only → {OUT_QR_ONLY}")
    print(f"lead_bottom={lead_bb[3]} qr_top={qy - pad} gap={(qy - pad) - lead_bb[3]}")


if __name__ == "__main__":
    main()
