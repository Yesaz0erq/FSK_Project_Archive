"""Paint the 4 × 4 albedo book used by the three-dimensional resource markers."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "assets/terrain/deposit_pigments.png"

# The motifs are small enough to read on a single ore chip at gameplay zoom.
# Coordinates are on a 24-texel face. Each stroke names its actual paint pot.
MOTIFS = {
    "bark": [
        (1, [(0,0),(6,0),(4,9),(5,14),(1,23),(0,23)]),
        (4, [(7,0),(11,0),(9,7),(10,11),(6,16),(8,10)]),
        (1, [(15,0),(19,0),(15,9),(15,17),(12,23),(10,23),(13,15),(12,10)]),
        (3, [(17,8),(21,4),(19,12),(21,16),(17,21),(17,16)]),
    ],
    "rings": [
        (1, [(1,8),(5,3),(15,2),(21,6),(23,15),(17,21),(7,20),(3,16)]),
        (4, [(3,8),(7,4),(15,3),(20,7),(20,14),(15,18),(8,18),(5,14)]),
        (2, [(6,9),(10,6),(15,7),(18,10),(16,16),(10,16),(7,14)]),
        (3, [(9,9),(13,8),(15,11),(13,14),(10,14),(9,12)]),
        (0, [(20,1),(16,6),(14,8),(15,10),(17,7),(22,4)]),
    ],
    "prism": [
        (1, [(0,0),(5,0),(6,7),(3,20),(0,23)]),
        (4, [(6,0),(12,0),(10,6),(7,13),(5,16),(7,5)]),
        (3, [(12,0),(16,0),(13,13),(8,23),(6,23),(10,12)]),
        (0, [(20,0),(23,0),(22,12),(15,23),(13,23),(18,12)]),
        (5, [(9,0),(11,0),(9,4),(8,5)]),
    ],
    "seam": [
        (1, [(0,4),(8,1),(14,5),(12,10),(6,12),(1,9)]),
        (3, [(1,4),(7,2),(11,4),(8,6),(3,7)]),
        (1, [(14,14),(21,10),(23,10),(23,22),(15,23),(12,18)]),
        (4, [(0,20),(6,15),(10,15),(14,10),(19,8),(23,3),(22,7),(18,11),(15,12),(10,18),(6,18)]),
        (5, [(8,15),(11,14),(14,10),(17,9),(15,12),(11,16)]),
    ],
    "drop": [
        (1, [(0,6),(4,12),(10,16),(17,16),(22,10),(23,9),(23,23),(0,23)]),
        (3, [(1,6),(3,3),(8,1),(13,2),(8,4),(5,9),(3,10)]),
        (5, [(3,5),(6,2),(9,2),(7,5),(4,7)]),
        (4, [(10,16),(17,15),(21,11),(19,16),(15,18),(10,18)]),
    ],
    "shelf": [
        (1, [(0,8),(10,5),(18,6),(23,4),(23,8),(15,10),(8,9),(0,12)]),
        (4, [(1,6),(10,3),(17,4),(14,6),(8,6),(0,9)]),
        (3, [(5,16),(14,12),(21,13),(17,16),(9,16),(4,19)]),
        (1, [(9,18),(16,17),(23,13),(23,17),(16,20),(4,22)]),
    ],
}

# Slots are stable. Multiple minerals share a crystal cut but have their own inks.
SLOTS = [
    ("bark", "221e30 473047 704b46 a66b4c d09461 e8c28a"),
    ("rings", "52343f 795053 b57b5d dcab71 e4bc83 f9dbac"),
    ("drop", "3e2938 77403a ba6939 e3933d f8ba59 ffe8a2"),
    ("drop", "132c48 1b4a69 23798a 52aeb2 81d4cb d5f6d9"),
    ("prism", "223754 34567d 6199b8 8ac7d0 b2e2df eff9de"),
    ("prism", "352946 54456e 9a8bb0 c8b5ce d4deea f9ede5"),
    ("prism", "49424e 796b72 b5a5a1 d5c9b2 e8daad fcebc8"),
    ("prism", "131724 232439 403953 5c506c 796780 b1a3af"),
    ("prism", "483a47 786032 b8a13b e1c552 ebd866 fff0ae"),
    ("seam", "242138 413a50 655769 867887 b9b1b4 e5d8bc"),
    ("seam", "32253c 523f53 766067 93726a db8d63 ffc595"),
    ("shelf", "5c3a46 956754 b28b64 d1a979 e3bb81 f5d69c"),
]


def main():
    book = Image.new("RGB", (128, 128))
    for slot, (motif, inks) in enumerate(SLOTS):
        palette = ["#" + rgb for rgb in inks.split()]
        tile = Image.new("RGB", (24, 24), palette[2])
        draw = ImageDraw.Draw(tile)
        for color, points in MOTIFS[motif]:
            draw.polygon(points, fill=palette[color])
        x, y = slot % 4 * 32, slot // 4 * 32
        # Extrude the border for mips at distant zoom.
        for v in range(32):
            for u in range(32):
                book.putpixel((x+u, y+v), tile.getpixel((max(0,min(23,u-4)), max(0,min(23,v-4)))))
    book.save(OUT, optimize=True)


if __name__ == "__main__":
    main()
