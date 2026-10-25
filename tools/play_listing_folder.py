"""Builds store/play/ (the folder layout Game-Management/play/store_listing.py
reads) from store/listing.md and the store graphics.

    python tools/play_listing_folder.py
"""
import pathlib
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]
STORE = ROOT / 'store'
OUT = STORE / 'play'


def section(text: str, head: str) -> str:
    part = text.split(f'## {head}', 1)[1].split('\n## ', 1)[0]
    return part


def field(part: str, label: str) -> str:
    return re.search(rf'\*\*{re.escape(label)}[^*]*:\*\*\s*(.+)', part).group(1).strip()


def full(part: str) -> str:
    label = '**Full description:**' if '**Full description:**' in part else '**자세한 설명:**'
    return part.split(label, 1)[1].strip()


def main() -> None:
    text = (STORE / 'listing.md').read_text(encoding='utf-8').replace('\r\n', '\n')
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / 'screenshots').mkdir(parents=True)
    for short, head, title, desc in (
        ('en', 'en-US', 'App name', 'Short description'),
        ('ko', 'ko-KR', '앱 이름', '간단한 설명'),
    ):
        part = section(text, head)
        (OUT / f'title_{short}.txt').write_text(field(part, title), encoding='utf-8')
        (OUT / f'short_{short}.txt').write_text(field(part, desc), encoding='utf-8')
        (OUT / f'full_{short}.txt').write_text(full(part), encoding='utf-8')
        shutil.copy(STORE / f'feature_graphic_{head}.png', OUT / f'feature_{short}.png')
        shutil.copy(STORE / 'icon_512.png', OUT / f'icon_{short}.png')
        for shot in sorted((STORE / 'screenshots' / head).glob('*.png')):
            shutil.copy(shot, OUT / 'screenshots' / f'{short}_{shot.name}')
    print('wrote', OUT)


if __name__ == '__main__':
    main()
