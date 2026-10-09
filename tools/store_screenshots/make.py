"""Composes the Google Play phone screenshots.

Reads the raw device captures in store/raw/<locale>/ and the captions
in captions.json (next to this script), and writes one captioned
1080x1920 PNG per shot to store/screenshots/<locale>/, plus a contact
sheet of all of them. Re-runnable: every output is rebuilt from scratch.

    python tools/store_screenshots/make.py

Needs Pillow (pip install pillow). Uses the Barlow font bundled with the
app, so nothing is downloaded. See README.md in this folder.
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
RAW_DIR = REPO / "store" / "raw"
OUT_DIR = REPO / "store" / "screenshots"
FONT_PATH = REPO / "assets" / "fonts" / "Barlow-SemiBold.ttf"
CAPTIONS_PATH = HERE / "captions.json"

# Output: 9:16, inside Google Play's 320-3840px per side.
WIDTH, HEIGHT = 1080, 1920

# The app's "Arena" palette (lib/theme/app_theme.dart, AppPalette.dark).
BACKGROUND = (0x07, 0x09, 0x0D)
ACCENT = (0xFF, 0x8A, 0x34)
TEXT = (0xF5, 0xF7, 0xFA)
BORDER = (0x23, 0x2A, 0x35)

# The app draws its top bar 4dp tall, which is 12px on the 3x phone the
# captures come from; the same 12px here keeps the two in proportion.
TOP_BAR = 12
GLOW_RADIUS = 1150
GLOW_ALPHA = 0.28

SIDE_MARGIN = 72
CAPTION_TOP = 92
CAPTION_SIZE = 60
CAPTION_MIN_SIZE = 44
CAPTION_MAX_LINES = 2
CAPTION_LINE_HEIGHT = 1.18

# The screenshot sits below a caption area sized for two lines at the
# full caption size, so it is in the same place on every image.
SHOT_TOP = 292
SHOT_BOTTOM_MARGIN = 64
SHOT_RADIUS = 48
SHOT_BORDER = 2
SHADOW_OFFSET = 26
SHADOW_BLUR = 34
SHADOW_ALPHA = 150

SHEET_THUMB = (270, 480)
SHEET_GAP = 16


def backdrop():
    """The Arena background: near-black, top-right glow, accent top bar."""
    image = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)

    # The glow's opacity: GLOW_ALPHA at the top-right corner, falling
    # off linearly to nothing at GLOW_RADIUS. Drawn small, then enlarged.
    n = 128
    falloff = Image.new("L", (2 * n, 2 * n))
    falloff.putdata(
        [
            int(255 * GLOW_ALPHA * max(0.0, 1 - math.hypot(x - n, y - n) / n))
            for y in range(2 * n)
            for x in range(2 * n)
        ]
    )
    falloff = falloff.resize((GLOW_RADIUS * 2, GLOW_RADIUS * 2), Image.BICUBIC)
    mask = Image.new("L", (WIDTH, HEIGHT), 0)
    mask.paste(falloff, (WIDTH - GLOW_RADIUS, -GLOW_RADIUS))
    image.paste(Image.new("RGB", (WIDTH, HEIGHT), ACCENT), (0, 0), mask)

    ImageDraw.Draw(image).rectangle((0, 0, WIDTH, TOP_BAR - 1), fill=ACCENT)
    return image


def wrap(draw, text, font, max_width):
    """Greedy word wrap; never splits a word."""
    lines, current = [], ""
    for word in text.split():
        candidate = f"{current} {word}".strip()
        if current and draw.textlength(candidate, font=font) > max_width:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


def fit_caption(draw, text):
    """The largest size at which the caption fits its lines and width."""
    max_width = WIDTH - 2 * SIDE_MARGIN
    for size in range(CAPTION_SIZE, CAPTION_MIN_SIZE - 1, -2):
        font = ImageFont.truetype(str(FONT_PATH), size)
        lines = wrap(draw, text, font, max_width)
        widest = max(draw.textlength(line, font=font) for line in lines)
        if len(lines) <= CAPTION_MAX_LINES and widest <= max_width:
            return font, lines
    raise SystemExit(
        f"Caption does not fit in {CAPTION_MAX_LINES} lines even at "
        f"{CAPTION_MIN_SIZE}px - shorten it: {text!r}"
    )


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def compose(raw_path, caption):
    image = backdrop()
    draw = ImageDraw.Draw(image)

    font, lines = fit_caption(draw, caption)
    line_height = round(font.size * CAPTION_LINE_HEIGHT)
    for index, line in enumerate(lines):
        draw.text((SIDE_MARGIN, CAPTION_TOP + index * line_height), line, font=font, fill=TEXT)

    shot = Image.open(raw_path).convert("RGB")
    box_w = WIDTH - 2 * SIDE_MARGIN
    box_h = HEIGHT - SHOT_TOP - SHOT_BOTTOM_MARGIN
    scale = min(box_w / shot.width, box_h / shot.height)
    size = (round(shot.width * scale), round(shot.height * scale))
    shot = shot.resize(size, Image.LANCZOS)
    left = (WIDTH - size[0]) // 2
    top = SHOT_TOP

    mask = rounded_mask(size, SHOT_RADIUS)

    shadow = Image.new("L", (WIDTH, HEIGHT), 0)
    shadow.paste(mask.point(lambda v: v * SHADOW_ALPHA // 255), (left, top + SHADOW_OFFSET))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    image.paste(Image.new("RGB", (WIDTH, HEIGHT), (0, 0, 0)), (0, 0), shadow)

    image.paste(shot, (left, top), mask)
    ImageDraw.Draw(image).rounded_rectangle(
        (left, top, left + size[0] - 1, top + size[1] - 1),
        SHOT_RADIUS,
        outline=BORDER,
        width=SHOT_BORDER,
    )
    return image


def contact_sheet(finals):
    """All finals in a grid: one row per locale, one column per shot."""
    rows = len(finals)
    cols = max(len(row) for row in finals.values())
    tw, th = SHEET_THUMB
    sheet = Image.new(
        "RGB",
        (SHEET_GAP + cols * (tw + SHEET_GAP), SHEET_GAP + rows * (th + SHEET_GAP)),
        (0x1B, 0x20, 0x28),
    )
    for row, images in enumerate(finals.values()):
        for col, image in enumerate(images):
            sheet.paste(
                image.resize(SHEET_THUMB, Image.LANCZOS),
                (SHEET_GAP + col * (tw + SHEET_GAP), SHEET_GAP + row * (th + SHEET_GAP)),
            )
    return sheet


def main():
    captions = json.loads(CAPTIONS_PATH.read_text(encoding="utf-8"))
    missing = [
        str((RAW_DIR / locale / f"{shot['file']}.png").relative_to(REPO))
        for locale, shots in captions.items()
        for shot in shots
        if not (RAW_DIR / locale / f"{shot['file']}.png").exists()
    ]
    if missing:
        sys.exit("Missing raw captures:\n  " + "\n  ".join(missing))

    finals = {}
    for locale, shots in captions.items():
        if not 2 <= len(shots) <= 8:
            sys.exit(f"{locale}: Google Play takes 2-8 phone screenshots, got {len(shots)}")
        out_dir = OUT_DIR / locale
        out_dir.mkdir(parents=True, exist_ok=True)
        for stale in out_dir.glob("*.png"):
            stale.unlink()
        finals[locale] = []
        for shot in shots:
            image = compose(RAW_DIR / locale / f"{shot['file']}.png", shot["caption"])
            out_path = out_dir / f"{shot['file']}.png"
            image.save(out_path, optimize=True)
            finals[locale].append(image)
            print(f"{out_path.relative_to(REPO)}  {out_path.stat().st_size // 1024} KB")

    sheet_path = OUT_DIR / "contact_sheet.png"
    contact_sheet(finals).save(sheet_path, optimize=True)
    print(sheet_path.relative_to(REPO))


if __name__ == "__main__":
    main()
