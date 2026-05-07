#!/usr/bin/env python3
"""
Trim a uniform light/white frame from a square app-icon master, then composite
the artwork onto a full-bleed 1024×1024 canvas (default: black).

Depends: Pillow only (`pip install Pillow`).

Usage:
  python3 Scripts/fix_app_icon_white_border.py input.png output.png
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def trim_light_border(
    image: Image.Image,
    *,
    rgb_threshold: int = 242,
    margin_px: int = 2,
) -> Image.Image:
    """Return a crop that removes pixels that read as white / light-gray frame."""
    rgba = image.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    def is_background(x: int, y: int) -> bool:
        r, g, b, _ = px[x, y]
        return r > rgb_threshold and g > rgb_threshold and b > rgb_threshold

    min_x, min_y = w, h
    max_x, max_y = 0, 0
    found = False
    for y in range(h):
        for x in range(w):
            if is_background(x, y):
                continue
            found = True
            if x < min_x:
                min_x = x
            if y < min_y:
                min_y = y
            if x > max_x:
                max_x = x
            if y > max_y:
                max_y = y

    if not found:
        return rgba

    x0 = max(0, min_x - margin_px)
    y0 = max(0, min_y - margin_px)
    x1 = min(w - 1, max_x + margin_px)
    y1 = min(h - 1, max_y + margin_px)
    return rgba.crop((x0, y0, x1 + 1, y1 + 1))


def letterbox_to_square(
    image: Image.Image,
    side: int,
    *,
    fill: tuple[int, int, int, int],
    scale_fill: float = 0.98,
) -> Image.Image:
    w, h = image.size
    scale = min(side / w, side / h) * scale_fill
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    resized = image.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (side, side), fill)
    ox = (side - nw) // 2
    oy = (side - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    return canvas


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: fix_app_icon_white_border.py input.png output.png", file=sys.stderr)
        sys.exit(2)
    inp = Path(sys.argv[1])
    outp = Path(sys.argv[2])
    im = Image.open(inp)
    trimmed = trim_light_border(im)
    out = letterbox_to_square(trimmed, 1024, fill=(0, 0, 0, 255), scale_fill=0.98)
    out.convert("RGB").save(outp, "PNG")


if __name__ == "__main__":
    main()
