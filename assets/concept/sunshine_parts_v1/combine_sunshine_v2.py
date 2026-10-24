"""Sunshine v2 layer test: wingless base, one left wing mirrored for the right,
flame-less thrusters with a separate 4-frame flame animation.
Boxes are measured on the 1254px one-piece concept (ref/full.png)."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageOps

D = os.path.dirname(os.path.abspath(__file__))
FONT = 'F:/NKW/App/Shootingstar/assets/fonts/NotoSansKR.ttf'
N = 1254


def clean(im):
    im = im.convert('RGBA')
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v <= 16 else (255 if v >= 240 else v))
    im = Image.merge('RGBA', (r, g, b, a))
    return im.crop(a.getbbox())


def load(name):
    return clean(Image.open(os.path.join(D, name)))


def fit_box(im, box, width_only=False):
    x0, y0, x1, y1 = box
    s = (x1 - x0) / im.width if width_only else min((x1 - x0) / im.width, (y1 - y0) / im.height)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    y = y0 if width_only else y0 + (y1 - y0 - im.height) // 2
    return im, (x0 + (x1 - x0 - im.width) // 2, y)


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
    # each frame starts at its own attachment bar so every frame meets the nozzle
    return [clean(sheet.crop((s, 0, e, sheet.height))) for s, e in runs]


def clean_keep_top(im):
    bb = im.getchannel('A').point(lambda v: 255 if v > 16 else 0).getbbox()
    return im.crop((bb[0], 0, bb[2], bb[3]))


def nozzles(sprite, at, row_frac=.965):
    """Opaque runs on a row near the bottom of the placed sprite → nozzle (centre x, width, y)."""
    a = sprite.getchannel('A')
    y = round(sprite.height * row_frac)
    runs, start = [], None
    for x in range(sprite.width + 1):
        on = x < sprite.width and a.getpixel((x, y)) > 128
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 6:
                runs.append((at[0] + (start + x) / 2, x - start, at[1] + y))
            start = None
    return runs


base = load('v2_base_nowing.png')
wing_l = load('v2_wing_left.png')
wing_r = ImageOps.mirror(wing_l)
engines = load('v2_engines_noflame.png')
FLAMES = split_frames(Image.open(os.path.join(D, 'v2_flame_frames.png')).convert('RGBA'))
for i, f in enumerate(FLAMES):
    f.save(os.path.join(D, f'v2_flame_{i + 1}.png'))

armor, nose, shield = load('part_armor.png'), load('part_nose.png'), load('part_shield.png')
gun, missile = load('part_winggun.png'), load('part_missile.png')
rear = load('part_reargun.png').rotate(180, expand=True)

STEP_BASE, STEP_FRAME, STEP_ARMOR, STEP_SHIELD, STEP_ALL = range(1, 6)


def assemble(frame=0, step=STEP_ALL, flame_scale=1.0):
    c = Image.new('RGBA', (N, N), (0, 0, 0, 0))

    def put(im, box, width_only=False):
        im, at = fit_box(im, box, width_only)
        c.alpha_composite(im, at)
        return im, at

    flame = FLAMES[frame % len(FLAMES)]
    flame_jobs = []
    if step >= STEP_FRAME:
        put(wing_l, (90, 520, 590, 870))
        put(wing_r, (664, 520, 1164, 870))
        eng, eng_at = fit_box(engines, (310, 760, 945, 1080))
        flame_jobs += nozzles(eng, eng_at)
    b, b_at = fit_box(base, (380, 130, 875, 1060))
    if step < STEP_FRAME:
        flame_jobs += nozzles(b, b_at, .975)
    # flames go under the nozzles
    for cx, w, y in flame_jobs:
        fw = w * 1.25
        s = fw / flame.width
        f = flame.resize((max(1, round(fw)), max(1, round(flame.height * s * flame_scale))), Image.LANCZOS)
        c.alpha_composite(f, (round(cx - f.width / 2), round(y - w * .45)))
    if step >= STEP_FRAME:
        c.alpha_composite(eng, eng_at)
    c.alpha_composite(b, b_at)
    if step >= STEP_ARMOR:
        put(armor, (385, 340, 875, None), width_only=True)
        put(nose, (490, 195, 770, 400))
    if step >= STEP_SHIELD:
        put(shield, (550, 735, 705, 880))
    if step >= STEP_ALL:
        put(missile, (245, 545, 380, 750))
        put(ImageOps.mirror(missile), (875, 545, 1005, 750))
        put(gun, (95, 545, 215, 745))
        put(ImageOps.mirror(gun), (1040, 545, 1160, 745))
        put(rear, (560, 845, 695, 1135))
    return c


full = assemble()
full.save(os.path.join(D, 'assembled_sunshine_v2.png'))

# Flame animation preview: 4 frames ping-pong with a small length jitter.
order = [0, 1, 2, 3, 2, 1]
jitter = [1.0, 1.06, .94, 1.03, .97, 1.05]
gif = []
for i, (fr, j) in enumerate(zip(order, jitter)):
    bg = Image.new('RGBA', (520, 560), (38, 104, 140, 255))
    shot = assemble(fr, STEP_ALL, j).resize((520, 520), Image.LANCZOS)
    bg.alpha_composite(shot, (0, 10))
    gif.append(bg.convert('P', palette=Image.ADAPTIVE, colors=255))
gif[0].save(os.path.join(D, 'sunshine_v2_flame.gif'), save_all=True, append_images=gif[1:], duration=70, loop=0, disposal=2)

# Comparison sheet
concept = Image.open(os.path.join(D, 'ref', 'full.png')).convert('RGBA')
big, mid, small = (ImageFont.truetype(FONT, s) for s in (40, 28, 22))
W, H = 2100, 1250
sheet = Image.new('RGBA', (W, H), (255, 196, 92, 255))
d = ImageDraw.Draw(sheet)
d.text((W // 2, 45), '선샤인 v2 — 날개 없는 기본 기체 · 날개 한 짝 반전 · 불꽃 분리', font=big, fill=(30, 30, 50), anchor='mm')
for i, (label, im) in enumerate([('원래 시안', concept), ('v2 합체 결과', full)]):
    sheet.alpha_composite(im.resize((600, 600), Image.LANCZOS), (80 + i * 660, 90))
    d.text((380 + i * 660, 710), label, font=mid, fill=(30, 30, 50), anchor='mm')
x = 1440
d.text((1760, 100), '불꽃 4프레임 (애니메이션)', font=mid, fill=(30, 30, 50), anchor='mm')
for i, f in enumerate(FLAMES):
    t, _ = fit_box(f, (0, 0, 130, 200))
    sheet.alpha_composite(t, (1460 + i * 150 + (130 - t.width) // 2, 140))
    d.text((1525 + i * 150, 360), f'{i + 1}', font=small, fill=(30, 30, 50), anchor='mm')
d.text((1760, 420), '날개: 왼쪽 1장 → 오른쪽 반전', font=mid, fill=(30, 30, 50), anchor='mm')
for i, wg in enumerate([wing_l, wing_r]):
    t, _ = fit_box(wg, (0, 0, 280, 200))
    sheet.alpha_composite(t, (1470 + i * 300, 460 + (200 - t.height) // 2))
names = ['기본 기체', '+날개·추진기', '+장갑·기수', '+보호막', '+무기 3칸']
for i, n in enumerate(names):
    t = assemble(i % 4, i + 1).resize((330, 330), Image.LANCZOS)
    sheet.alpha_composite(t, (60 + i * 400, 780))
    d.text((225 + i * 400, 1140), n, font=small, fill=(30, 30, 50), anchor='mm')
sheet.convert('RGB').save(os.path.join(D, 'combine_test_v2.png'))
print('ok')
