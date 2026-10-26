# Companion pets sprite sheet

Mode: built-in image_gen

## Initial prompt

Use case: style-transfer.
Asset type: one sprite sheet of three companion pets for a cute cat-themed vertical shooter mobile game.
Input image 1: exact style reference and yellow baby chick identity reference; not a layout to reproduce.
Create exactly 3 pets, left to right fire chick, medic chick, armored chick. Strict 3 columns x 1 row grid on a landscape 3:1 canvas. Three equal square cells with no visible boundaries. Center each complete pet-and-pod assembly in its cell, occupying about 70% of its cell height and width, with generous magenta space; all three same scale, aligned centers. Slightly above front view.
Each pet is a round cute yellow baby chick matching the two yellow chicks in the reference, riding in a tiny cat-ear-shaped flying eggshell pod, with a small exhaust flame directly below.
Left: fire chick, red bandana, small orange flame emblem on pod.
Center: medic chick, tiny white nurse cap with red plus, pink-cream pod with heart.
Right: armored chick, little silver helmet with visor, blue-steel pod with shield emblem.
Style: chunky cute kit matching reference exactly, thick even dark navy outlines, flat colors with one cel-shade step and a small white highlight. Preserve chick facial identity and round body geometry, adapt framing and accessories only as requested. Clean readable silhouettes.
Entire background outside pets: perfectly flat solid pure magenta #FF00FF. No magenta pigment inside pets. No diffuse glow or cast shadow on background. No grid lines, no text, no extra objects, no cropped flame or pod, no extra chicks. Output canvas exactly 3:1 landscape.

## Final correction prompt

Edit this image. Preserve exactly these three chick characters, their accessories, pods, emblems, dark outlines, colors, flame shapes and left-to-right order. Keep the landscape canvas ratio exactly 3:1 and three equal square cells. Center the pets at x=1/6, 1/2, 5/6 of the canvas, y=1/2, scaling each complete chick+pod+flame assembly uniformly to 70% of the square cell height. CRITICAL CHANGE: replace ALL transparent background with fully OPAQUE perfectly flat pure magenta RGB(255,0,255), hex #FF00FF. This is a chroma-key reference plate, NOT a transparent asset. Output must have visible bright magenta background across the whole canvas outside the pets, including between them and around flames. Do not remove the magenta background. No alpha transparency. No gradients, no shadows, no glow on magenta, no grid lines, no text. Preserve the three subjects' identity and art style.

