"""Clean the skill card frames' edges (v12.9, user 2026-10-25: frame edges
looked ragged). The frames were cut from a white background, so their soft
outer edge still carries a light halo and a few stray specks. Every frame has
a thick dark outline, so a light semi-transparent edge pixel is recoloured to
that outline colour, and pieces far smaller than the frame are dropped.

Run: python tools/defringe_card_frames.py   (originals are kept in
.local/cards_frames_backup/ the first time)
"""
import pathlib
import shutil

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art/cards_v13'
BACKUP = ROOT / '.local/cards_frames_backup'
OUTLINE = (22, 18, 30)


def components(px, w, h):
    seen = bytearray(w * h)
    for start in range(w * h):
        if seen[start] or px[start % w, start // w][3] < 24:
            continue
        seen[start] = 1
        stack, members = [start], []
        while stack:
            i = stack.pop()
            members.append(i)
            x, y = i % w, i // w
            for nx in (x - 1, x, x + 1):
                for ny in (y - 1, y, y + 1):
                    j = ny * w + nx
                    if 0 <= nx < w and 0 <= ny < h and not seen[j] \
                            and px[nx, ny][3] >= 24:
                        seen[j] = 1
                        stack.append(j)
        yield members


def clean(path: pathlib.Path) -> tuple[int, int]:
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()
    pieces = sorted(components(px, w, h), key=len, reverse=True)
    dropped = 0
    for piece in pieces[1:]:
        if len(piece) < 400:
            for i in piece:
                px[i % w, i // w] = (0, 0, 0, 0)
            dropped += len(piece)
    recoloured = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if a < 24:
                px[x, y] = (0, 0, 0, 0)
            elif a < 250 and min(r, g, b) > 120:
                # light halo left from the white background
                px[x, y] = (*OUTLINE, a)
                recoloured += 1
    im.save(path, 'WEBP', quality=94, alpha_quality=100, method=6)
    return recoloured, dropped


def main() -> None:
    BACKUP.mkdir(parents=True, exist_ok=True)
    for t in range(1, 7):
        path = ART / f'frame_{t}.webp'
        if not (BACKUP / path.name).exists():
            shutil.copy2(path, BACKUP / path.name)
        shutil.copy2(BACKUP / path.name, path)
        print(path.name, *clean(path))


if __name__ == '__main__':
    main()
