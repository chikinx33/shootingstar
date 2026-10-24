"""Analyze alpha islands into sampling metadata; never modify the PNG atlas."""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image

root = Path(__file__).resolve().parents[2]
atlas = root / 'assets/art/toon_v7/icons.png'
with Image.open(atlas) as image:
    alpha = image.getchannel('A')
    regions = []
    for cell in range(64):
        # Generated dimensions need not be divisible by eight (1254px here).
        # Match Flutter's fractional cell grid instead of accumulating floor drift.
        left, top = math.ceil(cell % 8 * image.width / 8), math.ceil(cell // 8 * image.height / 8)
        right, bottom = math.floor((cell % 8 + 1) * image.width / 8), math.floor((cell // 8 + 1) * image.height / 8)
        cell_w, cell_h = right - left, bottom - top
        pixels = list(alpha.crop((left, top, right, bottom)).get_flattened_data())
        seen = bytearray(len(pixels))
        largest = []
        for start, value in enumerate(pixels):
            if seen[start] or value < 32:
                continue
            seen[start] = 1
            stack, component = [start], []
            while stack:
                pos = stack.pop(); component.append(pos)
                x, y = pos % cell_w, pos // cell_w
                for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < cell_w and 0 <= ny < cell_h):
                        continue
                    nxt = ny * cell_w + nx
                    if not seen[nxt] and pixels[nxt] >= 32:
                        seen[nxt] = 1; stack.append(nxt)
            if len(component) > len(largest):
                largest = component
        assert largest, cell
        xs, ys = [p % cell_w for p in largest], [p // cell_w for p in largest]
        bounds = [left + max(0, min(xs) - 2), top + max(0, min(ys) - 2),
                  left + min(cell_w, max(xs) + 3), top + min(cell_h, max(ys) + 3)]
        regions.append(bounds)
result = {'atlasSha256': hashlib.sha256(atlas.read_bytes()).hexdigest(),
          'purpose': 'Runtime source rectangles; original PNG unchanged', 'regions': regions}
(root / 'assets/art/ui_icon_regions.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(f'Analyzed {len(regions)} icon regions; PNG SHA-256 {result["atlasSha256"]}')
