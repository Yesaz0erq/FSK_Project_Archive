// Entry point for rebuilding the full set of terrain art (Node + Python + Pillow).
const path = require('node:path');
const {execFileSync} = require('node:child_process');

require('./make_terrain_textures_hd.cjs');
const bake = path.join(__dirname, 'bake_terrain_tops.py');
if (process.platform === 'win32') {
  execFileSync('py', ['-3', bake], {stdio: 'inherit'});
} else {
  execFileSync('python3', [bake], {stdio: 'inherit'});
}
