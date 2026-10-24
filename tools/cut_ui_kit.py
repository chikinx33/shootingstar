"""Cut the generated flat UI kit (drawn on a pure magenta #FF00FF key) into
pieces with clean anti-aliased alpha.

Chroma key: a pixel's "key strength" is min(red, blue) - green, which is 255
for pure magenta and <= 0 for every UI colour (yellow, blue, orange, navy,
red, white). alpha = 1 - strength / 255, and edge colours are un-blended
from the magenta they were painted over, so outlines stay smooth when the
pieces are scaled — no white fringe, no stair steps.

Run: python tools/cut_ui_kit.py
"""
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/concept/gen_v13'
OUT = ROOT / 'assets/art/ui_v13'
SHEETS = [
    ('ui_flat_a_raw.png', 2, 3,
     ['btn_yellow', 'btn_blue', 'tab_on', 'tab_off', 'plate', 'track']),
    ('ui_flat_b_raw.png', 2, 2, ['panel', 'slot', 'ribbon', 'close']),
    # v12.9 item slots by rarity: gray, green, blue, purple, gold, red
    ('rarity_slots_raw.png', 3, 2,
     ['slot_r0', 'slot_r1', 'slot_r2', 'slot_r3', 'slot_r4', 'slot_r5']),
]
KEY = (255, 0, 255)


def key_out(cell: Image.Image) -> Image.Image:
    rgb = cell.convert('RGB')
    w, h = rgb.size
    src = rgb.load()
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = src[x, y]
            strength = min(r, b) - g
            a = 1.0 - max(0.0, min(1.0, strength / 235))
            if a < .03:
                continue
            if a > .97:
                dst[x, y] = (r, g, b, 255)
                continue
            col = [max(0, min(255, round((c - (1 - a) * k) / a)))
                   for c, k in zip((r, g, b), KEY)]
            dst[x, y] = (*col, round(a * 255))
    return out


def largest_piece(im: Image.Image) -> Image.Image:
    """Crops to the biggest solid piece (drops specks and neighbours)."""
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    best = None
    for start in range(w * h):
        if seen[start] or px[start % w, start // w][3] < 128:
            continue
        seen[start] = 1
        stack, n = [start], 0
        x0, y0, x1, y1 = w, h, 0, 0
        while stack:
            i = stack.pop()
            n += 1
            x, y = i % w, i // w
            x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                j = ny * w + nx
                if 0 <= nx < w and 0 <= ny < h and not seen[j] \
                        and px[nx, ny][3] >= 128:
                    seen[j] = 1
                    stack.append(j)
        if best is None or n > best[0]:
            best = (n, (x0, y0, x1 + 1, y1 + 1))
    x0, y0, x1, y1 = best[1]
    # keep the soft edge around the solid piece
    return im.crop((max(0, x0 - 3), max(0, y0 - 3),
                    min(w, x1 + 3), min(h, y1 + 3)))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for sheet_name, cols, rows, names in SHEETS:
        sheet = Image.open(SRC / sheet_name)
        cw, ch = sheet.width / cols, sheet.height / rows
        for index, name in enumerate(names):
            c, r = index % cols, index // cols
            cell = sheet.crop((round(c * cw), round(r * ch),
                               round((c + 1) * cw), round((r + 1) * ch)))
            piece = largest_piece(key_out(cell))
            piece.save(OUT / f'{name}.webp', 'WEBP', quality=94,
                       alpha_quality=100, method=6)
            print(name, piece.size)


if __name__ == '__main__':
    main()
