"""Cut a generated icon sheet (icons on flat white, one per grid cell) into
square transparent WebP icons.

The white background is removed by flood fill from each cell's border, so
white areas inside an outlined icon stay opaque.

Run: python tools/slice_icon_sheet.py [--fx] <sheet.png> <cols> <rows>
                                      <out dir> <name> [<name> ...]
('-' skips a cell). --fx: light effects drawn on black; brightness becomes
alpha, so the sprite glows the same over any background.
"""
import pathlib
import sys
from collections import deque

from PIL import Image

SIZE = 256
MARGIN = .06
WHITE = 236  # every channel at least this bright counts as background


def _drop_edge_slivers(im: Image.Image) -> None:
    """Clears opaque pieces that touch the cell edge (a neighbour's flame or
    pole crossing the grid line), keeping the cell's largest piece."""
    px = im.load()
    w, h = im.size
    label = [0] * (w * h)
    pieces = []  # (size, touches_edge, pixels)
    for start in range(w * h):
        if label[start] or px[start % w, start // w][3] <= 8:
            continue
        label[start] = len(pieces) + 1
        todo, pixels, edge = [start], [], False
        while todo:
            i = todo.pop()
            x, y = i % w, i // w
            pixels.append(i)
            edge = edge or x in (0, w - 1) or y in (0, h - 1)
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                j = ny * w + nx
                if 0 <= nx < w and 0 <= ny < h and not label[j] \
                        and px[nx, ny][3] > 8:
                    label[j] = len(pieces) + 1
                    todo.append(j)
        pieces.append((len(pixels), edge, pixels))
    if not pieces:
        return
    largest = max(pieces, key=lambda p: p[0])
    for piece in pieces:
        if piece is not largest and piece[1]:
            for i in piece[2]:
                px[i % w, i // w] = (255, 255, 255, 0)


def light(cell: Image.Image) -> Image.Image:
    """Black-background glow -> straight-alpha sprite (alpha = brightest
    channel, colour un-premultiplied)."""
    rgb = cell.convert('RGB')
    px = rgb.load()
    out = Image.new('RGBA', rgb.size)
    po = out.load()
    w, h = rgb.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            a = max(r, g, b)
            if a < 10:
                po[x, y] = (0, 0, 0, 0)
                continue
            po[x, y] = (min(255, r * 255 // a), min(255, g * 255 // a),
                        min(255, b * 255 // a), a)
    return out


def square(im: Image.Image) -> Image.Image:
    box = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    if box is None:
        raise ValueError('empty cell')
    sprite = im.crop(box)
    side = round(max(sprite.size) * (1 + 2 * MARGIN))
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(
        sprite, ((side - sprite.width) // 2, (side - sprite.height) // 2))
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def cut(cell: Image.Image) -> Image.Image:
    im = cell.convert('RGBA')
    px = im.load()
    w, h = im.size
    seen = bytearray(w * h)
    todo = deque((x, y) for x in range(w) for y in (0, h - 1))
    todo.extend((x, y) for y in range(h) for x in (0, w - 1))
    while todo:
        x, y = todo.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, _ = px[x, y]
        if min(r, g, b) < WHITE:
            continue
        px[x, y] = (255, 255, 255, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                todo.append((nx, ny))
    _drop_edge_slivers(im)
    return square(im)


def main() -> None:
    args = sys.argv[1:]
    fx = args[0] == '--fx'
    if fx:
        args = args[1:]
    sheet = Image.open(args[0])
    cols, rows = int(args[1]), int(args[2])
    out = pathlib.Path(args[3])
    names = args[4:]
    out.mkdir(parents=True, exist_ok=True)
    cw, ch = sheet.width / cols, sheet.height / rows
    for index, name in enumerate(names):
        if name == '-':
            continue
        c, r = index % cols, index // cols
        cell = sheet.crop((round(c * cw), round(r * ch),
                           round((c + 1) * cw), round((r + 1) * ch)))
        sprite = square(light(cell)) if fx else cut(cell)
        sprite.save(out / f'{name}.webp', 'WEBP', quality=90,
                       alpha_quality=100, method=6)
        print(out / f'{name}.webp')


if __name__ == '__main__':
    main()
