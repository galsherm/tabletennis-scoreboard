# Store screenshots

Builds the captioned Google Play phone screenshots from real device
captures. Nothing here is uploaded anywhere; the output is a folder of
PNGs to upload by hand.

```
tools/store_screenshots/
  make.py           composes the final images
  captions.json     one caption per shot, per listing language
  capture_s23.py    optional: takes the raw captures on a Samsung S23
store/
  raw/<locale>/         raw 1080x2340 device captures (input)
  screenshots/<locale>/ final 1080x1920 images (output)
  screenshots/contact_sheet.png   all finals in one grid, for review
```

Locales are `en-US`, `de-DE`, `fr-FR`. Each has six shots:
`01_setup`, `02_singles`, `03_serve`, `04_doubles`, `05_language`,
`06_help`.

## Rebuild the final images

Needs Python 3 and Pillow (`pip install pillow`).

```
python tools/store_screenshots/make.py
```

This regenerates everything under `store/screenshots/` from
`store/raw/` and `captions.json`. To change a caption, edit
`captions.json` and run it again. A caption is shown at 60px and
shrinks (down to 44px) if it would not fit on two lines; if it still
does not fit, the script stops and asks for a shorter one rather than
cutting words.

The layout uses the app's own palette and its bundled Barlow font from
`assets/fonts/`, so nothing is downloaded.

## Retake the raw captures

Captures are real screenshots (`adb exec-out screencap -p`) of a
profile build. Demo data: singles Anna vs Ben; doubles Anna and Ben vs
Chris and Dana.

1. `flutter run --profile` on the phone, Dark theme, setup screen.
2. For each language (choose it in the app's Language menu), save into
   `store/raw/<locale>/`:
   - `05_language.png` - the Language menu open
   - `01_setup.png` - setup screen after the toss, Anna serving first
   - `02_singles.png` - singles at 7-5, server on the left
   - `03_serve.png` - singles at 10-9
   - `06_help.png` - the top of the "How to use" page
   - `04_doubles.png` - doubles at 8-6
3. Run `make.py`.

On a Samsung S23 (1080x2340) `capture_s23.py` does step 2 by tapping
fixed coordinates; see the notes at the top of that file. It will not
work on another screen size or after the setup screen's layout changes.

### Status bar

Android's SystemUI demo mode gives a clean status bar (9:41, full
battery, no notification icons):

```
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
# ... capture ...
adb shell am broadcast -a com.android.systemui.demo -e command exit
adb shell settings put global sysui_demo_allowed 0
```

Samsung's One UI ignores these broadcasts (checked on the S23, One UI
6.1), so the committed raw captures still contain that phone's real
status bar. `make.py` therefore paints the status bar's contents out
of every capture before composing: the strip becomes the app's own
background, nothing is drawn in its place, and the app's accent top
bar and corner glow are kept where they run under it. The strip's
height is `RAW_STATUS_BAR` in `make.py` (81px, the S23's); change it
for captures from another device, or set it to 0 to leave captures
untouched (for example ones taken in demo mode).

## Google Play limits

Phone screenshots: 2 to 8 per language, PNG or JPEG, each side between
320px and 3840px. The finals are 1080x1920 (9:16), 24-bit PNG without
transparency.
