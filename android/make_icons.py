#!/usr/bin/env python3
"""Generate the Android launcher icon from the game sprites.

A horizontal demon tile (one big eye per half) in the middle of a domino chain,
with regular horizontal tiles connecting on both sides and running off the
icon edges, on the game's maroon background.

Outputs into android/res/, which CI copies over love-android's app/src/main/res/:
  drawable-<dpi>/love.png            legacy square icon (pre Android 8)
  drawable-<dpi>/love_foreground.png adaptive icon foreground (108dp canvas)
  drawable-anydpi-v26/love.xml       adaptive icon: maroon background + foreground
  values/love_icon.xml               background colour

Usage: python3 android/make_icons.py   (needs Pillow)
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(HERE, "..", "sprites")
RES = os.path.join(HERE, "res")

MAROON = (0x3E, 0x2D, 0x35, 255)   # UI.Colors.BACKGROUND, the game's main background
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# Adaptive canvas is 108dp; launchers show roughly the central 72dp (18..90).
CANVAS_DP, VISIBLE_DP = 108, 72
PX_DP = 0.9          # size of one sprite pixel in dp (demon tile ~58dp wide)
TILE_W, TILE_H = 64, 32
OVERLAP = 2          # neighbouring tiles share their 2px outline, like a chain


def sprite(*path):
    return Image.open(os.path.join(SPRITES, *path)).convert("RGBA")


def demon_tile():
    """Demon tile with one big eye (the title screen's) per half, centred on
    each half's face like drawDemonDomino places pips: 1/4 and 3/4 of the
    width, 2px above the tile centre."""
    tile = sprite("demon_tiles", "tilted_demon_tile.png")
    eye = sprite("demon_tiles", "big_eye_animation", "base.png")
    for cx in (TILE_W // 4, TILE_W * 3 // 4):
        tile.alpha_composite(eye, (cx - eye.width // 2, TILE_H // 2 - 2 - eye.height // 2))
    return tile


def chain():
    """[6|1][demon 1|1][1|6] at native sprite resolution."""
    right = sprite("titled_tiles", "16t.png")
    left = right.transpose(Image.FLIP_LEFT_RIGHT)   # 6|1
    step = TILE_W - OVERLAP
    img = Image.new("RGBA", (TILE_W + 2 * step, TILE_H), (0, 0, 0, 0))
    img.alpha_composite(left, (0, 0))
    img.alpha_composite(right, (2 * step, 0))
    img.alpha_composite(demon_tile(), (step, 0))     # on top of the shared outlines
    return img


def render(canvas_px, d, background):
    # Upscale on the pixel grid first, then resample down to the exact size, so
    # the pixel art stays crisp at non-integer scales.
    art = chain()
    art = art.resize((art.width * 8, art.height * 8), Image.NEAREST)
    art = art.resize((round(art.width / 8 * PX_DP * d), round(art.height / 8 * PX_DP * d)),
                     Image.LANCZOS)
    img = Image.new("RGBA", (canvas_px, canvas_px), background)
    x = (canvas_px - art.width) // 2
    y = (canvas_px - art.height) // 2
    img.alpha_composite(art, (x, y))       # alpha_composite clips at the edges
    return img


def main():
    for name, d in DENSITIES.items():
        folder = os.path.join(RES, "drawable-" + name)
        os.makedirs(folder, exist_ok=True)
        size = round(CANVAS_DP * d)
        render(size, d, (0, 0, 0, 0)).save(os.path.join(folder, "love_foreground.png"))
        # Legacy icon = the visible 72dp window on maroon, scaled to 48dp.
        full = render(size, d, MAROON)
        m = round((CANVAS_DP - VISIBLE_DP) / 2 * d)
        legacy = full.crop((m, m, full.width - m, full.height - m))
        legacy = legacy.resize((round(48 * d), round(48 * d)), Image.LANCZOS)
        legacy.save(os.path.join(folder, "love.png"))

    os.makedirs(os.path.join(RES, "drawable-anydpi-v26"), exist_ok=True)
    with open(os.path.join(RES, "drawable-anydpi-v26", "love.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/love_icon_background"/>\n'
                '    <foreground android:drawable="@drawable/love_foreground"/>\n'
                '</adaptive-icon>\n')
    os.makedirs(os.path.join(RES, "values"), exist_ok=True)
    with open(os.path.join(RES, "values", "love_icon.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="love_icon_background">#%02X%02X%02X</color>\n'
                '</resources>\n' % MAROON[:3])


if __name__ == "__main__":
    main()
