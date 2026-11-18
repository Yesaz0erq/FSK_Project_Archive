// Rebuild the six stratified side atlases consumed by the six terrain meshes.
// Rows: forest, desert, volcano, snow. Columns: four stable parcel variations.
// 124x124 painted pixels per sample, enlarged 2x; extruded gutters protect mip levels.
const fs = require('node:fs');
const path = require('node:path');
const OUT = path.resolve(__dirname, '../assets/terrain');
const SIZE = 124;
const SLOT = 128;
const BORDER = 2;
const biomes = ['forest', 'desert', 'volcano', 'snow'];
const types = ['sand', 'grass', 'burnt', 'river', 'riverbed', 'oasis'];

// Shadow, middle and light pigments for each material, in district order.
const pigments = {
  sand: [
    '785c62 a4856e c3aa83 e1ca98',
    '995e63 c58b73 e5b787 f4d59e',
    '544557 81615e a27b69 c19a80',
    '8596b8 afc7d6 cadfe3 e8f1ed',
  ],
  grass: [
    '284f53 487b68 789b70 a2b87e',
    '42635c 638866 899e70 b6b977',
    '424d52 617765 87936d b29c76',
    '526e85 72979d 94b8ac c4d7bb',
  ],
  burnt: [
    '343348 514758 73616a ab8178',
    '504052 6e4e58 926963 bf8b76',
    '342e45 4e4057 72515f a36c69',
    '464760 656682 9291a2 c4b8b9',
  ],
  river: [
    '244760 32687c 468c99 83c7b8',
    '305671 3f8594 65aca6 a5d8bc',
    '373a59 514e6e 696785 a199a9',
    '355878 5989a4 82b6c6 bfe7e3',
  ],
  riverbed: [
    '61545e 8d7e77 b0a386 d1c6a5',
    '795f65 aa8576 c3a28a e0c6a5',
    '453d50 6e606a 908280 b4a499',
    '64758c 879ba9 abb9bf d2d8d4',
  ],
  earth: [
    '342f43 554751 806855 a68c69',
    '4a354e 78525c ab7768 d5a383',
    '2d293d 493b50 6a515e 986d64',
    '394660 586982 8395aa b3c6d2',
  ],
};

function random(seed) {
  return () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 4294967296;
  };
}

function mix(first, second, weight) {
  const a = parseInt(first, 16);
  const b = parseInt(second, 16);
  let color = 0;
  for (const shift of [16, 8, 0]) {
    const start = (a >> shift) & 255;
    const end = (b >> shift) & 255;
    color |= Math.round(start + (end - start) * weight) << shift;
  }
  return color.toString(16).padStart(6, '0');
}

function ramp(kind, biome) {
  const [shadow, middle, light, rim] = pigments[kind][biome].split(' ');
  return [shadow, mix(shadow, middle, .64), middle, mix(middle, light, .36),
    mix(middle, light, .72), light, mix(light, rim, .6), rim];
}

class Tile {
  constructor() {
    this.pixels = Array(SIZE * SIZE);
  }

  dot(x, y, color) {
    if (x >= 0 && y >= 0 && x < SIZE && y < SIZE) this.pixels[y * SIZE + x] = color;
  }

  rect(x, y, width, height, color) {
    for (let yy = Math.max(0, y); yy < Math.min(SIZE, y + height); yy++) {
      for (let xx = Math.max(0, x); xx < Math.min(SIZE, x + width); xx++) this.dot(xx, yy, color);
    }
  }

  line(x, y, endX, endY, color, thickness = 1) {
    const length = Math.max(Math.abs(endX - x), Math.abs(endY - y), 1);
    for (let step = 0; step <= length; step++) {
      const t = step / length;
      this.rect(Math.round(x + (endX - x) * t), Math.round(y + (endY - y) * t), thickness, thickness, color);
    }
  }

  paint(pigment) {
    for (let y = 0; y < SIZE; y++) {
      for (let x = 0; x < SIZE; x++) this.dot(x, y, pigment(x, y));
    }
  }

  // Merge same-color horizontal runs vertically before emitting integer-aligned SVG paths.
  toSvg(column, row) {
    const byColor = new Map();
    let active = new Map();
    function emit(rect) {
      if (!byColor.has(rect.color)) byColor.set(rect.color, []);
      byColor.get(rect.color).push(`M${rect.x} ${rect.y}h${rect.w}v${rect.h}h-${rect.w}z`);
    }
    const sample = (x, y) => this.pixels[Math.min(SIZE - 1, Math.max(0, y - BORDER)) * SIZE +
      Math.min(SIZE - 1, Math.max(0, x - BORDER))];
    for (let y = 0; y < SLOT; y++) {
      const runs = new Map();
      let x = 0;
      while (x < SLOT) {
        const color = sample(x, y);
        let end = x + 1;
        while (end < SLOT && sample(end, y) === color) end++;
        const key = [x, end, color].join(',');
        const previous = active.get(key);
        if (previous) { previous.h++; active.delete(key); }
        runs.set(key, previous || {x, y, w: end - x, h: 1, color});
        x = end;
      }
      active.forEach(emit);
      active = runs;
    }
    active.forEach(emit);
    const paths = Array.from(byColor, ([color, parts]) => `<path fill="#${color}" d="${parts.join('')}"/>`);
    return `<g transform="translate(${column * SLOT} ${row * SLOT})">${paths.join('\n')}</g>`;
  }
}

const sin = Math.sin;
const cos = Math.cos;
const between = (rng, low, high) => low + Math.floor(rng() * (high - low + 1));

function contours(x, y, phase) {
  return sin(x * .055 + sin(y * .075 + phase)) * .52 +
    cos(y * .095 + x * .033 - phase) * .26 + sin(x * .14 - y * .1 - phase) * .13;
}

function stone(tile, x, y, radius, pal) {
  const h = Math.max(2, Math.round(radius * .62));
  for (let dy = -h; dy <= h; dy++) {
    const span = Math.round(radius * Math.sqrt(1 - (dy / (h + .5)) ** 2));
    const left = x - span + (dy > 1 ? 1 : 0);
    tile.rect(left + 1, y + dy + 2, span * 2, 1, pal[1]);
    tile.rect(left, y + dy, span * 2, 1, dy >= 1 ? pal[2] : pal[5]);
    if (dy < 0) tile.rect(left, y + dy, Math.max(2, span - 1), 1, pal[6]);
  }
}

function strata(tile, type, biome, rng, phase) {
  const earth = ramp('earth', biome);
  const cap = ramp(type === 'oasis' ? 'grass' : type, biome);
  const outcrop = between(rng, 13, 49);
  const cleft = between(rng, 69, 103);
  const rocky = type === 'burnt' || type === 'riverbed';
  tile.paint((x, y) => {
    const field = contours(x, y, phase);
    const lip = 8 + 4 * sin(x * .09 + phase) + 2 * sin(x * .24);
    if (y < lip) return cap[y < 2 ? 5 : 3];
    if (y < lip + 4) return earth[0];
    const fault = x + y * .17 > cleft ? 8 : 0;
    const depth = y + 8 * sin(x * .047 + phase) + x * .11 + fault;
    const lamina = Math.floor(depth / 22);
    const seam = depth - lamina * 22;
    // Outcrops cross the bands, with a broken lip and shaded fracture faces.
    const ledge = Math.abs(x - outcrop - y * .18) + Math.abs(y - 50) * .87;
    if (ledge < (rocky ? 41 : 32)) {
      if (ledge > (rocky ? 37 : 28)) return earth[y < 46 ? 5 : 0];
      return earth[y < 44 + (x - outcrop) * .28 ? 4 : field > .08 ? 2 : 1];
    }
    if (Math.abs(x + y * .17 - cleft) < 2 && y > 29) return earth[0];
    if (y > 104) return earth[seam < 3 ? 0 : 1];
    if (seam < 2 && field > .01) return earth[5];
    if (seam < 5 && field > -.3) return earth[1];
    return earth[[3,2,4,2,3,2,1][Math.abs(lamina) % 7]];
  });
  for (let i = 0; i < (rocky ? 13 : 7); i++) {
    stone(tile, between(rng, 0, SIZE), between(rng, 24, 97), between(rng, 2, rocky ? 7 : 5), earth);
  }
  if (type === 'grass' || type === 'oasis') {
    for (let i = 0; i < 5; i++) {
      const x = between(rng, 2, SIZE - 3);
      const y = between(rng, 16, 30);
      tile.line(x, 8, x + 1, y, earth[5], 2);
      tile.line(x + 1, y - 3, x - 3, y + 4, earth[4]);
    }
  }
}

// Side faces remain editable stepped strata, while tops use the painted master.
fs.mkdirSync(OUT, {recursive: true});
for (const [index, type] of types.entries()) {
  const parts = [];
  for (let biome = 0; biome < biomes.length; biome++) {
    for (let variant = 0; variant < 4; variant++) {
      const rng = random(173221 + index * 13217 + variant * 3911 + biome * 11267);
      const tile = new Tile();
      const phase = rng() * Math.PI * 2;
      strata(tile, type, biome, rng, phase);

      parts.push(tile.toSvg(variant, biome));
    }
  }
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 512 512" shape-rendering="crispEdges">\n${parts.join('\n')}\n</svg>\n`;
  fs.writeFileSync(path.join(OUT, `sheet_${type}_side.svg`), svg);
}
