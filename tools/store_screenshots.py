"""Phone screenshots for the Google Play listing (1080x1920) from the local
web build, in Korean and English.

Needs the web build served at http://localhost:5180 (preview server) and
Playwright: PYTHONPATH=D:/Programs/pylib python tools/store_screenshots.py
[--probe]. --probe saves every step to .local/store_probe/ for tuning taps.
"""
import pathlib
import sys
import time

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = 'http://localhost:5180/'
W, H, SCALE = 360, 640, 3  # 1080x1920
PROBE = '--probe' in sys.argv
OUT = ROOT / ('.local/store_probe' if PROBE else 'store/screenshots')

# taps in CSS pixels of the 360x640 layout
NAV_Y = 598
NAV = {'supply': 36, 'growth': 108, 'sortie': 180, 'challenge': 252, 'research': 324}
TABS_Y = 80
TABS = {'gear': 60, 'weapons': 180, 'pets': 300}


def run(lang: str) -> None:
    out = OUT / ('ko-KR' if lang == 'ko' else 'en-US')
    out.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as pw:
        browser = pw.chromium.launch(channel='chrome', headless=True)
        ctx = browser.new_context(
            viewport={'width': W, 'height': H},
            device_scale_factor=SCALE,
            is_mobile=True,
            has_touch=False,
        )
        ctx.add_init_script(
            "try{localStorage.setItem('flutter.shootingstar.language.v1',"
            f"'\"{lang}\"');}}catch(e){{}}"
        )
        page = ctx.new_page()
        step = [0]

        def shot(name: str) -> None:
            step[0] += 1
            page.screenshot(path=str(out / f'{name}.png'))
            print('saved', out / f'{name}.png')

        def tap(x: float, y: float, wait: float = 1.2) -> None:
            page.mouse.click(x, y)
            time.sleep(wait)

        page.goto(URL)
        time.sleep(12)
        if PROBE:
            shot('p01_start')
        # first launch shows the prologue: its skip button (bottom left)
        tap(70, 598, 2.5)
        if PROBE:
            shot('p02_after_prologue')
        shot('01_lobby')
        tap(NAV['growth'], NAV_Y, 2.0)
        shot('03_gear')
        tap(TABS['weapons'], TABS_Y, 1.5)
        shot('04_weapons')
        tap(TABS['pets'], TABS_Y, 1.5)
        shot('05_pets')
        tap(NAV['sortie'], NAV_Y, 2.0)
        # launch: the big yellow button above the navigation; the first
        # sortie opens the flight guide, closed by its yellow button
        tap(W / 2, 520, 2.0)
        if PROBE:
            shot('p03_guide')
        tap(W / 2, 510, 1.0)
        time.sleep(9)
        # fly with a held finger so the run actually plays out
        page.mouse.move(W / 2, 470)
        page.mouse.down()
        for i in range(70):
            page.mouse.move(W / 2 + 70 * (1 if (i // 6) % 2 else -1), 470, steps=6)
            time.sleep(.25)
        shot('02_battle')
        page.mouse.up()
        browser.close()


if __name__ == '__main__':
    for lang in (['ko'] if PROBE else ['ko', 'en']):
        run(lang)
