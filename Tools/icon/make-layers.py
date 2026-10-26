#!/usr/bin/env python3
"""Draws the layers of Nullmere's Liquid Glass app icon (Packaging/AppIcon.icon).

    python3 Tools/icon/make-layers.py

The moon's face is taken from Packaging/AppIcon.png, the classic icon; the
night, the shore and the water are drawn here. Each layer is a full-bleed
1024 px square: macOS masks it to the icon's shape and lights the glass.
Needs Pillow and NumPy. The art is original and dedicated to the public
domain (CC0), like the rest of Nullmere's art.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SOURCE = os.path.join(ROOT, "Packaging", "AppIcon.png")
OUT = os.path.join(ROOT, "Packaging", "AppIcon.icon", "Assets")
S = 1024
# The classic icon's artwork spans 824 px from (100, 100).
TO_FULL = S / 824.0
HORIZON = 0.535
MOON = (512, 296, 90)
REFLECTION_Y = 842

rng = np.random.default_rng(20261024)
y = np.linspace(0, 1, S)[:, None]
x = np.linspace(0, 1, S)[None, :]


def night():
    sky_top = np.array([5, 7, 13], float)
    sky_low = np.array([16, 19, 30], float)
    water_top = np.array([9, 11, 18], float)
    water_low = np.array([3, 4, 8], float)
    t = np.clip(y / HORIZON, 0, 1)
    sky = sky_top + (sky_low - sky_top) * t[..., None] ** 1.6
    w = np.clip((y - HORIZON) / (1 - HORIZON), 0, 1)
    water = water_top + (water_low - water_top) * w[..., None] ** 0.7
    img = np.where((y < HORIZON)[..., None], sky, water) * np.ones((1, S, 1))
    # A soft glow around the moon, in the sky and on the water.
    mx, my, _ = MOON
    d = np.hypot(x * S - mx, y * S - my)
    img += np.array([40, 46, 62])[None, None, :] * np.exp(-d / 210.0)[..., None] * (y < HORIZON)[..., None]
    dr = np.hypot((x * S - mx) * 1.0, (y * S - REFLECTION_Y) * 1.6)
    img += np.array([18, 21, 30])[None, None, :] * np.exp(-dr / 170.0)[..., None] * (y >= HORIZON)[..., None]
    # The moon's path on the water: faint, broken lines.
    path = np.exp(-((x * S - mx) / 46.0) ** 2) * (y >= HORIZON + 0.02) * (y < 0.98)
    lines = 0.75 + 0.25 * np.sin(y * S * 0.21 + np.sin(y * S * 0.05) * 3)
    fade = np.exp(-np.abs(y * S - REFLECTION_Y) / 260.0)
    img += np.array([16, 18, 26])[None, None, :] * (path * lines * fade)[..., None]
    img = np.clip(img, 0, 255)
    out = Image.fromarray(img.astype(np.uint8), "RGB")

    # Stars above, and their reflections below, a little dimmer.
    draw = ImageDraw.Draw(out, "RGBA")
    for _ in range(115):
        sx, sy = rng.uniform(0, S), rng.uniform(0, S * HORIZON - 30)
        if np.hypot(sx - mx, sy - my) < 150:
            continue
        b = rng.uniform(0.2, 1.0) ** 2.6
        r = 0.9 + 1.6 * b
        c = int(120 + 135 * b)
        draw.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(c, c, min(255, c + 18), int(255 * (0.4 + 0.6 * b))))
        ry = 2 * S * HORIZON - sy + 18
        if ry < S and b > 0.2:
            draw.ellipse([sx - r, ry - r * 0.8, sx + r, ry + r * 0.8], fill=(c, c, min(255, c + 18), int(110 * b)))

    # The far shore: low, dark hills along the horizon.
    hy = S * HORIZON
    hills = Image.new("L", (S, S), 0)
    hd = ImageDraw.Draw(hills)
    points = [(0, hy)]
    for i in range(0, S + 16, 16):
        h = 10 + 9 * np.sin(i * 0.011) + 7 * np.sin(i * 0.031 + 1) + (18 if 540 < i < 940 else 0) * np.sin((i - 540) / 400 * np.pi)
        points.append((i, hy - max(h, 4)))
    points += [(S, hy + 10), (0, hy + 10)]
    hd.polygon(points, fill=255)
    hills = hills.filter(ImageFilter.GaussianBlur(1.2))
    out.paste(Image.new("RGB", (S, S), (11, 13, 21)), mask=hills)
    # Their reflection, faint and soft.
    mirror = hills.transpose(Image.FLIP_TOP_BOTTOM).transform((S, S), Image.AFFINE, (1, 0, 0, 0, 1, S - 2 * hy - 4))
    out.paste(Image.new("RGB", (S, S), (7, 8, 14)), mask=mirror.point(lambda v: v * 0.7).filter(ImageFilter.GaussianBlur(2.5)))
    return out


def moon_face():
    src = Image.open(SOURCE).convert("RGBA")
    # The moon in the classic icon: centre (512, 338), radius about 72.
    cx, cy, r = 512, 338, 74
    crop = src.crop((cx - r, cy - r, cx + r, cy + r))
    size = int(2 * MOON[2])
    crop = crop.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse([4, 4, size * 4 - 4, size * 4 - 4], fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    crop.putalpha(mask)
    return crop


def moon_layer(face):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mx, my, r = MOON
    layer.alpha_composite(face, (mx - r, my - r))
    return layer


def reflection_layer(face):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mx, _, r = MOON
    mirrored = face.transpose(Image.FLIP_TOP_BOTTOM)
    rgb = np.asarray(mirrored).astype(float)
    rgb[..., :3] *= 0.72
    rgb[..., 3] *= 0.9
    # The still water barely breaks it: a few thin dark lines.
    rows = np.arange(rgb.shape[0])[:, None]
    rgb[..., 3] *= np.where((rows % 37) < 1, 0.82, 1.0)
    mirrored = Image.fromarray(rgb.clip(0, 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.8))
    layer.alpha_composite(mirrored, (mx - r, REFLECTION_Y - r))
    return layer


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    face = moon_face()
    night().save(os.path.join(OUT, "night.png"))
    moon_layer(face).save(os.path.join(OUT, "moon.png"))
    reflection_layer(face).save(os.path.join(OUT, "reflection.png"))
    preview = night().convert("RGBA")
    preview.alpha_composite(reflection_layer(face))
    preview.alpha_composite(moon_layer(face))
    preview.save(os.path.join(os.path.dirname(__file__), "preview.png"))
    print("Wrote", OUT)
