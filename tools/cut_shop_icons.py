"""Cut the v12.13 shop icons (generated 3x2 on a pure magenta key) into
assets/art/shop_v1/<name>.png; run tools/png_to_webp.py on that folder next.

Source: assets/concept/shop_icons_v1/shop_icons_raw.png
Run: python tools/cut_shop_icons.py
"""
import pathlib
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from cut_ui_kit import key_out_border  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/concept/shop_icons_v1/shop_icons_raw.png'
OUT = ROOT / 'assets/art/shop_v1'
NAMES = ['starter', 'fund', 'monthly', 'adpass', 'supporter', 'ad']
SIZE = 192


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SRC)
    cw, ch = sheet.width / 3, sheet.height / 2
    for i, name in enumerate(NAMES):
        c, r = i % 3, i // 3
        cell = sheet.crop((round(c * cw), round(r * ch),
                           round((c + 1) * cw), round((r + 1) * ch)))
        keyed = key_out_border(cell)
        # magenta enclosed by the art (inside the frame) is not reached from
        # the border: clear clearly-magenta pixels too
        rgb, px = cell.convert('RGB').load(), keyed.load()
        for y in range(keyed.height):
            for x in range(keyed.width):
                r_, g, b = rgb[x, y]
                if min(r_, b) - g > 120:
                    px[x, y] = (0, 0, 0, 0)
        box = keyed.split()[3].point(lambda a: 255 if a > 40 else 0).getbbox()
        piece = keyed.crop((max(0, box[0] - 3), max(0, box[1] - 3),
                            min(keyed.width, box[2] + 3),
                            min(keyed.height, box[3] + 3)))
        piece.thumbnail((SIZE, SIZE), Image.LANCZOS)
        piece.save(OUT / f'{name}.png')
        print(name, piece.size)


if __name__ == '__main__':
    main()
