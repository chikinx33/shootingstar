"""Layer Sunshine's separate part PNGs into the full-equipped look and compare
with the one-piece concept. Boxes were measured on the 1254px concept image."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageOps

D = 'F:/NKW/App/Shootingstar/assets/concept/sunshine_parts_v1'
FONT = 'F:/NKW/App/Shootingstar/assets/fonts/NotoSansKR.ttf'
N = 1254

# bottom → top. (name, file, box, mirror, rotate180)
LAYERS = [
    ('날개', 'part_wings.png', (90, 540, 1165, 860), False, False),
    ('추진기', 'part_engines.png', (330, 780, 920, 1115), False, False),
    ('기본 기체', None, None, False, False),
    ('동체 장갑', 'part_armor.png', (385, 340, 875, 'w'), False, False),
    ('기수 덮개', 'part_nose.png', (490, 195, 770, 400), False, False),
    ('보호막 장치', 'part_shield.png', (550, 735, 705, 880), False, False),
    ('미사일 L', 'part_missile.png', (245, 545, 380, 750), False, False),
    ('미사일 R', 'part_missile.png', (875, 545, 1005, 750), True, False),
    ('윙건 L', 'part_winggun.png', (95, 545, 215, 745), False, False),
    ('윙건 R', 'part_winggun.png', (1040, 545, 1160, 745), True, False),
    ('후방 자주포', 'part_reargun.png', (560, 845, 695, 1135), False, True),
]


def clean(path):
    im = Image.open(path).convert('RGBA')
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v <= 16 else (255 if v >= 240 else v))
    im = Image.merge('RGBA', (r, g, b, a))
    return im.crop(a.getbbox())


def fit_box(im, box):
    x0, y0, x1, y1 = box
    if y1 == 'w':  # fit to width, top-aligned
        s = (x1 - x0) / im.width
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        return im, (x0, y0)
    s = min((x1 - x0) / im.width, (y1 - y0) / im.height)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    return im, (x0 + (x1 - x0 - im.width) // 2, y0 + (y1 - y0 - im.height) // 2)


def base_layer():
    # Match the base canopy (centre 627,592 / width 415) to the concept canopy
    # (centre 627,562 / width 325).
    im = Image.open(os.path.join(D, 'base_airframe.png')).convert('RGBA')
    s = 325 / 415
    im = im.resize((round(N * s), round(N * s)), Image.LANCZOS)
    return im, (round(627 - 627 * s), round(562 - 592 * s))


def assemble(upto=None):
    canvas = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    for i, (name, f, box, mirror, rot) in enumerate(LAYERS):
        if upto is not None and i >= upto:
            break
        if f is None:
            im, at = base_layer()
        else:
            im = clean(os.path.join(D, f))
            if mirror:
                im = ImageOps.mirror(im)
            if rot:
                im = im.rotate(180, expand=True)
            im, at = fit_box(im, box)
        canvas.alpha_composite(im, at)
    return canvas


full = assemble()
full.save(os.path.join(D, 'assembled_sunshine.png'))

# comparison sheet
concept = Image.open(os.path.join(D, 'ref', 'full.png')).convert('RGBA')
big, mid, small = (ImageFont.truetype(FONT, s) for s in (40, 28, 22))
W, H = 2100, 1500
sheet = Image.new('RGBA', (W, H), (255, 196, 92, 255))
d = ImageDraw.Draw(sheet)
d.text((W // 2, 50), '선샤인 부위 분리 → 합체 시험', font=big, fill=(30, 30, 50), anchor='mm')
for i, (label, im) in enumerate([('원래 시안 (한 장 그림)', concept), ('분리 PNG 합체 결과', full)]):
    t = im.resize((640, 640), Image.LANCZOS)
    x = 120 + i * 720
    sheet.alpha_composite(t, (x, 100))
    d.text((x + 320, 760), label, font=mid, fill=(30, 30, 50), anchor='mm')
# build-up steps
steps = [3, 5, 6, len(LAYERS)]
names = ['기본 기체+날개+추진기', '+장갑+기수', '+보호막', '+무기 3칸']
for i, (u, n) in enumerate(zip(steps, names)):
    t = assemble(u).resize((300, 300), Image.LANCZOS)
    x = 80 + i * 330
    sheet.alpha_composite(t, (x, 830))
    d.text((x + 150, 1150), n, font=small, fill=(30, 30, 50), anchor='mm')
# exploded parts
x, y = 1520, 110
d.text((1790, 90), '분리된 PNG', font=mid, fill=(30, 30, 50), anchor='mm')
files = [('기본 기체', 'base_airframe.png'), ('날개', 'part_wings.png'), ('추진기', 'part_engines.png'),
         ('동체 장갑', 'part_armor.png'), ('기수 덮개', 'part_nose.png'), ('보호막', 'part_shield.png'),
         ('윙건', 'part_winggun.png'), ('미사일', 'part_missile.png'), ('후방 자주포', 'part_reargun.png')]
for i, (n, f) in enumerate(files):
    im = clean(os.path.join(D, f))
    im, _ = fit_box(im, (0, 0, 150, 150))
    cx, cy = 1520 + (i % 3) * 180, 140 + (i // 3) * 210
    sheet.alpha_composite(im, (cx + (150 - im.width) // 2, cy + (150 - im.height) // 2))
    d.text((cx + 75, cy + 170), n, font=small, fill=(30, 30, 50), anchor='mm')
# battle-size check
for i, (label, im) in enumerate([('시안', concept), ('합체', full)]):
    t = im.resize((96, 96), Image.LANCZOS)
    bg = Image.new('RGBA', (130, 130), (40, 110, 140, 255))
    bg.alpha_composite(t, (17, 17))
    sheet.alpha_composite(bg, (1560 + i * 200, 900))
    d.text((1625 + i * 200, 1050), f'{label} 96px', font=small, fill=(30, 30, 50), anchor='mm')
sheet.convert('RGB').save(os.path.join(D, 'combine_test.png'))
print('ok')
