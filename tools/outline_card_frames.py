"""Give every skill card frame a clean dark outline (v12.9.7, user
2026-10-25: a light edge still showed outside the frames; the edge must end
in a black line of the outline's thickness).

The frames were cut from a white background, so frames 1/2 lost their dark
outer line and frame 6 kept a soft purple glow outside it. Here the alpha is
made crisp (soft glow and fringe dropped), stray specks removed, and a dark
outline drawn around the shape - thick where the art has none, thin where it
already has one. Each frame is padded by PAD px; lib/ui/skill_cards.dart
holds the new sizes and inner windows (printed by this script).

Run: python tools/outline_card_frames.py   (sources: .local/cards_frames_backup)
"""
import pathlib

from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art/cards_v13'
BACKUP = ROOT / '.local/cards_frames_backup'
OUTLINE = (22, 18, 30)
PAD = 6
# outline radius (px at 300 wide): frames without their own dark line get
# the full thickness, frames that have one only a thin clean-up edge
RADIUS = {1: 5, 2: 5, 3: 2, 4: 2, 5: 2, 6: 4}


def crisp_mask(im: Image.Image) -> Image.Image:
    alpha = im.getchannel('A').point(lambda a: 255 if a >= 150 else 0)
    # drop specks: keep pixels whose 9x9 neighbourhood is mostly solid
    solid = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    return solid


def outline(t: int) -> None:
    src = Image.open(BACKUP / f'frame_{t}.webp').convert('RGBA')
    w, h = src.size
    px = src.load()
    for y in range(h):
        for x in range(w):
            r_, g, b, a = px[x, y]
            # the light halo left from the white background becomes outline
            if 0 < a < 250 and min(r_, g, b) > 120:
                px[x, y] = (*OUTLINE, a)
    im = Image.new('RGBA', (w + 2 * PAD, h + 2 * PAD), (0, 0, 0, 0))
    im.paste(src, (PAD, PAD))
    mask = crisp_mask(im)
    art = im.copy()
    art.putalpha(mask)
    r = RADIUS[t]
    ring = mask.filter(ImageFilter.MaxFilter(2 * r + 1)).filter(
        ImageFilter.GaussianBlur(.8))
    out = Image.new('RGBA', im.size, (*OUTLINE, 0))
    out.putalpha(ring)
    # soften the art's own edge a touch so it blends into the outline
    out.alpha_composite(art)
    out.save(ART / f'frame_{t}.webp', 'WEBP', quality=94, alpha_quality=100,
             method=6)
    print(t, out.size)


if __name__ == '__main__':
    for t in range(1, 7):
        outline(t)
