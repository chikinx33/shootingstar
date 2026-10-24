"""Drop CJK ideographs (Hanja) from the bundled Korean font.

Keeps every modern Hangul syllable (11,172), jamo, Latin, digits, symbols,
all OpenType features and the full variable weight axis, so the game renders
exactly as before at about half the size. Any ideograph the game's own text
uses is kept as well.

Needs fontTools (installed at D:/Programs/pylib):
  PYTHONPATH=D:/Programs/pylib python tools/subset_font.py <full NotoSansKR.ttf>
The full font is in git history before v12.5.1 (assets/fonts/NotoSansKR.ttf).
"""
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/fonts/NotoSansKR.ttf'


def ideograph(cp: int) -> bool:
    return 0x3400 <= cp <= 0x9FFF or 0xF900 <= cp <= 0xFAFF or cp >= 0x20000


def main() -> None:
    source = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    used = set()
    for path in (ROOT / 'lib').rglob('*.dart'):
        used |= {ord(c) for c in path.read_text(encoding='utf-8')}
    font = TTFont(source)
    keep = [cp for cp in font.getBestCmap() if not ideograph(cp) or cp in used]
    options = subset.Options()
    options.layout_features = ['*']
    options.name_IDs = ['*']
    options.name_languages = ['*']
    options.notdef_outline = True
    options.glyph_names = False
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=keep)
    subsetter.subset(font)
    font.save(OUT)
    print(f'{source.stat().st_size // 1024}K -> {OUT.stat().st_size // 1024}K, '
          f'{len(keep)} code points')


if __name__ == '__main__':
    main()
