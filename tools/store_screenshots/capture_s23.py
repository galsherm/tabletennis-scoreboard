"""Captures the raw store screenshots from a Samsung S23 over adb.

Drives the app by tapping fixed screen coordinates, so it only works on
a 1080x2340 screen at 480dpi (the S23) with the current setup-screen
layout - on any other device, capture by hand as README.md describes.

Before running: install a profile build (`flutter run --profile`), open
the app on the setup screen in Dark theme with the language set to
Automatic on a device whose language resolves to English, Singles
selected, default names, no toss yet.

    python tools/store_screenshots/capture_s23.py [SERIAL]

Writes store/raw/<locale>/01_setup.png ... 06_help.png. It changes no
phone settings; it leaves the app on the setup screen, back on Automatic.
"""

import os
import shutil
import subprocess
import sys
import time
from io import BytesIO
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent.parent
RAW_DIR = REPO / "store" / "raw"

SERIAL = sys.argv[1] if len(sys.argv) > 1 else None
ADB = shutil.which("adb") or str(
    Path(os.environ.get("LOCALAPPDATA", "")) / "Android/Sdk/platform-tools/adb.exe"
)

# Screen coordinates in physical pixels (1080x2340).
MENU = (84, 164)
MENU_LANGUAGE = (140, 480)
MENU_HELP = (250, 627)
LANGUAGE_OPTION = {"en-US": (730, 480), "de-DE": (730, 768), "fr-FR": (730, 912)}
OUTSIDE_MENU = (540, 2120)
MODE_SINGLES = (300, 567)
MODE_DOUBLES = (780, 567)
SINGLES_NAMES = {(231, 774): "Anna", (714, 774): "Ben"}
DOUBLES_NAMES = {(699, 837): "Chris", (699, 921): "Dana"}
COIN_BEFORE_TOSS = (540, 1590)
SINGLES_COIN = (540, 1482)
SINGLES_START = (540, 1800)
DOUBLES_START = (540, 1932)
LEFT, RIGHT = (270, 1300), (810, 1300)
# Just under the scoreboard's app bar: the serving half's accent bar.
SERVE_BAR_LEFT, SERVE_BAR_RIGHT = (200, 253), (880, 253)

# Rallies that read like a real game. L/R = a point for the left/right side.
TO_7_5 = "LRLLRLRRLLRL"
ON_TO_10_9 = "RLRLRLR"
DOUBLES_8_6 = "LLRLRRLLRLRLRL"


def adb(*args, capture=False):
    command = [ADB] + (["-s", SERIAL] if SERIAL else []) + list(args)
    result = subprocess.run(command, check=True, capture_output=True)
    return result.stdout if capture else None


def tap(point, pause=1.2):
    adb("shell", "input", "tap", str(point[0]), str(point[1]))
    time.sleep(pause)


def back(pause=2.0):
    adb("shell", "input", "keyevent", "4")
    time.sleep(pause)


def screenshot():
    return Image.open(BytesIO(adb("exec-out", "screencap", "-p", capture=True))).convert("RGB")


def save(locale, name):
    path = RAW_DIR / locale / f"{name}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    screenshot().save(path, optimize=True)
    print(path.relative_to(REPO))


def rename(point, name):
    tap(point)
    adb("shell", "input", "text", name)
    adb("shell", "input", "keyevent", "66")
    time.sleep(1.5)


def play(points):
    for side in points:
        tap(LEFT if side == "L" else RIGHT, pause=0.5)
    time.sleep(1.5)


def is_accent(pixel):
    r, g, b = pixel
    return r > 200 and 90 < g < 180 and b < 110


def left_side_serves():
    shot = screenshot()
    return is_accent(shot.getpixel(SERVE_BAR_LEFT)) and not is_accent(
        shot.getpixel(SERVE_BAR_RIGHT)
    )


def open_language_menu():
    tap(MENU)
    tap(MENU_LANGUAGE)


def prepare():
    """Names in, and a toss that Anna (left side) won."""
    for point, name in SINGLES_NAMES.items():
        rename(point, name)
    tap(MODE_DOUBLES)
    for point, name in DOUBLES_NAMES.items():
        rename(point, name)
    tap(MODE_SINGLES)

    # The toss is random: toss, look at the scoreboard, and come back to
    # toss again until the left side serves first.
    coin = COIN_BEFORE_TOSS
    for _ in range(12):
        tap(coin, pause=2.5)
        coin = SINGLES_COIN
        tap(SINGLES_START, pause=4.5)
        serves_left = left_side_serves()
        back()
        if serves_left:
            return
    sys.exit("The toss never came up for the left side - try again.")


def capture(locale):
    open_language_menu()
    tap(LANGUAGE_OPTION[locale], pause=2.0)

    open_language_menu()
    save(locale, "05_language")
    tap(OUTSIDE_MENU, pause=1.5)

    save(locale, "01_setup")

    tap(SINGLES_START, pause=4.5)
    play(TO_7_5)
    save(locale, "02_singles")
    play(ON_TO_10_9)
    save(locale, "03_serve")
    back()

    tap(MENU)
    tap(MENU_HELP, pause=2.5)
    save(locale, "06_help")
    back()

    tap(MODE_DOUBLES)
    tap(DOUBLES_START, pause=4.5)
    play(DOUBLES_8_6)
    save(locale, "04_doubles")
    back()
    tap(MODE_SINGLES)


def main():
    prepare()
    for locale in LANGUAGE_OPTION:
        capture(locale)
    # Back to Automatic.
    open_language_menu()
    tap(LANGUAGE_OPTION["en-US"], pause=2.0)


if __name__ == "__main__":
    main()
