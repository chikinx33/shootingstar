"""Add another cat's airframe to assets/data/ship_layouts.json.

The new ship reuses Sunshine's current (user-edited) equipment layout — parts
are shared equipment — and swaps in its own base pod and canopy cut from the
given base PNG. Sunshine itself is never changed. Revision grows by one.

  python tools/add_ship_variant.py nightfall 나이트폴 path/to/base.png
"""
from pathlib import Path
import copy
import json
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_ship_parts as bsp  # noqa: E402

LAYOUTS = ROOT / 'assets/data/ship_layouts.json'


def main():
    ship_id, label, base_path = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    data = json.loads(LAYOUTS.read_text(encoding='utf-8'))
    source = data['ships']['sunshine']
    layers = copy.deepcopy(source['layers'])
    by_id = {l['id']: l for l in layers}
    sun_base = by_id['base']
    out_dir = ROOT / f'assets/art/ship_parts/{ship_id}'
    out_dir.mkdir(parents=True, exist_ok=True)

    base = bsp.clean(Image.open(base_path))
    # same height and centre as Sunshine's base so every part still fits
    height = sun_base['width'] * sun_base['aspect']
    width = height * base.width / base.height
    px = 768 / 1  # export resolution per canvas unit
    w_px = max(8, round(width * px))
    base.resize((w_px, round(base.height * w_px / base.width)), Image.LANCZOS).save(out_dir / 'base.png', optimize=True)
    by_id['base'].update(asset=f'assets/art/ship_parts/{ship_id}/base.png',
                         aspect=round(base.height / base.width, 4), width=round(width, 4))

    canopy, (x0, y0, x1, y1) = bsp.canopy_from(base)
    s = width / base.width  # canvas units per source px
    left = sun_base['x'] - width * sun_base['pivotX']
    top = sun_base['y'] - height * sun_base['pivotY']
    cw = (x1 - x0) * s
    c_px = max(8, round(cw * px))
    canopy.resize((c_px, round(canopy.height * c_px / canopy.width)), Image.LANCZOS).save(out_dir / 'canopy.png', optimize=True)
    by_id['canopy'].update(asset=f'assets/art/ship_parts/{ship_id}/canopy.png',
                           aspect=round(canopy.height / canopy.width, 4), width=round(cw, 4),
                           x=round(left + (x0 + x1) / 2 * s, 4), y=round(top + (y0 + y1) / 2 * s, 4),
                           pivotX=.5, pivotY=.5)
    # the pod's own nozzle flame sits at its new nozzle
    noz = bsp.nozzles(base, s, left, top, .975)
    if noz and 'flame_base' in by_id:
        nx, nw, ny = noz[0]
        f = by_id['flame_base']
        f.update(x=round(nx, 4), y=round(ny - nw * .45, 4), width=round(nw * 1.25, 4), pivotX=.5, pivotY=0)
    data['ships'][ship_id] = {'label': label, 'layers': layers}
    data['revision'] = int(data.get('revision', 0)) + 1
    LAYOUTS.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{ship_id}: {len(layers)} layers, revision {data["revision"]}')


if __name__ == '__main__':
    main()
