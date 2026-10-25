"""Cut the v12.12 action button icons (generated 4x3 on a pure magenta key)
into assets/art/ui_v13/act_<name>.png; run tools/png_to_webp.py on that
folder next.

Source: assets/concept/action_icons_v1/action_icons_raw.png
Run: python tools/cut_action_icons.py
"""
import pathlib
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from cut_ui_kit import key_out_border  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/concept/action_icons_v1/action_icons_raw.png'
OUT = ROOT / 'assets/art/ui_v13'
NAMES = [
    'check', 'cross', 'upgrade', 'lock',
    'unlock', 'dismantle', 'launch', 'helpers',
    'feed', 'promote', 'heart', None,  # the gear cog is not used
]
SIZE = 128


def main() -> None:
    sheet = Image.open(SRC)
    cw, ch = sheet.width / 4, sheet.height / 3
    for i, name in enumerate(NAMES):
        if name is None:
            continue
        c, r = i % 4, i // 4
        cell = sheet.crop((round(c * cw), round(r * ch),
                           round((c + 1) * cw), round((r + 1) * ch)))
        keyed = key_out_border(cell)
        # magenta enclosed by the art (inside a padlock shackle) is not
        # reached from the border: clear clearly-magenta pixels too
        rgb, px = cell.convert('RGB').load(), keyed.load()
        for y in range(keyed.height):
            for x in range(keyed.width):
                r, g, b = rgb[x, y]
                if min(r, b) - g > 120:
                    px[x, y] = (0, 0, 0, 0)
        # every opaque piece (a rocket's flame drops too), not just the
        # largest one
        box = keyed.split()[3].point(lambda a: 255 if a > 40 else 0).getbbox()
        piece = keyed.crop((max(0, box[0] - 3), max(0, box[1] - 3),
                            min(keyed.width, box[2] + 3),
                            min(keyed.height, box[3] + 3)))
        piece.thumbnail((SIZE, SIZE), Image.LANCZOS)
        piece.save(OUT / f'act_{name}.png')
        print(name, piece.size)


if __name__ == '__main__':
    main()
