#!/usr/bin/env python3
"""Draws Nullmere Online's icon: the launcher's lake, still, under a full moon.

    python3 Tools/icon/make-icon.py

Writes the layers of the Liquid Glass icon (Packaging/AppIcon.icon: the
night, the moon's image in the water, and the glass moon) and the classic
icon built from them (Packaging/AppIcon.png), with a preview beside this
script. The scene is the launcher's own, framed square around the moon:
its sky and water, its far shore of flat-topped mesas worked out as the
lake's shader works them (LakeShore), its stars cold and now and then warm,
and the water a black mirror, giving the moon and the stars back whole, as
far below the horizon as they stand above it. Everything is drawn here;
nothing is copied. Needs Pillow and NumPy. The art is original and
dedicated to the public domain (CC0), like the rest of Nullmere's art.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "Packaging", "AppIcon.icon", "Assets")
CLASSIC = os.path.join(ROOT, "Packaging", "AppIcon.png")
S = 1024
HORIZON = 548                      # the waterline, from the top
MOON = (512, 296, 90)              # centre and radius
IMAGE_Y = 2 * HORIZON - MOON[1]    # the moon's image: as far below as it stands above
# The launcher's scene runs from 0 at the left to its aspect at the right;
# the icon frames a square of it with the moon at its centre, as the moon
# stands in the launcher at 16:10.
SCENE_LEFT, SCENE_WIDTH = 0.3, 1.0

f32 = np.float32
rng = np.random.default_rng(20261029)


# The far shore, as LakeShore and the lake's shader work it, in single precision.
def fract(v):
    return (v - np.floor(v)).astype(f32)


def hash12(x, y):
    a = fract(x * f32(0.1137) + f32(0.4142))
    b = fract(y * f32(0.1459) + f32(0.7320))
    a = fract(a * f32(51.73) + b * b * f32(29.17))
    b = fract(b * f32(43.39) + a * a * f32(37.61))
    return fract(a * f32(19.07) + b * f32(61.13) + a * b * f32(7.31))


def noise(x, y):
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = (x - ix).astype(f32), (y - iy).astype(f32)
    ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hash12(ix, iy), hash12(ix + 1, iy)
    c, d = hash12(ix, iy + 1), hash12(ix + 1, iy + 1)
    return (a + (b - a) * ux) * (1 - uy) + (c + (d - c) * ux) * uy


def fbm(x, y):
    value, amplitude = np.zeros_like(x, dtype=f32), f32(0.5)
    for _ in range(4):
        value = value + amplitude * noise(x, y)
        x, y = x * f32(2.03) + f32(17.1), y * f32(2.03) + f32(9.3)
        amplitude = amplitude * f32(0.5)
    return value


def smoothstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mesas(x):
    n = fbm(x * f32(2.2) + f32(4.0), np.full_like(x, f32(11.0)))
    tops = smoothstep(0.50, 0.56, n) * 0.55 + smoothstep(0.60, 0.65, n) * 0.45
    body = 0.016 + 0.044 * tops
    wear = 0.0012 * noise(x * f32(55.0), np.full_like(x, f32(1.0)))
    mask = smoothstep(0.15, 0.55, noise(x * f32(0.9) + f32(19.0), np.full_like(x, f32(4.5))))
    return (body + wear) * mask


def bank(x):
    n = fbm(x * f32(3.1) + f32(18.75), np.full_like(x, f32(8.6)))
    return 0.0018 + 0.006 * smoothstep(0.35, 0.75, n) + 0.0007 * noise(x * f32(70.0), np.full_like(x, f32(5.0)))


def ridge(height, mirrored):
    """A mask of the shore, standing up from the waterline or mirrored down."""
    xs = (SCENE_LEFT + (np.arange(S, dtype=f32) + f32(0.5)) / f32(S) * f32(SCENE_WIDTH)).astype(f32)
    tops = height(xs) * S
    rows = np.arange(S)[:, None]
    if mirrored:
        mask = (rows >= HORIZON) & (rows < HORIZON + tops[None, :])
    else:
        mask = (rows < HORIZON) & (rows >= HORIZON - tops[None, :])
    image = Image.fromarray((mask * 255).astype(np.uint8), "L")
    return image.filter(ImageFilter.GaussianBlur(0.8))


def star_colour(seed):
    """Cold, or now and then warm, as the shader tints the stars."""
    w = seed * seed
    return np.array([0.76 + 0.24 * w, 0.85 + 0.07 * w, 1.0 - 0.18 * w])


def night():
    y = np.arange(S, dtype=float)[:, None]
    x = np.arange(S, dtype=float)[None, :]
    # The launcher's sky: black at the top, a cold grey glow at the horizon;
    # its water: the sky given back, darkening toward the near shore.
    zenith, sky_low = np.array([1.0, 1.5, 3.1]), np.array([15.3, 19.4, 26.5])
    water_high, water_low = np.array([12.8, 16.1, 22.4]), np.array([0.8, 1.0, 2.0])
    t = np.clip(y / HORIZON, 0, 1)[..., None]
    sky = zenith + (sky_low - zenith) * t ** 2.2
    w = np.clip((y - HORIZON) / (S - HORIZON), 0, 1)[..., None]
    water = water_high + (water_low - water_high) * w ** 0.6
    img = np.where((y < HORIZON)[..., None], sky, water) * np.ones((1, S, 1))

    # The moon's light about it in the sky, and about its image in the water,
    # layer on layer as the launcher's halo.
    mx, my, r = MOON
    moonlight = np.array([148, 173, 219])
    for centre, strength in ((my, 1.0), (IMAGE_Y, 0.62)):
        d = np.hypot(x - mx, y - centre) / r
        halo = 0.34 * np.exp(-(d - 1).clip(0) * 6.0) + 0.09 * np.exp(-d / 2.4) + 0.03 * np.exp(-d / 7.0)
        side = (y < HORIZON) if centre == my else (y >= HORIZON)
        img += moonlight * (strength * halo * side)[..., None]

    # Mist lying on the water at the horizon.
    mist = 0.04 * np.exp(-np.abs(y - HORIZON) / 26.0)
    img += np.array([140, 161, 194]) * mist[..., None]
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")

    # The stars, and the same stars given back by the still water.
    draw = ImageDraw.Draw(out, "RGBA")
    for _ in range(150):
        sx, sy = rng.uniform(0, S), rng.uniform(0, HORIZON - 70)
        brightness = rng.uniform(0.15, 1.0) ** 2.4
        warmth = rng.uniform(0, 1)
        if np.hypot(sx - mx, sy - my) < r * 1.9:
            continue
        radius = 0.8 + 1.7 * brightness
        colour = tuple(int(c) for c in np.clip(star_colour(warmth) * (150 + 105 * brightness), 0, 255))
        draw.ellipse([sx - radius, sy - radius, sx + radius, sy + radius], fill=colour + (int(255 * (0.45 + 0.55 * brightness)),))
        my_ = 2 * HORIZON - sy
        if my_ < S:
            draw.ellipse([sx - radius, my_ - radius, sx + radius, my_ + radius], fill=colour + (int(255 * 0.7 * (0.45 + 0.55 * brightness)),))

    # The far shore and the nearer bank, standing dark against the sky's
    # glow, and lying mirrored on the water, a little darker.
    for height, colour, image_colour in ((mesas, (8, 11, 16), (7, 9, 12)), (bank, (2, 3, 5), (2, 3, 4))):
        out.paste(Image.new("RGB", (S, S), colour), mask=ridge(height, mirrored=False))
        out.paste(Image.new("RGB", (S, S), image_colour), mask=ridge(height, mirrored=True))
    return out


def moon_face():
    """The full moon: pale, cold, darker at the rim, with its seas and grain."""
    mx, my, r = MOON
    size = 2 * r
    y, x = np.mgrid[0:size, 0:size].astype(float) + 0.5
    u, v = (x - r) / r, (y - r) / r
    d = np.hypot(u, v)
    limb = np.sqrt(np.clip(1 - d * d, 0, 1)) ** 0.22
    xs, ys = (u * 1.6 + 3.0).astype(f32), (v * 1.6 + 5.0).astype(f32)
    seas = smoothstep(0.40, 0.72, fbm(xs, ys))
    grain = noise((u * 30).astype(f32), (v * 30).astype(f32))
    tone = (0.97 * limb * (1 - 0.15 * seas) * (0.97 + 0.04 * grain))[..., None]
    rgb = np.array([0.93, 0.95, 0.98]) * 255 * tone
    big = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(big).ellipse([2, 2, size * 4 - 2, size * 4 - 2], fill=255)
    alpha = np.asarray(big.resize((size, size), Image.LANCZOS))[..., None]
    return Image.fromarray(np.concatenate([np.clip(rgb, 0, 255), alpha], axis=2).astype(np.uint8), "RGBA")


def moon_layer(face):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mx, my, r = MOON
    layer.alpha_composite(face, (mx - r, my - r))
    return layer


def reflection_layer(face):
    """The moon's image: the moon given back whole, a little dimmer, by the
    still water, as far below the horizon as the moon stands above it."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mx, _, r = MOON
    image = np.asarray(face.transpose(Image.FLIP_TOP_BOTTOM)).astype(float)
    image[..., :3] *= 0.74
    layer.alpha_composite(Image.fromarray(image.clip(0, 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.6)),
                          (mx - r, IMAGE_Y - r))
    return layer


def classic(scene):
    """The icon for places without Liquid Glass: the scene on macOS's
    rounded square, 824 px from (100, 100), with its soft shadow."""
    body, corner, at = 824, 185, 100
    art = scene.resize((body, body), Image.LANCZOS)
    big = Image.new("L", (body * 4, body * 4), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, body * 4 - 1, body * 4 - 1], radius=corner * 4, fill=255)
    mask = big.resize((body, body), Image.LANCZOS)
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow = Image.new("L", (S, S), 0)
    shadow.paste(mask, (at, at + 12))
    icon.paste(Image.new("RGBA", (S, S), (0, 0, 0, 120)), mask=shadow.filter(ImageFilter.GaussianBlur(18)))
    art.putalpha(mask)
    icon.alpha_composite(art, (at, at))
    return icon


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    face = moon_face()
    sky = night()
    moon, image = moon_layer(face), reflection_layer(face)
    sky.save(os.path.join(OUT, "night.png"))
    moon.save(os.path.join(OUT, "moon.png"))
    image.save(os.path.join(OUT, "reflection.png"))
    scene = sky.convert("RGBA")
    scene.alpha_composite(image)
    scene.alpha_composite(moon)
    scene.save(os.path.join(os.path.dirname(__file__), "preview.png"))
    classic(scene).save(CLASSIC)
    print("Wrote", OUT, "and", CLASSIC)
