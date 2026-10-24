from pathlib import Path

STYLE = (
    "Strict orthographic TOP-DOWN map view (straight down, like a vertical scrolling shooter background), "
    "cozy cartoon small-town style matching image 2 and the house map in image 3 (soft flat colors, gentle cel "
    "shading, thin soft outlines), this neighborhood sits on a sunset hill in early autumn so trees have warm "
    "orange, gold and red leaves mixed with green, deliberately LOW CONTRAST and slightly muted so bright cats, "
    "enemies and glowing bullets stay readable on top. No people, no animals, no vehicles moving, no text, no "
    "letters, no signs with writing, no watermark. Portrait 2:3 image."
)
LOT = (
    "Top-down lot of ONE building in a small town, seen strictly from above, filling the frame: {what} "
    "The front gate faces the bottom of the image where a residential street ends. Include the roof, yard, "
    "fence and small details that tell who lives or works there. "
)
houses = {
    'h2_0_store': "a small 24-hour corner convenience store with a flat rooftop and air-conditioner units, a tiny parking spot, an outdoor plastic table with a parasol, stacked drink crates and snack boxes by the door.",
    'h2_1_vet': "a small animal clinic building with a mint-green roof, a fenced dog-run yard with a little kennel, a bone-shaped bench, potted plants and a paw-print stepping-stone path.",
    'h2_2_dojo': "a taekwondo dojo building with a blue roof, an outdoor training yard with soft mats, wooden practice dummies and stacked kick pads.",
    'h2_3_laundry': "a small dry-cleaner shop with laundry lines full of colorful clothes and white sheets drying on the rooftop and in the yard, a few laundry baskets.",
    'h2_4_daycare': "a colorful daycare building with a sunny yellow roof, a little playground with a slide, a sandbox, tiny chairs and a small flower garden.",
    'h2_5_camper': "a small wooden house with a big parked camper van, a pitched tent, a campfire ring with logs, a hammock between two trees.",
    'h2_6_farm': "a farmhouse beside a large vegetable garden with neat rows, tomato vines on sticks, a plastic greenhouse tunnel, pumpkins and a cute scarecrow.",
    'h2_7_library': "a cozy brick library with a green roof, a reading garden with benches, book carts and round hedges.",
    'h2_8_fire': "a small fire station with a red roof, a wide garage with a parked red fire truck, a training tower and coiled hose reels.",
    'h2_9_catcafe': "a cozy two-story cat cafe house with an orange roof and a cat-shaped skylight, a terrace with cat towers, cushions and little cat beds, a garden full of flowers.",
}
for key, what in houses.items():
    Path(f'p_{key}.txt').write_text(LOT.format(what=what) + STYLE, encoding='utf-8')
Path('p_h2_street.txt').write_text(
    "Seamless vertical scrolling street tile for a cozy small Korean-style neighborhood on a gentle hill: a calm "
    "two-lane residential road running straight from bottom to top through the center, sidewalks, small front "
    "gardens, stone walls, hedges, autumn trees, parked bicycles, little fences, manholes, crosswalk stripes. The "
    "top and bottom edges must continue seamlessly when stacked. " + STYLE,
    encoding='utf-8',
)
OWN = (
    "Character sheet of FIVE simple cute chibi human neighbors for a casual mobile game, in exactly the same very "
    "simple design language as the neighbors in image 3 and the cats in image 2 (big round heads, tiny dot eyes, "
    "small mouth, minimal details, thick dark outlines, flat colors), bust portraits arranged in one row with wide "
    "transparent gaps, same size: {who} Friendly warm expressions. Wide 2:1 image, fully transparent background "
    "(PNG alpha), no text, no watermark."
)
Path('p_h2_owners_a.txt').write_text(OWN.format(who=(
    "1) JIHO a young convenience-store part-timer with messy hair, a green store vest and a sleepy smile, "
    "2) DR. YOON a veterinarian woman with short hair, a white coat, a stethoscope and a paw-print badge, "
    "3) the TAEKWONDO MASTER a bald strong man in a white dobok with a black belt, "
    "4) the LAUNDRY GRANDPA an old man with round glasses, an apron and a clothes hanger, "
    "5) the DAYCARE DIRECTOR a kind woman with a ponytail and an apron with a sun patch.")), encoding='utf-8')
Path('p_h2_owners_b.txt').write_text(OWN.format(who=(
    "1) SORA a traveler woman with a bucket hat and a small camera, "
    "2) the FARMER UNCLE with a straw hat and a towel around his neck, "
    "3) the LIBRARIAN with glasses and a cardigan holding a book, "
    "4) the FIREFIGHTER a young woman with a helmet and an orange uniform, "
    "5) the CAT CAFE OWNER a young barista with an apron and a cat-ear headband.")), encoding='utf-8')
print('prompts ok')
