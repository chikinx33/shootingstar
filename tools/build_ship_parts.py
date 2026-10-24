"""Turn the Sunshine concept part PNGs into game assets and a default layout.

Reads assets/concept/sunshine_parts_v1/, writes trimmed and downscaled sprites
to assets/art/ship_parts/sunshine/ and the default layer layout to
assets/data/ship_layouts.json. Positions come from the one-piece concept
(1254px canvas, centre 627,627): x/y/width are fractions of that canvas.

Run: python tools/build_ship_parts.py  (overwrites the JSON with defaults)
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/concept/sunshine_parts_v1'
OUT = ROOT / 'assets/art/ship_parts/sunshine'
JSON_PATH = ROOT / 'assets/data/ship_layouts.json'
N = 1254           # concept canvas
EXPORT = 768 / N   # sprites keep a 768px ship canvas worth of detail


def clean(im):
    im = im.convert('RGBA')
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v <= 16 else (255 if v >= 240 else v))
    im = Image.merge('RGBA', (r, g, b, a))
    return im.crop(a.getbbox())


def load(name):
    return clean(Image.open(SRC / name))


def fit(im, box, width_only=False):
    """Concept placement used by combine_sunshine_v2.py → (centre x, centre y, width)."""
    x0, y0, x1, y1 = box
    s = (x1 - x0) / im.width if width_only else min((x1 - x0) / im.width, (y1 - y0) / im.height)
    w, h = im.width * s, im.height * s
    left = x0 + (x1 - x0 - w) / 2
    top = y0 if width_only else y0 + (y1 - y0 - h) / 2
    return left + w / 2, top + h / 2, w


def split_frames(sheet, count=4):
    a = sheet.getchannel('A')
    cols = [any(a.getpixel((x, y)) > 16 for y in range(0, sheet.height, 3)) for x in range(sheet.width)]
    runs, start = [], None
    for x, on in enumerate(cols + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 20:
                runs.append((start, x))
            start = None
    assert len(runs) == count, runs
    return [clean(sheet.crop((s, 0, e, sheet.height))) for s, e in runs]


def nozzles(sprite, scale, left, top, row_frac=.965):
    a = sprite.getchannel('A')
    y = round(sprite.height * row_frac)
    runs, start = [], None
    for x in range(sprite.width + 1):
        on = x < sprite.width and a.getpixel((x, y)) > 128
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 6:
                runs.append((left + (start + x) / 2 * scale, (x - start) * scale, top + y * scale))
            start = None
    return runs


def gap_split(im):
    """Column in the middle transparent gap of a twin sprite (falls back to the centre)."""
    a = im.getchannel('A')
    empty = [all(a.getpixel((x, y)) <= 16 for y in range(0, im.height, 2)) for x in range(im.width)]
    mid = im.width // 2
    for d in range(im.width // 4):
        for x in (mid - d, mid + d):
            if empty[x]:
                return x
    return mid


def canopy_from(base):
    """Cut the glass dome (with the cat) out of the base so it can sit above armour."""
    px = base.load()
    xs, ys = [], []
    for y in range(base.height):
        for x in range(base.width):
            r, g, b, a = px[x, y]
            if a > 200 and b > 170 and b > r + 60 and g > 90:
                xs.append(x); ys.append(y)
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    pad = round((x1 - x0) * .06)
    box = (max(0, x0 - pad), max(0, y0 - pad), min(base.width, x1 + pad), min(base.height, y1 + pad))
    crop = base.crop(box)
    mask = Image.new('L', crop.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, crop.width - 1, crop.height - 1), fill=255)
    r, g, b, a = crop.split()
    a = Image.composite(a, Image.new('L', crop.size, 0), mask)
    return Image.merge('RGBA', (r, g, b, a)), box


def save(im, name, concept_width):
    w = max(8, round(concept_width * EXPORT))
    h = max(8, round(im.height * w / im.width))
    im.resize((w, h), Image.LANCZOS).save(OUT / name, optimize=True)
    return h / w


def u(v):  # concept px → canvas fraction, centred
    return round((v - N / 2) / N, 4)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    layers = []

    def layer(id_, label, asset, cx, cy, w, aspect, z, **extra):
        entry = {'id': id_, 'label': label, 'asset': asset, 'aspect': round(aspect, 4),
                 'x': u(cx), 'y': u(cy), 'width': round(w / N, 4), 'rotation': 0.0,
                 'pivotX': .5, 'pivotY': .5, 'z': z, 'flipX': False, 'visible': True}
        entry.update(extra)
        layers.append(entry)

    base = load('v2_base_nowing.png')
    engines = load('v2_engines_noflame.png')
    wing = load('v2_wing_left.png')
    flames = split_frames(Image.open(SRC / 'v2_flame_frames.png').convert('RGBA'))
    flame_w = max(f.width for f in flames)
    flame_aspect = None
    for i, f in enumerate(flames):
        # pad every frame to one width so frames swap without jumping
        pad = Image.new('RGBA', (flame_w, max(fr.height for fr in flames)), (0, 0, 0, 0))
        pad.alpha_composite(f, ((flame_w - f.width) // 2, 0))
        flame_aspect = save(pad, f'flame_{i + 1}.png', 90)
    frames = [f'assets/art/ship_parts/sunshine/flame_{i + 1}.png' for i in range(len(flames))]
    P = 'assets/art/ship_parts/sunshine/'

    # Pairs: only the left piece is drawn; the right layer mirrors it
    # (mirrorOf), so the editor moves both sides together.
    cx, cy, w = fit(wing, (90, 520, 590, 870))
    layer('wing_l', '날개', P + 'wing_left.png', cx, cy, w, save(wing, 'wing_left.png', w), 1)
    layer('wing_r', '날개 (오른쪽)', P + 'wing_left.png', N - cx, cy, w, wing.height / wing.width, 1,
          flipX=True, mirrorOf='wing_l')

    # engines: split the twin housing into its left thruster + a mirror,
    # and hang each flame on its thruster (attachTo) so it follows.
    ecx, ecy, ew = fit(engines, (310, 760, 945, 1080))
    es = ew / engines.width
    left = clean(engines.crop((0, 0, gap_split(engines), engines.height)))
    lbox = engines.getchannel('A').crop((0, 0, gap_split(engines), engines.height)).point(
        lambda v: 255 if v > 16 else 0).getbbox()
    lx0 = ecx - ew / 2 + lbox[0] * es
    ly0 = ecy - ew * engines.height / engines.width / 2 + lbox[1] * es
    lw = left.width * es
    lcx, lcy = lx0 + lw / 2, ly0 + left.height * es / 2
    layer('engine_l', '추진기', P + 'engine_left.png', lcx, lcy, lw, save(left, 'engine_left.png', lw), 2)
    layer('engine_r', '추진기 (오른쪽)', P + 'engine_left.png', N - lcx, lcy, lw, left.height / left.width, 2,
          flipX=True, mirrorOf='engine_l')
    nx, nw, ny = nozzles(left, es, lx0, ly0)[0]
    # pivot at the flame's top centre, so x/y is the nozzle mouth
    layer('flame_l', '추진기 불꽃', frames[0], nx, ny - nw * .45, nw * 1.25, flame_aspect, 0,
          pivotY=0.0, frames=frames, fps=14, attachTo='engine_l')
    layer('flame_r', '추진기 불꽃 (오른쪽)', frames[0], N - nx, ny - nw * .45, nw * 1.25, flame_aspect, 0,
          pivotY=0.0, frames=frames, fps=14, mirrorOf='flame_l', flipX=True)
    # base pod + its own nozzle flame + canopy layer
    bcx, bcy, bw = fit(base, (380, 130, 875, 1060))
    bh = bw * base.height / base.width
    layer('base', '기본 기체', P + 'base.png', bcx, bcy, bw, save(base, 'base.png', bw), 4)
    for nx, nw, ny in nozzles(base, bw / base.width, bcx - bw / 2, bcy - bh / 2, .975)[:1]:
        layer('flame_base', '기본 기체 불꽃', frames[0], nx, ny - nw * .45, nw * 1.25, flame_aspect, 3,
              pivotY=0.0, frames=frames, fps=14, attachTo='base')
    canopy, (x0, y0, x1, y1) = canopy_from(base)
    s = bw / base.width
    layer('canopy', '조종석 유리 (고양이)', P + 'canopy.png',
          bcx - bw / 2 + (x0 + x1) / 2 * s, bcy - bh / 2 + (y0 + y1) / 2 * s, (x1 - x0) * s,
          save(canopy, 'canopy.png', (x1 - x0) * s), 7, attachTo='base')

    for id_, label, name, box, z, extra in [
        ('armor', '동체 장갑', 'part_armor.png', (385, 340, 875, None), 5, {}),
        ('nose', '기수 덮개', 'part_nose.png', (490, 195, 770, 400), 6, {}),
        ('shield', '보호막 장치', 'part_shield.png', (550, 735, 705, 880), 8, {}),
    ]:
        im = load(name)
        cx, cy, w = fit(im, box if box[3] else (box[0], box[1], box[2], 0), width_only=box[3] is None)
        layer(id_, label, P + name.replace('part_', ''), cx, cy, w, save(im, name.replace('part_', ''), w), z, **extra)

    missile, gun, rear = load('part_missile.png'), load('part_winggun.png'), load('part_reargun.png')
    cx, cy, w = fit(missile, (245, 545, 380, 750))
    layer('missile_l', '미사일', P + 'missile.png', cx, cy, w, save(missile, 'missile.png', w), 9)
    layer('missile_r', '미사일 (오른쪽)', P + 'missile.png', N - cx, cy, w, missile.height / missile.width, 9,
          flipX=True, mirrorOf='missile_l')
    cx, cy, w = fit(gun, (95, 545, 215, 745))
    layer('gun_l', '윙건', P + 'winggun.png', cx, cy, w, save(gun, 'winggun.png', w), 10)
    layer('gun_r', '윙건 (오른쪽)', P + 'winggun.png', N - cx, cy, w, gun.height / gun.width, 10,
          flipX=True, mirrorOf='gun_l')
    rotated = rear.rotate(180, expand=True)
    cx, cy, w = fit(rotated, (560, 845, 695, 1135))
    layer('rear_gun', '후방 자주포', P + 'reargun.png', cx, cy, w, save(rear, 'reargun.png', w), 11, rotation=180.0)

    layers.sort(key=lambda e: (e['z'], e['id']))
    data = {'revision': 1, 'ships': {'sunshine': {'label': '선샤인', 'layers': layers}}}
    JSON_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(layers)} layers → {JSON_PATH.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
