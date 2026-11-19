"""Bake the four district grades as continuous paintings into GPU atlases."""
from pathlib import Path
from math import sin, cos
from PIL import Image, ImageColor

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools/terrain_art/parcel_surfaces.png"
OUTPUT = ROOT / "assets/terrain"
TYPES = ("sand", "grass", "burnt", "river", "riverbed", "oasis")
DISTRICTS = ("forest", "desert", "volcano", "snow")
SLOT = 512
GUTTER = 4
SAMPLE = SLOT - 2 * GUTTER

# Anchors keyed to diffuse energy within *each* original material. The artist's
# hue is mixed back separately so stone, reflections and leaves retain their own color.
GRADES = {
    "sand": (
        "28393b 414945 625947 847353 a29165 c2ad7a d5bf8d",
        "473a49 67474c 875950 a3745b c3936b dcae7f ebce99",
        "312e40 443848 5b4350 765754 906b5d b08c71 cbac89",
        "4c5878 667c9d 839db5 9bb6c8 b2c8d3 c9d8db e0e8e2",
    ),
    "grass": (
        "172f3e 22474b 2c5b54 3d735b 659366 9ab276 c4ca87",
        "223b43 315a53 526f51 718b56 8f9d62 b6b675 d7cb82",
        "292d3b 374348 4b5b50 5e7055 7f865f 9c9d6e b4a97d",
        "344b65 4b7180 67919a 85aba9 a2bfb5 c6d7c7 dce4d0",
    ),
    "burnt": (
        "232637 343443 4a4655 63565e 816363 a9816e e6af83",
        "292838 423745 5c4451 785a5c 967063 ba906f edba83",
        "211f31 322c3e 48394d 674658 8e5360 bc7766 eda47d",
        "2a3148 40455d 565b71 74798a 9898a4 bab4b6 d5c9be",
    ),
    "river": (
        "132c44 1d4359 265b6c 367586 539597 84b9aa c7d2af",
        "19364d 275467 357680 579392 77aba1 a8c2a7 edd3ac",
        "272740 3b3550 4e4262 655470 865f77 b08289 e6b69c",
        "233d5f 355c7a 507e97 689db0 8bb9c6 b6d6d5 dbe9dc",
    ),
    "riverbed": (
        "303c45 4d5053 65615d 867b6d a2967c bab08e cec4a3",
        "4d3b4d 674c57 8b635f a77f6c c09879 d5b48c e4caa5",
        "2c2b3d 443b47 60535a 796866 928379 b2a18e cfb99b",
        "465670 5c718a 798c9f 95a6b2 b0bec3 c8d0cf dde1d9",
    ),
}
HUE_MIX = {
    "sand": (.055, .23, .03, .008),
    "grass": (.11, .19, .055, .04),
    "burnt": (.43, .41, .54, .22),
    "river": (.29, .33, .18, .2),
    "riverbed": (.11, .26, .07, .055),
}


def rgb_points(kind, biome):
    return [ImageColor.getrgb("#" + stop) for stop in GRADES[kind][biome].split()]


def graded(source, kind, biome):
    """Keep the original pixel-cluster drawing, change its materials' light ramps."""
    # The oasis combines two families. Classify its shore versus its water by hue.
    palettes = {name: rgb_points(name, biome) for name in GRADES}
    limits = [18, 45, 73, 104, 143, 191, 237]
    pixels = []
    for y in range(source.height):
        for x in range(source.width):
            r, g, b = source.getpixel((x, y))
            family = kind
            if kind == "oasis":
                if g - r > 13 and b > r + 3:
                    family = "river"
                elif g > b * 1.35 and g > r * .85:
                    family = "grass"
                else:
                    family = "sand"
            value = r * .29 + g * .56 + b * .15
            # The authored sand starts with golden light, most of its pixels are near
            # mid-high values. Wet forest sand and volcanic ash need a lower key.
            if family == "sand" and biome in (0, 2):
                value = value * .70 - 10
            elif family == "sand" and biome == 3:
                value = value * .75 + 8
            if family == "river" and kind == "oasis":
                value += 12
            index = next((i for i in range(6) if value < limits[i + 1]), 5)
            fraction = max(0, min(1, (value - limits[index]) / (limits[index + 1] - limits[index])))
            lo, hi = palettes[family][index:index + 2]
            keep = HUE_MIX[family][biome]
            channel = [round((a + (c - a) * fraction) * (1 - keep) + raw * keep)
                       for a, c, raw in zip(lo, hi, (r, g, b))]
            pixels.append(tuple(channel))
    output = Image.new("RGB", source.size)
    output.putdata(pixels)
    return output


def forest_litter(soil, grass, sand):
    """Catch moss in the troughs of the damp sand, with sparse fern litter."""
    mask = Image.new("L", soil.size)
    weights = []
    for y in range(soil.height):
        v = (y + 0.5) / soil.height
        for x in range(soil.width):
            u = (x + 0.5) / soil.width
            r, g, b = sand.getpixel((x, y))
            # Vary along the painted banks. Restrict the lit sand and leave the
            # open center of each ridge easy to read.
            bank = .52 * sin(u * 13.86 + sin(v * 15.37)) + .36 * cos(u * 9.58 + v * 21.17)
            shadow = max(0.0, min(1.0, (165 - (r * .3 + g * .55 + b * .15)) / 41))
            reed = max(0.0, min(1.0, (bank - .02) * 2.5))
            weights.append(round(shadow * reed * 185))
    mask.putdata(weights)
    return Image.composite(grass, soil, mask)


def padded(tile):
    output = Image.new(tile.mode, (SLOT, SLOT))
    end = SLOT - GUTTER
    output.paste(tile, (GUTTER, GUTTER))
    output.paste(tile.crop((0, 0, 1, SAMPLE)).resize((GUTTER, SAMPLE)), (0, GUTTER))
    output.paste(tile.crop((SAMPLE - 1, 0, SAMPLE, SAMPLE)).resize((GUTTER, SAMPLE)), (end, GUTTER))
    output.paste(output.crop((0, GUTTER, SLOT, GUTTER + 1)).resize((SLOT, GUTTER)), (0, 0))
    output.paste(output.crop((0, end - 1, SLOT, end)).resize((SLOT, GUTTER)), (0, end))
    return output


def source_tile(sheet, index):
    """Read each painted texel once at the source sheet's native resolution."""
    w, h = sheet.width // 3, sheet.height // 2
    x, y = index % 3 * w, index // 3 * h
    inset_x, inset_y = round(w * GUTTER / SLOT), round(h * GUTTER / SLOT)
    face = sheet.crop((x + inset_x, y + inset_y, x + w - inset_x, y + h - inset_y))
    if face.size == (SAMPLE, SAMPLE):
        return face
    return face.resize((SAMPLE, SAMPLE), Image.Resampling.LANCZOS)


def bake_low_river():
    """Paint submerged gravel and wet gravel bars; alpha stores depth for the moving light."""
    with Image.open(OUTPUT / "sheet_river_top.png") as water, Image.open(OUTPUT / "sheet_riverbed_top.png") as bed:
        atlas = Image.new("RGBA", water.size)
        for region in range(4):
            left, top = (region % 2) * SLOT, (region // 2) * SLOT
            box = (left + GUTTER, top + GUTTER, left + SLOT - GUTTER, top + SLOT - GUTTER)
            river = water.crop(box).convert("RGB").load()
            gravel = bed.crop(box).convert("RGB").load()
            shoal = Image.new("RGBA", (SAMPLE, SAMPLE))
            pixels = shoal.load()
            for y in range(SAMPLE):
                v = y / SAMPLE
                for x in range(SAMPLE):
                    u = x / SAMPLE
                    stone = gravel[x, y]
                    ripple = river[x, y]
                    # Broad braided pools have a broken, pixel-stepped shoreline.
                    depth = (.47 * sin(19 * u + 8 * v + 2.6 * sin(9 * v))
                             + .33 * cos(14 * v - 11 * u) + .17 * sin(28 * v + 18 * u)
                             + .11 * sin(61 * u - 33 * v) - (sum(stone) / 3 - 100) / 245 + .19)
                    wet = min(1, max(0, (depth + .08) * 2.7))
                    mix = .12 + .60 * wet
                    rim = 8 if -.09 < depth < -.04 else 0
                    color = tuple(min(255, round(s * (.82 - .16 * wet) * (1 - mix) + r * mix + rim))
                                  for s, r in zip(stone, ripple))
                    pixels[x, y] = (*color, 32 + round(wet * 223))
            atlas.paste(padded(shoal), (left, top))
        atlas.save(OUTPUT / "sheet_river_low_top.png", optimize=True)


def main():
    with Image.open(SOURCE) as image:
        sheet = image.convert("RGB")
    for index, kind in enumerate(TYPES):
        atlas = Image.new("RGB", (SLOT * 2, SLOT * 2))
        sample = source_tile(sheet, index)
        for district, name in enumerate(DISTRICTS):
            colored = graded(sample, kind, district)
            if kind == "sand" and name == "forest":
                fern = source_tile(sheet, TYPES.index("grass"))
                colored = forest_litter(colored, graded(fern, "grass", 0), sample)
            colored = colored.quantize(colors=128, method=Image.Quantize.MEDIANCUT,
                                      dither=Image.Dither.NONE).convert("RGB")
            atlas.paste(padded(colored), (district % 2 * SLOT, district // 2 * SLOT))
        atlas.save(OUTPUT / f"sheet_{kind}_top.png", optimize=True)
    bake_low_river()


if __name__ == "__main__":
    main()
