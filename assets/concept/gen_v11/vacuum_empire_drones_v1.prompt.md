# Vacuum Empire drone sheet

Mode: built-in image_gen
References: ref_style.png; ref_battle.png

## Initial prompt

Use case: style-transfer
Asset type: Shootingstar game sprite sheet, transparent PNG.
Input images: Image 1 (ref_style.png) is the primary art-style reference; Image 2 (ref_battle.png) is the supporting in-game readability and style reference. Preserve the visual language of both references, while making the five new requested enemies. Do not reproduce their hero, cats, interface, scenery or existing sprite sheet contents.
Primary request: EXACTLY FIVE distinct Vacuum Empire enemy drones, arranged in a top row of THREE and a bottom row of TWO centered, each in its own invisible cell. Wide landscape canvas approximately 3:2. Similar visual size for the five main sprites, wide fully transparent gaps and generous outer padding, no cell lines.
Top row left to right:
1. Cucumber mine-layer: green cucumber-shaped bomber with little bomb racks, toxic green main body and purple mechanical details.
2. Dust-bunny splitter: angry fluffy gray dust ball monster, one glowing pink eye, tiny jets. A chunky scalloped fluffy silhouette, not detailed fur.
3. Long-range sniper drone: slim spray-nozzle rifle drone with a long thin barrel pointing straight toward the TOP edge, and a scope eye.
Bottom row left to right:
4. Big robot-vacuum carrier mothership: large round robot vacuum hull with a hangar hatch and small docked drones attached within its silhouette. Its large-ship identity comes from its broad round hull; render at similar sheet footprint to the other enemies.
5. Vacuum-hose kamikaze: vacuum cleaner head with open suction mouth at its TOP/front edge and hose tail trailing DOWN behind it, poised to charge forward.
Style: exactly match the supplied references' Survivor.io-family casual mobile shooter art: thick even dark navy outlines, bold flat saturated colors, ONE simple cel-shade step, small white highlights, top-left lighting, chunky clean silhouettes readable at 60 pixels. Purple, magenta, dark gray and toxic green faction colors with glowing pink or red eyes/cores contrasting with the orange-yellow hero.
View: strict orthographic TOP-DOWN, seen directly from above, no perspective or isometric tilt. EVERY vehicle FRONT points straight to the TOP of the image; all forward barrels, mouths and fronts face UP; jets and tails behind point DOWN. Eyes can be on upper hull surfaces.
Background: genuinely fully transparent PNG alpha, including all gaps and canvas corners. No opaque backdrop, no checkerboard drawn into image.
Avoid: cats, humans, text, letters, numbers, watermarks, shadows cast outside sprites, scenery, ground, panels, frames, extra free-floating objects. No gradients, excessive mechanical detailing or photorealistic rendering.

## Final refinement prompt

Edit this five-drone sprite sheet. Preserve exactly these FIVE designs, colors, identities, thick dark outlines, strict overhead view and all upward-facing vehicle fronts. Make one correction pass for production sprite layout and cutout cleanliness:
Use a 1536x1024 transparent canvas, top row of three evenly spaced sprites, bottom row of two centered sprites. Scale each complete sprite to fit fully inside a roughly 340x350 pixel box, with comparable overall visual size. In particular REDUCE the oversized round carrier to match the others' visual size. Leave at least 100 pixels of completely transparent clear space between every main sprite and at least 70 pixels of clear outer margin. Keep all barrels, racks and hose tails inside their own boxes.
Eliminate exterior diffuse glow, colored haze and shadow. Pink glowing eyes must remain bright inside their outlines, but nothing may glow onto the empty canvas. All exterior pixels and all inter-sprite gaps must be fully transparent alpha zero, with opaque sprite interiors and crisp antialiased boundaries. Do not draw a black background or checkerboard.
Keep five main subjects: cucumber mine-layer with bomb racks; fluffy gray one-eyed dust splitter with tiny jets; spray-nozzle sniper with long upward barrel and scope eye; round vacuum carrier with hatch and small docked drones; vacuum-head kamikaze with open mouth at TOP and hose tail trailing DOWN. Preserve saturated purple, magenta, gray, toxic green and pink/red cores. Simple flat colors with one cel-shade step, small white highlights, top-left light. No additional subjects, no cats, humans, text, labels, frames, scenery or watermark. Output transparent PNG.

