# Menu art v8

2026-10-18. Built-in `image_gen` generated 17 separate assets for the requested lobby, supply and growth overhaul. No API key was used. No sprite sheet/grid, UI text, UI frame or button image was generated. `generation.json` records original output paths and prompts; `manifest.json` records SHA-256, original dimensions and normalized safe sampling bounds.

Three full-bleed backgrounds: `hangar`, `supply`, `growth`. Fourteen alpha objects: three player ships, three supply illustrations, two navigation badges and six equipment slot illustrations. The original PNG bytes are copied without bitmap editing. The menu renderer preserves each object's aspect ratio. Each visible silhouette (alpha >=8) has at least 24 source pixels of clearance. Sampling includes another 12 pixels of padding around the visible silhouette. A render-time alpha remap removes generated 1..7/255 residue while retaining opaque colors and antialiased edges. No other grid cell exists to intrude.

Panels and buttons use a continuous Canvas path and solid face, highlight, lower edge and outline. They do not sample or stretch these PNGs. Existing generated battle assets remain in `toon_v7`.

Run `python tools/qa/check_menu_art.py` and `flutter test test/menu_panel_test.dart`. The browser matrix and implementation record are in `docs/MENU_V8_IMPLEMENTATION.md`.
