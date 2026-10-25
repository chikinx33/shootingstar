"""Cut the v12.11 support device cores (generated on a pure magenta key)
into the airframe's middle-socket sprites, one per support part.

Sources: assets/concept/support_orbs_v1/support_orbs_raw.png (3x2 sheet)
and shield_orb_raw.png (one piece). Output PNGs land in
assets/art/ship_parts/orbs/; run tools/png_to_webp.py on that folder next.

Run: python tools/cut_support_orbs.py
"""
import pathlib
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from cut_ui_kit import key_out_border, largest_piece  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/concept/support_orbs_v1'
OUT = ROOT / 'assets/art/ship_parts/orbs'
SHEET = ['armor', 'capacitor', 'sensor', 'repair', 'magnet', 'thruster']
SIZE = 192  # longest side; the socket is drawn well under this


def save(piece: Image.Image, name: str) -> None:
    piece.thumbnail((SIZE, SIZE), Image.LANCZOS)
    piece.save(OUT / f'{name}.png')
    print(name, piece.size)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SRC / 'support_orbs_raw.png')
    cw, ch = sheet.width / 3, sheet.height / 2
    for i, name in enumerate(SHEET):
        c, r = i % 3, i // 3
        cell = sheet.crop((round(c * cw), round(r * ch),
                           round((c + 1) * cw), round((r + 1) * ch)))
        save(largest_piece(key_out_border(cell)), name)
    save(largest_piece(key_out_border(Image.open(SRC / 'shield_orb_raw.png'))),
         'shield')


if __name__ == '__main__':
    main()
