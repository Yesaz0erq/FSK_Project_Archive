"""Draw the district floor paintings from blank swatches and pack the game atlases.

Coordinates here are brush pixels. Each 252-pixel painting covers several
parcels. A four-texel bleed carries the adjacent repeat into the GPU mip chain.
"""

from math import pi
from pathlib import Path
from random import Random

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/terrain"
N, SLOT, GUTTER = 252, 512, 4
PERIOD = 2 * pi
Y, X = np.mgrid[:N, :N] / N

# Seven separate pigment families, mixed for the skylight of the four districts.
# Index order: occlusion, shadow, shadow-facing plane, local colour, lifted
# plane, light edge, rare glint. The rear planes stay close in value.
PIGMENTS = {
    "grass": [
        "182a3b 193d46 225553 30695b 487e5d 85ac69 c8ce7d",
        "242b3a 364643 495947 606e48 778447 a3a65a d7c47c",
        "282536 353d42 49544d 5a6351 747c53 99a063 caca8c",
        "292f49 394e65 4c6975 628683 80a79b abc5b4 d6e1c8",
    ],
    "sand": [
        "34313e 4e4547 695948 806c52 a68c66 ceb184 e2cda1",
        "482e43 63414c 885653 a87159 c68f65 e7b778 f6d498",
        "302638 493547 64484f 805954 a57c60 c79a74 e2b78b",
        "38425d 516580 687d94 8193a3 a3b5bb c6d3ce e6e9d8",
    ],
    "burnt": [
        "201e31 2b293e 40394a 534555 685366 916d78 dc9b77",
        "271e32 352a3f 493949 604950 775956 a57b67 efac76",
        "1e1c31 2b263e 443149 593e50 724d59 a46668 f1a276",
        "252a40 353c53 465068 59617b 717e90 99a8b3 ccd6c9",
    ],
    "river": [
        "15243e 16334c 19485d 205c71 337b86 6aa8a0 d2d6ad",
        "1b2e43 204759 2c6069 39797b 54978e 98bca3 e8d7ab",
        "262239 33314b 49405e 604d6a 7b6078 ba8590 eac1a8",
        "222f4b 304761 3a6281 4e7f98 6ca3b1 a1c9c9 e7e9d6",
    ],
    "riverbed": [
        "292c3d 3b3c47 555056 6d6462 887d70 a89b82 c8b99a",
        "392b3d 543d49 705051 926758 ad856a d1a579 e5c494",
        "2b2638 403342 584651 715b60 8b736f ab9280 cab699",
        "343d58 4b5972 62738a 7b8d9b 98a9b0 b8c8c5 d7dfce",
    ],
}
FLOWERS = [(194, 144, 131), (203, 158, 101), (178, 118, 108), (177, 170, 208)]


def inks(kind, district):
    return [tuple(bytes.fromhex(s)) for s in PIGMENTS[kind][district].split()]


def noise(seed, width, height):
    """Toroidal low-frequency wash used to group several strokes under one value."""
    grid = np.random.default_rng(seed).uniform(-1, 1, (height, width))
    u, v = X * width, Y * height
    ix, iy = u.astype(int), v.astype(int)
    dx, dy = u - ix, v - iy
    dx, dy = dx * dx * (3 - 2 * dx), dy * dy * (3 - 2 * dy)
    a = grid[iy, ix] * (1 - dx) + grid[iy, (ix + 1) % width] * dx
    b = grid[(iy + 1) % height, ix] * (1 - dx) + grid[(iy + 1) % height, (ix + 1) % width] * dx
    return a * (1 - dy) + b * dy


class Swatch:
    def __init__(self, image, palette):
        self.im = image
        self.draw = ImageDraw.Draw(self.im)
        self.palette = palette

    @classmethod
    def wash(cls, values, palette):
        # Mix neighbouring pigments on the palette in quarter pans. Keep crisp
        # brush edges without turning every wash into a chain of contour rings.
        value = np.clip(np.round(values * 4) / 4, 0, 6)
        low = value.astype(int)
        gain = (value - low)[..., None]
        colours = np.asarray(palette)
        underpaint = colours[low] * (1 - gain) + colours[np.minimum(6, low + 1)] * gain
        return cls(Image.fromarray(underpaint.round().astype("uint8")), palette)

    def stamp(self, xy, colour, line=False):
        """Continue brush shapes through both seams in each painting."""
        colour = self.palette[colour] if isinstance(colour, int) else colour
        x, y = zip(*xy)
        shifts_x = [0] + ([N] if min(x) < 0 else []) + ([-N] if max(x) >= N else [])
        shifts_y = [0] + ([N] if min(y) < 0 else []) + ([-N] if max(y) >= N else [])
        brush = self.draw.line if line else self.draw.polygon
        for dx in shifts_x:
            for dy in shifts_y:
                brush([(round(px + dx), round(py + dy)) for px, py in xy], fill=colour)

    def mark(self, x, y, offsets, colour, scale=1, mirror=1):
        self.stamp([(x + dx * scale * mirror, y + dy * scale) for dx, dy in offsets], colour)


def turf(district):
    palette = inks("grass", district)
    rng = Random(407 + 17 * district)
    wash = 0.71 * noise(283 + district, 5, 6) + 0.28 * noise(422 + district, 13, 12)
    ledges = np.sin(PERIOD * (Y * 3 - X + 0.19 * np.sin(PERIOD * (X + Y))))
    base = 2.45 + 1.48 * wash + 0.24 * ledges + 0.12 * noise(610 + district, 24, 30)
    canvas = Swatch.wash(base, palette)
    # A tuft grows out of a bent shelf. Each blade has a clipped broad face,
    # a shaded half and an asymmetric tip, drawn together as one silhouette.
    for _ in range(105):
        cx, cy = rng.randrange(N), rng.randrange(N)
        light = wash[cy, cx]
        if light < -0.38:
            continue
        for _ in range(rng.randint(3, 7)):
            x, y = cx + rng.gauss(0, 6.5), cy + rng.gauss(0, 3.8)
            size = rng.uniform(0.64, 1.45)
            turn = rng.choice([-1, 1])
            face = 3 if light < 0.06 else 4
            if district == 1:  # drought rosettes with blunt, waxy paddles
                canvas.mark(
                    x,
                    y,
                    [(-6, -3), (-2, -2), (-3, -7), (0, -5), (1, -2), (4, -6), (6, -6), (4, -1), (1, 1), (-3, 1)],
                    face - 1,
                    size,
                    turn,
                )
                canvas.mark(x, y, [(0, 0), (4, -6), (6, -6), (4, -3)], face + 1, size, turn)
            elif district == 3:  # hooked frost grass catches a white tip
                canvas.mark(
                    x,
                    y,
                    [(-6, -2), (-3, -2), (-1, 0), (1, -6), (4, -9), (3, -4), (1, 1), (-2, 2)],
                    face,
                    size,
                    turn,
                )
                canvas.mark(x, y, [(1, -5), (4, -9), (3, -6)], 5, size, turn)
            else:
                canvas.mark(
                    x,
                    y,
                    [
                        (-7, -3),
                        (-6, -4),
                        (-2, -2),
                        (-4, -7),
                        (-2, -7),
                        (0, -3),
                        (2, -6),
                        (6, -9),
                        (4, -3),
                        (2, 0),
                        (-1, 2),
                        (-4, 1),
                    ],
                    face - 1,
                    size,
                    turn,
                )
                canvas.mark(x, y, [(0, 0), (2, -5), (6, -9), (4, -4), (2, -1)], face + 1, size, turn)
                if rng.random() < 0.27:
                    canvas.mark(x, y, [(3, -5), (6, -9), (5, -6)], 5, size, turn)
        if light > 0.12 and rng.random() < 0.19:
            for _ in range(3):
                x, y = cx + rng.randrange(-8, 8), cy + rng.randrange(-4, 4)
                canvas.mark(x, y, [(-2, 0), (0, -2), (2, -1), (1, 1)], FLOWERS[district])
                canvas.mark(x, y, [(0, -2), (1, -2), (0, -1)], 6)
    return canvas.im


def sand(district):
    pal = inks("sand", district)
    rng = Random(692 + district)
    # A shallow scarp has a long gently lit incline and a short dark slip face.
    # Bend the whole row, occasionally splitting it into two smaller ridges.
    turn = 0.29 * np.sin(PERIOD * (X + 0.12 * district)) + 0.16 * np.sin(PERIOD * (2 * X - Y))
    ridge = np.mod(4 * Y - X + turn + 0.29 * noise(31 + district, 4, 3), 1)
    broad = noise(75 + district, 4, 5)
    gust = np.clip((noise(367 + district, 5, 4) + 0.22) * 1.75, 0, 1)
    slope = np.where(ridge > 0.55, (ridge - 0.55) * 1.9, -np.maximum(0, 0.31 - ridge) * 3.0)
    value = 2.92 + 0.58 * broad + slope * (0.27 + 0.80 * gust)
    value += 0.18 * noise(590 + district, 16, 14) + 0.11 * noise(154 + district, 33, 27)
    value[(ridge > 0.971) & (gust > 0.64)] += 0.53
    # The uninterrupted broad faces keep the working area readable.
    canvas = Swatch.wash(value, pal)
    # The side of a bank breaks into wedge-shaped scoops at oblique angles.
    # Dark troughs collect small flat stones; isolated lips catch grazing light.
    for _ in range(105):
        x, y = rng.randrange(N), rng.randrange(N)
        length = rng.randrange(7, 21)
        if ridge[y, x] > 0.48:
            continue
        p = int(round(value[y, x]))
        lean = rng.choice([-1, 1])
        canvas.mark(
            x,
            y,
            [
                (-length, 0),
                (-length * 0.33, -2),
                (2, -3),
                (length * 0.62, -6),
                (length, -7),
                (length * 0.60, -4),
                (3, 0),
                (-length * 0.47, 1),
            ],
            max(1, p - 1),
            0.78,
            lean,
        )
        if rng.random() < 0.56:
            canvas.mark(
                x, y, [(-length * 0.28, -2), (2, -4), (length * 0.61, -6), (4, -3)], min(5, p + 1), 0.78, lean
            )
    for _ in range(75):
        x, y = rng.randrange(N), rng.randrange(N)
        for _ in range(rng.randrange(2, 6)):
            px, py = x + rng.gauss(0, 5), y + rng.gauss(0, 2.2)
            length = rng.uniform(1.5, 5.5)
            canvas.mark(px, py, [(0, 0), (length, -1), (length + 1, -1), (2, 1)], 2)
            if rng.random() < 0.45:
                canvas.mark(px, py, [(0, -1), (length, -2), (length, -1)], 4)
    for _ in range(24):
        x, y = rng.randrange(N), rng.randrange(N)
        if district == 0:
            # Curled leaf litter embedded in the forest's exposed silt.
            canvas.mark(x, y, [(-6, 0), (-3, -3), (0, -4), (6, -4), (3, -1), (-1, 1)], (90, 81, 63))
            canvas.mark(x, y, [(-5, 0), (0, -3), (4, -3), (1, -1)], (137, 119, 77))
        elif district == 1:
            # Raised salt scales in the lee of a dune.
            for j in range(rng.randint(2, 4)):
                pebble(canvas, x + rng.gauss(0, 3), y + rng.gauss(0, 2), rng.uniform(0.40, 0.78), 4)
        elif district == 2:
            canvas.mark(x, y, [(-5, 1), (-5, -1), (1, -4), (6, -4), (5, -2), (-1, 2)], (74, 56, 69))
            canvas.mark(x, y, [(-5, -1), (1, -4), (4, -4), (0, -2)], (116, 86, 87))
        else:
            # Pinched ends of small angular pressure cracks in thawing snow.
            canvas.mark(x, y, [(-8, 2), (-2, -2), (2, -2), (7, -6), (4, -2), (0, 0), (-3, 0)], 2)
            canvas.mark(x, y, [(-5, 0), (-2, -3), (1, -3), (-1, -2)], 5)
    return canvas.im


def pebble(canvas, x, y, size, face, mirror=1):
    # Water-worn shale has an offset upper plane and a thin undercut.
    canvas.mark(
        x,
        y,
        [(-5, 1), (-5, -1), (-2, -3), (3, -3), (6, -1), (5, 1), (1, 3), (-3, 3)],
        max(0, face - 2),
        size,
        mirror,
    )
    canvas.mark(x, y, [(-5, 0), (-3, -2), (0, -4), (4, -3), (6, -1), (2, 1), (-2, 1)], face, size, mirror)
    canvas.mark(x, y, [(-4, -1), (-1, -4), (2, -4), (0, -2)], min(6, face + 1), size, mirror)


def gravel(district):
    pal = inks("riverbed", district)
    rng = Random(315 + district)
    bars = (
        noise(271 + district, 4, 5) * 0.65
        + np.sin(PERIOD * (3 * Y - X + 0.23 * np.sin(PERIOD * (X + 2 * Y)))) * 0.42
    )
    canvas = Swatch.wash(2.7 + bars * 1.32 + 0.14 * noise(516, 20, 24), pal)
    for _ in range(110):
        x, y = rng.randrange(N), rng.randrange(N)
        if bars[y, x] < -0.42:
            continue
        for _ in range(rng.randrange(2, 6)):
            px, py = x + rng.gauss(0, 6.1), y + rng.gauss(0, 3.3)
            pebble(canvas, px, py, rng.uniform(0.33, 1.10), rng.choice([2, 3, 3, 4]), rng.choice([-1, 1]))
    return canvas.im


def charcoal(district):
    pal = inks("burnt", district)
    rng = Random(93 + district)
    wash = 0.74 * noise(319 + district, 6, 6) + 0.26 * noise(321, 11, 10)
    canvas = Swatch.wash(2.5 + 1.65 * wash + 0.2 * noise(506, 17, 16), pal)
    # Columnar rock splits into offset books. Group them along faults, leaving
    # intervals of unbroken basalt between the hot fissures.
    for _ in range(65):
        cx, cy = rng.randrange(N), rng.randrange(N)
        for j in range(rng.randrange(2, 6)):
            x, y = cx + j * rng.uniform(2, 4), cy - j * rng.uniform(2, 5)
            s = rng.uniform(0.55, 1.45)
            canvas.mark(x, y, [(-9, 1), (-5, -3), (4, -5), (10, -3), (6, 1), (-2, 4), (-7, 4)], 1, s)
            canvas.mark(x, y, [(-9, 0), (-4, -4), (4, -6), (10, -4), (5, -1), (-3, 2)], rng.choice([2, 3, 4]), s)
            canvas.mark(x, y, [(-8, 0), (-4, -4), (1, -5), (-2, -3)], 4, s)
        if rng.random() < 0.20:
            canvas.mark(cx, cy, [(0, 3), (6, 1), (11, -1), (13, -4), (14, -4), (13, 0), (8, 2), (2, 4)], 5)
            canvas.mark(cx, cy, [(7, 1), (12, -2), (10, 1)], 6)
    return canvas.im


def current(district):
    pal = inks("river", district)
    rng = Random(863 + district)
    # Broad planes of reflected canopy break against narrow shoals of open sky.
    wash = 0.66 * noise(219 + district, 3, 11) + 0.34 * noise(448 + district, 6, 22)
    channel = np.sin(PERIOD * (Y * 6 - X + 0.16 * np.sin(PERIOD * (X + Y)))) * 0.13
    canvas = Swatch.wash(2.30 + 1.65 * wash + channel + 0.17 * noise(119 + district, 16, 28), pal)
    # Reflections nest in interrupted wedges. Their distal edge is broad
    # enough to read as sky, then narrows to a one-brush-pixel filament.
    for _ in range(33):
        x, y = rng.randrange(N), rng.randrange(N)
        if wash[y, x] < -0.13:
            continue
        width = rng.randint(12, 32)
        canvas.mark(
            x,
            y,
            [
                (-width, 2),
                (-width * 0.37, 0),
                (-width * 0.22, -2),
                (width * 0.27, -2),
                (width * 0.52, -4),
                (width, -5),
                (width * 0.68, -2),
                (width * 0.29, 0),
                (-width * 0.10, 0),
                (-width * 0.41, 2),
            ],
            4,
        )
        canvas.mark(x, y, [(-width * 0.17, -2), (width * 0.22, -3), (width * 0.50, -4), (width * 0.32, -2)], 5)
    for _ in range(37):
        cx, cy = rng.randrange(N), rng.randrange(N)
        count = rng.randint(2, 5)
        value = wash[cy, cx]
        for j in range(count):
            x, y = cx + rng.gauss(0, 7), cy + j * rng.uniform(2.3, 3.5)
            length = rng.uniform(4.5, 17) * (0.62 if j == count - 1 else 1)
            # Interrupted, flat-edged ribbons have broad feet and thin ends.
            canvas.mark(
                x,
                y,
                [
                    (-length, 1),
                    (-0.48 * length, -1),
                    (0.26 * length, -1),
                    (0.66 * length, -3),
                    (length, -3),
                    (0.64 * length, 0),
                    (-0.22 * length, 1),
                    (-0.53 * length, 2),
                ],
                3 if value < -0.12 else 4,
            )
            if value > -0.08 and j in [0, 2]:
                canvas.mark(
                    x, y, [(-0.65 * length, 0), (-0.45 * length, -1), (0.2 * length, -1), (0.10 * length, 0)], 5
                )
                if j == 0 and value > 0.21:
                    canvas.mark(
                        x, y, [(0.5 * length, -2), (0.8 * length, -3), (length, -3), (0.71 * length, -2)], 6
                    )
    return canvas.im


def shallow(district, bed, water):
    bars = (
        np.sin(PERIOD * (2 * X - Y + 0.21 * np.sin(PERIOD * (X + Y)))) * 0.66 + noise(238 + district, 4, 5) * 0.53
    )
    # Pigment and depth use the same shore shapes. Alpha remains nonzero to
    # retain the dry pigment during the engine's texture import.
    depth = np.interp(bars, [-0.38, -0.1, 0.16, 0.54], [32, 92, 176, 255]).astype("uint8")
    gravel_rgb = np.asarray(bed).astype(float)
    river_rgb = np.asarray(water).astype(float)
    mix = np.select([bars < -0.15, bars < 0.05, bars < 0.34], [0.08, 0.37, 0.57], default=0.77)[..., None]
    rgb = gravel_rgb * (1 - mix) * 0.9 + river_rgb * mix
    rgb[(bars >= -0.18) & (bars < -0.145)] = np.asarray(inks("riverbed", district)[4]) * 0.95
    return Image.fromarray(np.dstack((rgb.astype("uint8"), depth)))


def spring(district, earth, water):
    qx = (X - 0.5) / 0.40
    qy = (Y - 0.5) / 0.33
    radius = np.hypot(qx, qy)
    theta = np.arctan2(qy, qx)
    boundary = 1 + 0.105 * np.sin(theta * 3 + 0.8) + 0.045 * np.cos(theta * 6 - 0.4)
    depth = boundary - radius
    pal = inks("river", district)
    bed = inks("riverbed", district)
    # The outer rim is a low terrace with a narrow vein of pale clay; deeper
    # water takes the colour of reflected sky and a cold central shadow.
    rgb = np.asarray(earth).copy()
    rgb[depth > -0.12] = bed[2]
    rgb[depth > -0.074] = bed[4]
    rgb[depth > -0.028] = pal[4]
    rgb[depth > 0.08] = np.asarray(water)[depth > 0.08]
    rgb[(depth > 0.57) & (np.asarray(water)[:, :, 0] < pal[3][0])] = pal[1]
    pool = Swatch(Image.fromarray(rgb), bed)
    rng = Random(127 + district)
    for _ in range(370):
        x, y = rng.randrange(N), rng.randrange(N)
        if -0.14 < depth[y, x] < 0.095:
            pebble(pool, x, y, rng.uniform(0.47, 1.25), rng.choice([3, 4, 4]), rng.choice([-1, 1]))
    mask = np.uint8(np.clip(depth * 8, 0, 1) * 223 + 32)
    return Image.fromarray(np.dstack((np.asarray(pool.im), mask)))


def packed_face(im):
    # Integer enlargement preserves the brush grid. Supply the adjoining
    # print's RGBA texels for anisotropic samples that fall outside the swatch.
    face = im.resize((SLOT - 2 * GUTTER,) * 2, Image.Resampling.NEAREST)
    return Image.fromarray(np.pad(np.asarray(face), ((GUTTER, GUTTER), (GUTTER, GUTTER), (0, 0)), mode="wrap"))


def main():
    names = ("sand", "grass", "burnt", "river", "riverbed", "river_low", "oasis")
    atlases = {
        name: Image.new("RGBA" if name in ("river_low", "oasis") else "RGB", (2 * SLOT, 2 * SLOT))
        for name in names
    }
    for district in range(4):
        earth = sand(district)
        pool = current(district)
        bed = gravel(district)
        paintings = (
            earth,
            turf(district),
            charcoal(district),
            pool,
            bed,
            shallow(district, bed, pool),
            spring(district, earth, pool),
        )
        for name, im in zip(names, paintings):
            atlases[name].paste(packed_face(im), (district % 2 * SLOT, district // 2 * SLOT))
    for name, atlas in atlases.items():
        atlas.save(OUTPUT / f"sheet_{name}_top.png", optimize=True)


if __name__ == "__main__":
    main()
