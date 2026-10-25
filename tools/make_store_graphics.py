"""Google Play graphics: 512px icon and the 1024x500 feature graphic with the
game name (Korean and English) over the generated key art.

Sources: web/icons/Icon-512.png, store/source/feature_raw.png
Output: store/icon_512.png, store/feature_graphic_{ko-KR,en-US}.png
Run: python tools/make_store_graphics.py
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
STORE = ROOT / 'store'
FONT = ROOT / 'assets/fonts/NotoSansKR.ttf'


def font(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_axes([900])
    except Exception:
        pass
    return f


def lettering(text: str, size: int, top=(255, 255, 255), bottom=(255, 214, 90)):
    """Game-style title: gradient fill, thick navy outline, soft shadow."""
    f = font(size)
    stroke = max(4, size // 9)
    box = f.getbbox(text, stroke_width=stroke)
    w, h = box[2] - box[0] + 24, box[3] - box[1] + 24
    origin = (12 - box[0], 12 - box[1])
    outline = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(outline).text(origin, text, font=f, fill=(22, 30, 58, 255),
                                 stroke_width=stroke, stroke_fill=(22, 30, 58, 255))
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).text(origin, text, font=f, fill=255)
    grad = Image.new('RGBA', (w, h))
    gd = ImageDraw.Draw(grad)
    for y in range(h):
        t = y / max(1, h - 1)
        gd.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    shadow = outline.filter(ImageFilter.GaussianBlur(6))
    out = Image.new('RGBA', (w + 8, h + 10), (0, 0, 0, 0))
    out.alpha_composite(Image.eval(shadow, lambda v: v // 2), (6, 8))
    out.alpha_composite(outline, (0, 0))
    out.paste(grad, (0, 0), mask)
    return out


def feature(lang: str, title: str, subtitle: str) -> None:
    art = Image.open(STORE / 'source/feature_raw.png').convert('RGBA')
    # cover 1024x500
    scale = max(1024 / art.width, 500 / art.height)
    art = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
    left = (art.width - 1024) // 2
    top = (art.height - 500) // 2
    art = art.crop((left, top, left + 1024, top + 500))
    # soft glow behind the title for contrast over the clouds
    glow = Image.new('RGBA', art.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((-60, 80, 520, 400), fill=(30, 20, 70, 120))
    art.alpha_composite(glow.filter(ImageFilter.GaussianBlur(40)))
    t = lettering(title, 70 if lang == 'ko' else 76)
    s = lettering(subtitle, 36, top=(255, 255, 255), bottom=(190, 230, 255))
    tx = max(20, 230 - t.width // 2)
    ty = 150 if lang == 'ko' else 140
    art.alpha_composite(t, (tx, ty))
    art.alpha_composite(s, (tx + (t.width - s.width) // 2, ty + t.height - 6))
    out = STORE / f'feature_graphic_{lang_code(lang)}.png'
    art.convert('RGB').save(out)
    print(out, art.size)


def lang_code(lang: str) -> str:
    return 'ko-KR' if lang == 'ko' else 'en-US'


def main() -> None:
    STORE.mkdir(exist_ok=True)
    icon = Image.open(ROOT / 'web/icons/Icon-512.png').convert('RGBA')
    icon.save(STORE / 'icon_512.png')
    print(STORE / 'icon_512.png', icon.size, icon.mode)
    feature('ko', '수호묘 특공대', '고양이 비행 슈팅')
    feature('en', 'Purrtectors', 'Cat Sky Squad')


if __name__ == '__main__':
    main()
