"""Cut the v12.15 generated sheets (pure magenta key) into game sprites:
Vacuum Empire enemies and bosses, the chick pets and the item/UI icons that
replace every old (v9/v10/v16/v52) picture. Run tools/png_to_webp.py on the
output folders next.

Sources: assets/concept/v14_{enemies,bosses,pets,icons_a,icons_b}/raw.png
Run: python tools/cut_v14_art.py
"""
import pathlib
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from cut_ui_kit import key_out_border  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONCEPT = ROOT / 'assets/concept'
ART = ROOT / 'assets/art'

# (sheet, columns, rows, output folder, longest side, names; None = skip)
SHEETS = [
    ('v14_enemies', 4, 3, 'enemies_v14', 256,
     [f'enemy_{i}' for i in range(11)] + [None]),
    ('v14_bosses', 4, 3, 'enemies_v14', 384,
     [f'boss_{i}' for i in range(10)] + [None, None]),
    ('v14_pets', 3, 1, 'pets_v14', 256, ['pet_0', 'pet_1', 'pet_2']),
    ('v14_icons_a', 4, 3, 'icons_v14', 160, [
        'codex', 'fast_forward', 'coin', 'key',
        'calendar', 'chick', 'gem', 'bolt',
        'shield', 'pause', 'crosshair', 'refresh',
    ]),
    ('v14_icons_b', 4, 3, 'icons_v14', 160, [
        'rotate', 'season', 'gene', 'relic_dust',
        'explore_ticket', 'token', 'collect_crate', 'heal',
        'magnet', 'bomb', 'hourglass', 'speed',
    ]),
    # v12.16 ship ultimates: missile storm, clones, invincible, star cannon
    ('v15_ultimates', 4, 1, 'icons_v14', 160,
     ['ult_storm', 'ult_clone', 'ult_shield', 'ult_star']),
]


def cut(cell: Image.Image) -> Image.Image:
    keyed = key_out_border(cell)
    # magenta enclosed by the art is not reached from the border
    rgb, px = cell.convert('RGB').load(), keyed.load()
    for y in range(keyed.height):
        for x in range(keyed.width):
            r, g, b = rgb[x, y]
            if min(r, b) - g > 120:
                px[x, y] = (0, 0, 0, 0)
    box = keyed.split()[3].point(lambda a: 255 if a > 40 else 0).getbbox()
    return keyed.crop((max(0, box[0] - 3), max(0, box[1] - 3),
                       min(keyed.width, box[2] + 3),
                       min(keyed.height, box[3] + 3)))


def main() -> None:
    for sheet_name, cols, rows, folder, side, names in SHEETS:
        sheet = Image.open(CONCEPT / sheet_name / 'raw.png')
        out = ART / folder
        out.mkdir(parents=True, exist_ok=True)
        cw, ch = sheet.width / cols, sheet.height / rows
        for i, name in enumerate(names):
            if name is None:
                continue
            c, r = i % cols, i // cols
            cell = sheet.crop((round(c * cw), round(r * ch),
                               round((c + 1) * cw), round((r + 1) * ch)))
            piece = cut(cell)
            piece.thumbnail((side, side), Image.LANCZOS)
            piece.save(out / f'{name}.png')
            print(folder, name, piece.size)


if __name__ == '__main__':
    main()
