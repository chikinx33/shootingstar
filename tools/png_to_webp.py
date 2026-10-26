"""Convert bundled PNG art to WebP and shrink oversized sources.

Each folder is capped at the largest size the game ever decodes it to, so the
stored file is never bigger than what the screen can show. Alpha is kept
lossless-quality; colour uses high-quality lossy WebP.

Run: python tools/png_to_webp.py [assets/art/<folder> ...]   (default: all)
"""
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art'

# Longest side in pixels. Sprites are decoded at 256-384px; everything else
# at 1024px or less.
CAPS = {
    'enemies_v14': 640,
    'pets_v14': 640,
    'icons_v14': 320,
}
DEFAULT_CAP = 1024
# Full-screen backgrounds keep their own (already modest) resolution.
BACKGROUNDS: set = set()


def convert(png: pathlib.Path) -> tuple[int, int]:
    folder = png.resolve().relative_to(ART).parts[0]
    im = Image.open(png)
    im.load()
    if im.mode not in ('RGB', 'RGBA'):
        im = im.convert('RGBA')
    if (folder, png.stem) in BACKGROUNDS:
        cap = max(im.size)
    else:
        cap = CAPS.get(folder, DEFAULT_CAP)
    if max(im.size) > cap:
        scale = cap / max(im.size)
        im = im.resize(
            (round(im.width * scale), round(im.height * scale)), Image.LANCZOS
        )
    out = png.with_suffix('.webp')
    im.save(out, 'WEBP', quality=90, alpha_quality=100, method=6)
    before = png.stat().st_size
    png.unlink()
    return before, out.stat().st_size


def main() -> None:
    targets = [pathlib.Path(a) for a in sys.argv[1:]] or [ART]
    total_before = total_after = 0
    for target in targets:
        for png in sorted(target.rglob('*.png')):
            before, after = convert(png)
            total_before += before
            total_after += after
    print(f'{total_before // 1024}K -> {total_after // 1024}K')


if __name__ == '__main__':
    main()
