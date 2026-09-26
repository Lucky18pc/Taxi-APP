#!/usr/bin/env python3
"""Luckys-Taxi-Aufkleber: Überschrift oben in eigener Zone, QR klar darunter."""
from __future__ import annotations

import math
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "web" / "luckys-taxi-aufkleber-qr.png"
OUT_V2 = ROOT / "web" / "luckys-taxi-aufkleber-v2.png"
OUT_QR_ONLY = ROOT / "web" / "luckys-taxi-qr-scan.png"
SCAN_URL = "https://luckystaxiapp.de/scan.html"

YELLOW = (255, 204, 0)
YELLOW_LIGHT = (255, 236, 140)
YELLOW_DEEP = (245, 188, 0)
NAVY = (12, 28, 52)
GOLD = (218, 165, 32)
GOLD_EDGE = (150, 105, 8)
WHITE = (255, 255, 255)


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
    draw.text(((canvas - tw) / 2, y), text, font=fnt, fill=fill)
    # absolute bbox where text was drawn
    return draw.textbbox(((canvas - tw) / 2, y), text, font=fnt)


def brand_mark(size=240) -> Image.Image:
    mark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(mark)
    cx = cy = size / 2
    draw_star(d, cx, cy, size * 0.48, NAVY)
    lines = ["Lucky's", "Taxi", "App"]
    f = font(max(24, int(size * 0.135)))
    gaps = []
    for line in lines:
        bb = d.textbbox((0, 0), line, font=f)
        gaps.append((line, bb[2] - bb[0], bb[3] - bb[1]))
    total_h = sum(h for _, _, h in gaps) + 5 * (len(lines) - 1)
    y = cy - total_h / 2 + 4
    for line, tw, th in gaps:
        d.text((cx - tw / 2, y), line, font=f, fill=YELLOW)
        y += th + 5
    return mark


def make_qr(side: int) -> Image.Image:
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=16, border=3)
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

    # === OBERE ZONE (helleres Band): Sterne + Überschrift — weit weg vom QR ===
    header_bottom = 320
    draw.rounded_rectangle((48, 48, size - 48, header_bottom), radius=40, fill=YELLOW_LIGHT, outline=NAVY, width=6)

    star_y = 95
    gap = 88
    start_x = size / 2 - 2 * gap
    for i in range(5):
        draw_star(draw, start_x + i * gap, star_y, 32, GOLD, outline=GOLD_EDGE, width=3)

    center_text(draw, "5 Sterne · Sehr gut", 140, font(36))

    # GROSSE Überschrift im hellen Band — kann nicht vom QR bedeckt werden
    lead_bb = center_text(draw, "Taxi online bestellen", 210, font(56))
    assert lead_bb[3] < header_bottom - 20, f"Lead zu tief: {lead_bb}"

    # Markenstern unter dem Band
    mark = brand_mark(230)
    mark_y = header_bottom + 20
    img.paste(mark, ((size - mark.width) // 2, mark_y), mark)

    # QR deutlich darunter
    qr_side = 480
    pad = 24
    qx = (size - qr_side) // 2
    qy = mark_y + mark.height + 36 + pad
    assert qy - pad > lead_bb[3] + 80, "QR zu nah an Überschrift"

    draw.rounded_rectangle(
        (qx - pad, qy - pad, qx + qr_side + pad, qy + qr_side + pad),
        radius=28,
        fill=WHITE,
        outline=NAVY,
        width=8,
    )
    img.paste(make_qr(qr_side), (qx, qy))

    below = qy + qr_side + pad + 22
    center_text(draw, "Bitte scannen", below, font(64))
    center_text(draw, "Please scan me", below + 68, font(34, bold=False))
    center_text(draw, "luckystaxiapp.de/scan.html", below + 118, font(30, bold=False))

    print(
        f"Layout: lead_bottom={lead_bb[3]} header_band={header_bottom} "
        f"mark_y={mark_y} qr_frame_top={qy - pad} gap_lead_to_qr={(qy - pad) - lead_bb[3]}"
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG", optimize=True)
    img.save(OUT_V2, "PNG", optimize=True)
    make_qr(1200).save(OUT_QR_ONLY, "PNG", optimize=True)
    print(f"Wrote {OUT}")
    print(f"Wrote {OUT_V2}")
    print(f"Wrote {OUT_QR_ONLY}")


if __name__ == "__main__":
    main()
