// Rebuild the parcel cuts, surface paintings and mineral pigments (Python, Pillow, NumPy).
const path = require('node:path');
const {execFileSync} = require('node:child_process');

require('./make_terrain_textures_hd.cjs');
const windows = process.platform === 'win32';
for (const source of ['bake_terrain_tops.py', 'paint_deposits.py']) {
  const script = path.join(__dirname, source);
  execFileSync(windows ? 'py' : 'python3', windows ? ['-3', script] : [script], {stdio: 'inherit'});
}
