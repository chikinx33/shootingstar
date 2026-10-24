"""Render a ship from assets/data/ship_layouts.json exactly as the editor does.

x/y: canvas fractions (centre 0,0) of the sprite's pivot point.
width: sprite width as a canvas fraction; height = width * aspect.
pivotX/pivotY: pivot inside the sprite (0..1, after flipX).
rotation: degrees clockwise around the pivot. Higher z draws on top.
A layer with mirrorOf copies that layer mirrored across the centre line.

Run: python tools/render_ship_layout.py [ship] [out.png] [size] [frame]
"""
from pathlib import Path
import json
import math
import sys
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]


def resolve(layers):
    by_id = {l['id']: l for l in layers}
    out = []
    for l in layers:
        src = by_id.get(l.get('mirrorOf'))
        if src:
            l = {**l, 'x': -src['x'], 'y': src['y'], 'width': src['width'], 'rotation': -src['rotation'],
                 'pivotX': 1 - src['pivotX'], 'pivotY': src['pivotY'], 'flipX': not src['flipX'],
                 'aspect': src['aspect'], 'asset': src['asset'], 'frames': src.get('frames')}
        out.append(l)
    return out


def render(ship='sunshine', size=1024, frame=0, data=None, pad=.15):
    """[size] is one canvas unit; [pad] adds room on every side for parts
    placed outside the -0.5..0.5 frame (the image is size * (1 + 2 * pad))."""
    data = data or json.loads((ROOT / 'assets/data/ship_layouts.json').read_text(encoding='utf-8'))
    layers = resolve(data['ships'][ship]['layers'])
    margin = round(size * pad)
    canvas = Image.new('RGBA', (size + 2 * margin, size + 2 * margin), (0, 0, 0, 0))
    for l in sorted(layers, key=lambda e: e['z']):
        if not l.get('visible', True):
            continue
        asset = (l.get('frames') or [l['asset']])[frame % len(l.get('frames') or [l['asset']])]
        im = Image.open(ROOT / asset).convert('RGBA')
        w = max(1, round(l['width'] * size))
        h = max(1, round(w * l['aspect']))
        im = im.resize((w, h), Image.LANCZOS)
        if l.get('flipX'):
            im = ImageOps.mirror(im)
        px, py = l['pivotX'] * w, l['pivotY'] * h
        # pad so the pivot is the image centre, then rotate about it
        half = math.ceil(math.hypot(max(px, w - px), max(py, h - py)))
        pad = Image.new('RGBA', (half * 2, half * 2), (0, 0, 0, 0))
        pad.alpha_composite(im, (round(half - px), round(half - py)))
        pad = pad.rotate(-l['rotation'], resample=Image.BICUBIC)
        cx, cy = margin + size / 2 + l['x'] * size, margin + size / 2 + l['y'] * size
        canvas.alpha_composite(pad, (round(cx - half), round(cy - half)))
    return canvas


if __name__ == '__main__':
    ship = sys.argv[1] if len(sys.argv) > 1 else 'sunshine'
    out = sys.argv[2] if len(sys.argv) > 2 else str(ROOT / 'assets/concept/sunshine_parts_v1/layout_render.png')
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
    frame = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    render(ship, size, frame).save(out)
    print(out)
