"""Cut a generated sprite sheet into sprites and install them as game art.

Each object on the transparent sheet is found (pieces closer than --join
pixels count as one object), ordered row by row, trimmed, padded and saved as
assets/art/game_v10/<name>.webp; manifest.json gets fresh size/bounds/sha256.
The previous PNG is kept once in .local/game_v10_before/.

  python tools/install_game_art.py sheet.png enemy-0 enemy-1 ... [--size 512]
  python tools/install_game_art.py single.png boss-3          (one object)
  python tools/install_game_art.py sheet.png --preview out.png (no install)
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art/game_v10'
BACKUP = ROOT / '.local/game_v10_before'


def clean(im):
    im = im.convert('RGBA')
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v <= 16 else (255 if v >= 240 else v))
    return Image.merge('RGBA', (r, g, b, a))


def objects(sheet, join=24, min_area=900):
    """Bounding boxes of the objects on a transparent sheet, row-major."""
    scale = 4
    small = sheet.getchannel('A').resize((sheet.width // scale, sheet.height // scale))
    mask = small.point(lambda v: 255 if v > 24 else 0)
    if join:
        mask = mask.filter(ImageFilter.MaxFilter(max(3, (join // scale) | 1)))
    w, h = mask.size
    px = mask.load()
    seen = bytearray(w * h)
    boxes = []
    for y in range(h):
        for x in range(w):
            if px[x, y] and not seen[y * w + x]:
                stack = [(x, y)]
                seen[y * w + x] = 1
                x0 = x1 = x
                y0 = y1 = y
                count = 0
                while stack:
                    cx, cy = stack.pop()
                    count += 1
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not seen[ny * w + nx]:
                            seen[ny * w + nx] = 1
                            stack.append((nx, ny))
                if count * scale * scale >= min_area:
                    boxes.append((x0 * scale, y0 * scale, (x1 + 1) * scale, (y1 + 1) * scale))
    # refine each box to the real alpha bounds inside it
    alpha = sheet.getchannel('A').point(lambda v: 255 if v > 16 else 0)
    refined = []
    for b in boxes:
        inner = alpha.crop(b).getbbox()
        if inner:
            refined.append((b[0] + inner[0], b[1] + inner[1], b[0] + inner[2], b[1] + inner[3]))
    # row-major: group by rows using vertical centres
    refined.sort(key=lambda b: (b[1] + b[3]) / 2)
    rows, current = [], []
    for b in refined:
        if current and (b[1] + b[3]) / 2 - (current[-1][1] + current[-1][3]) / 2 > max(
                (current[-1][3] - current[-1][1]) * .5, 40):
            rows.append(current)
            current = []
        current.append(b)
    if current:
        rows.append(current)
    return [b for row in rows for b in sorted(row, key=lambda b: b[0])]


def square(sprite, size, margin=.06):
    side = round(max(sprite.size) * (1 + 2 * margin))
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(sprite, ((side - sprite.width) // 2, (side - sprite.height) // 2))
    return canvas.resize((size, size), Image.LANCZOS)


def install(name, sprite, size):
    out = ART / f'{name}.webp'
    if out.exists() and not (BACKUP / out.name).exists():
        BACKUP.mkdir(parents=True, exist_ok=True)
        shutil.copy(out, BACKUP / out.name)
    im = square(sprite, size)
    im.save(out, 'WEBP', quality=90, alpha_quality=100, method=6)
    a = im.getchannel('A')
    box = a.point(lambda v: 255 if v > 16 else 0).getbbox()
    manifest_path = ART / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest[name] = {
        'background': False,
        'size': [im.width, im.height],
        'visibleBounds': list(box),
        'bounds': [box[0] / im.width, box[1] / im.height, box[2] / im.width, box[3] / im.height],
        'safeMargin': min(box[0], box[1], im.width - box[2], im.height - box[3]),
        'alpha': list(a.getextrema()),
        'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('sheet')
    p.add_argument('names', nargs='*')
    p.add_argument('--size', type=int, default=512)
    p.add_argument('--join', type=int, default=24)
    p.add_argument('--preview')
    args = p.parse_args()
    sheet = clean(Image.open(args.sheet))
    boxes = objects(sheet, args.join)
    print(f'{len(boxes)} objects: {boxes}')
    if args.preview:
        from PIL import ImageDraw
        prev = Image.new('RGBA', sheet.size, (255, 196, 92, 255))
        prev.alpha_composite(sheet)
        d = ImageDraw.Draw(prev)
        for i, b in enumerate(boxes):
            d.rectangle(b, outline=(255, 0, 0), width=4)
            d.text((b[0] + 6, b[1] + 6), str(i), fill=(255, 0, 0))
        prev.convert('RGB').save(args.preview)
        return
    if len(boxes) != len(args.names):
        raise SystemExit(f'expected {len(args.names)} objects, found {len(boxes)}')
    for name, b in zip(args.names, boxes):
        install(name, sheet.crop(b), args.size)
        print('installed', name)


if __name__ == '__main__':
    main()
