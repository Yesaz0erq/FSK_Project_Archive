// Rebuild the side atlases (low water shares the exposed riverbed cut).
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
    '4e4547 695948 806c52 ceb184',
    '63414c 885653 a87159 e7b778',
    '493547 64484f 805954 c79a74',
    '516580 687d94 8193a3 c6d3ce',
  ],
  grass: [
    '193d46 225553 30695b 85ac69',
    '364643 495947 606e48 a3a65a',
    '353d42 49544d 5a6351 99a063',
    '394e65 4c6975 628683 abc5b4',
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

// Rasterize the drawn facets on the same grid as the exposed face, before
// the UV gutters are extruded. All palette indices below address solid inks.
function polygon(tile, points, color) {
  const y0 = Math.max(0, Math.min(...points.map(p => p[1])));
  const y1 = Math.min(SIZE, Math.max(...points.map(p => p[1])));
  for (let y = Math.floor(y0); y < y1; y++) {
    const cuts = [];
    for (let i = 0; i < points.length; i++) {
      const [a, b] = [points[i], points[(i + 1) % points.length]];
      if ((a[1] > y + .5) !== (b[1] > y + .5)) {
        cuts.push(a[0] + (y + .5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]));
      }
    }
    cuts.sort((a, b) => a - b);
    for (let i = 0; i + 1 < cuts.length; i += 2) {
      const x = Math.ceil(cuts[i] - .5);
      tile.rect(x, y, Math.ceil(cuts[i+1] - .5) - x, 1, color);
    }
  }
}

const cuts = {
  // Four different exposed foundations: shale, sandstone, basalt and glacial till.
  forest: ['181c32','292a43','423648','614c51','816253','aa8867','a8ad80'],
  desert: ['32213b','532d47','784056','a25554','c87860','e49b6d','f4c086'],
  volcano: ['17172c','27263e','3a3046','514055','715463','a67068','e8a078'],
  snow: ['28324d','3a4762','515f7e','657f9a','86a2b2','abc6c9','d3dfd7'],
};

function strata(tile, type, biome, rng) {
  const district = biomes[biome];
  const rock = cuts[district];
  const cap = ramp(type === 'oasis' ? 'grass' : type, biome);
  const pick = (lo, hi) => lo + Math.floor(rng() * (hi - lo + 1));
  tile.paint(() => rock[1]);
  // Draw overlapping rock plates from the base up. Each has a long lit
  // cutting plane, a broad middle face, and one broken, cooler return face.
  const massive = district === 'volcano' || type === 'burnt';
  const heights = massive ? [119,81,46,14] : [118,95,68,42,17];
  for (const [tier,y] of heights.entries()) {
    let x = -pick(19,43);
    while (x < SIZE) {
      const w = massive ? pick(19,38) : pick(33,59);
      const h = massive ? pick(35,49) : pick(25,38);
      const d = pick(3,8);
      const yy = y + pick(-3,3);
      const muted = tier === 0 ? 0 : 1;
      const grain = pick(0,2) === 0 ? 1 : 0;
      const shape = (pts, c) => polygon(tile, pts.map(([u,v])=>[x+u, yy+v]), c);
      shape([[0,4],[w*.26,0],[w-6,-3],[w,2],[w-1,h*.56],[w-d,h-2],[w*.35,h+1],[2,h-3]],
        rock[2+muted]);
      shape([[0,4],[w*.26,0],[w-6,-3],[w,2],[w-d,5],[w*.32,6],[4,9]],rock[3+muted+grain]);
      shape([[w-d,5],[w,2],[w-1,h*.56],[w-d,h-2],[w*.6,h],[w*.77,h*.64]],rock[2]);
      if (tier > 0 && rng() < .65) {
        shape([[4,5],[w*.28,1],[w*.58,0],[w*.43,2],[w*.23,3],[9,6]],rock[5]);
      }
      if (district === 'desert' || district === 'snow') {
        shape([[0,h*.58],[w*.32,h*.50],[w*.66,h*.46],[w*.54,h*.53],[w*.29,h*.57],[1,h*.68]],
          rock[district === 'snow' ? 4 : 2]);
      }
      x += w;
    }
  }
  // Surface lips use different silhouettes: rooted sod, brittle char, a
  // saturated waterline and dry gravel all read when a parcel flips.
  const wet = type === 'river' || type === 'oasis';
  const sod = type === 'grass' || type === 'oasis';
  let x = -5;
  while (x < SIZE) {
    const w = pick(17,37);
    const h = wet ? pick(10,15) : pick(7,14);
    polygon(tile, [[x,0],[x+w,0],[x+w,h-2],[x+w*.82,h+2],[x+w*.38,h+1],[x+5,h+5],[x,h+3]],rock[0]);
    polygon(tile, [[x,0],[x+w,0],[x+w,h-3],[x+w*.8,h-1],[x+w*.35,h-2],[x+4,h+1],[x,h]],cap[3]);
    polygon(tile, [[x,0],[x+w,0],[x+w,2],[x+w*.43,3],[x+3,6],[x,5]],cap[5]);
    if (sod) {
      polygon(tile, [[x+4,h-2],[x+10,h-1],[x+7,h+8],[x+5,h+13],[x+5,h+4],[x+2,h+4]],cap[2]);
      tile.line(x+6,h+8,x+2,h+15,rock[4]);
    } else if (wet) {
      tile.line(x+3,h-4,x+Math.floor(w*.55),h-5,cap[5],1);
    } else if (type === 'burnt') {
      polygon(tile, [[x+10,0],[x+15,0],[x+10,h-3],[x+8,h+3],[x+8,6]],rock[0]);
    } else if (type === 'riverbed') {
      polygon(tile, [[x+4,3],[x+9,1],[x+14,3],[x+11,7],[x+5,6]],cap[6]);
    }
    x += w;
  }
}
fs.mkdirSync(OUT, {recursive: true});
for (const [index, type] of types.entries()) {
  const parts = [];
  for (let biome = 0; biome < biomes.length; biome++) {
    for (let variant = 0; variant < 4; variant++) {
      const rng = random(173221 + index * 13217 + variant * 3911 + biome * 11267);
      const tile = new Tile();
      strata(tile, type, biome, rng);
      parts.push(tile.toSvg(variant, biome));
    }
  }
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 512 512" shape-rendering="crispEdges">\n${parts.join('\n')}\n</svg>\n`;
  fs.writeFileSync(path.join(OUT, `sheet_${type}_side.svg`), svg);
}
