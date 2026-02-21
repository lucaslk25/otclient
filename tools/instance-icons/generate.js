/**
 * Instance Icons Generator
 * Generates topbutton (22x22) and panel button (40x20) icons for the game_instance module.
 * Run from repo root: cd tools/instance-icons && npm install && npm run generate
 */

const path = require('path');
const sharp = require('sharp');

// -----------------------------------------------------------------------------
// Config (tweak here for iteration)
// -----------------------------------------------------------------------------
const CONFIG = {
  // Output paths relative to repo root
  repoRoot: path.resolve(__dirname, '..', '..'),
  topbuttonOut: 'data/images/topbuttons/instance.png',
  buttonOut: 'data/images/options/button_instance.png',

  // Sizes
  topbuttonSize: { w: 22, h: 22 },
  buttonFrameSize: { w: 20, h: 20 },
  buttonStripSize: { w: 40, h: 20 },

  // Colors (RGBA 0–255)
  topbutton: {
    transparent: [0, 0, 0, 0],
    outline: [35, 35, 35, 255],
    fill: [200, 200, 200, 255],
    shadowOutline: [80, 80, 80, 255],
    shadowFill: [130, 130, 130, 255],
  },
  button: {
    normalBg: [90, 90, 90, 255],
    pressedBg: [70, 70, 70, 255],
    innerShadow: [48, 48, 48, 255],
    outline: [30, 30, 30, 255],
    fill: [200, 200, 200, 255],
    shadowOutline: [50, 50, 50, 255],
    shadowFill: [110, 110, 110, 255],
    bevelLight: [60, 60, 60, 255],
    bevelDark: [30, 30, 30, 255],
  },
};

// Monster face pattern (14x16) — skull with horns and teeth; 0=skip, 1=outline, 2=fill
const FACE = [
  [0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
  [1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2],
  [0, 1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1],
  [0, 0, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, 0],
  [0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0],
  [0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0],
  [0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0],
  [0, 0, 1, 2, 1, 1, 2, 2, 2, 1, 1, 2, 1, 0],
  [0, 0, 1, 2, 1, 1, 2, 2, 2, 1, 1, 2, 1, 0],
  [0, 0, 1, 2, 2, 2, 2, 1, 2, 2, 2, 2, 1, 0],
  [0, 0, 0, 1, 2, 2, 1, 2, 1, 2, 2, 1, 0, 0],
  [0, 0, 0, 0, 1, 2, 1, 2, 1, 2, 1, 0, 0, 0],
  [0, 0, 0, 0, 1, 1, 2, 1, 2, 1, 1, 0, 0, 0],
  [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0],
];

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
function createBuffer(w, h) {
  return Buffer.alloc(w * h * 4);
}

function setPixel(buf, w, x, y, r, g, b, a) {
  if (x < 0 || x >= w) return;
  const h = buf.length / (w * 4);
  if (y < 0 || y >= h) return;
  const idx = (y * w + x) * 4;
  buf[idx] = r;
  buf[idx + 1] = g;
  buf[idx + 2] = b;
  buf[idx + 3] = a;
}

function fillRect(buf, w, x1, y1, x2, y2, r, g, b, a) {
  for (let y = y1; y <= y2; y++) {
    for (let x = x1; x <= x2; x++) {
      setPixel(buf, w, x, y, r, g, b, a);
    }
  }
}

function drawFace(buf, w, ox, oy, outline, fill) {
  for (let y = 0; y < FACE.length; y++) {
    for (let x = 0; x < FACE[y].length; x++) {
      const v = FACE[y][x];
      if (v === 1) setPixel(buf, w, ox + x, oy + y, ...outline);
      else if (v === 2) setPixel(buf, w, ox + x, oy + y, ...fill);
    }
  }
}

// -----------------------------------------------------------------------------
// Topbutton (22x22): transparent bg, dual monster, optional 1px border
// -----------------------------------------------------------------------------
function generateTopbutton() {
  const { w, h } = CONFIG.topbuttonSize;
  const buf = createBuffer(w, h);

  // Start fully transparent
  fillRect(buf, w, 0, 0, w - 1, h - 1, ...CONFIG.topbutton.transparent);

  // Back monster (shadow) — offset +4, +5 — visible mid grey, no border
  drawFace(buf, w, 4, 5, CONFIG.topbutton.shadowOutline, CONFIG.topbutton.shadowFill);
  // Front monster — offset +1, +1
  drawFace(buf, w, 1, 1, CONFIG.topbutton.outline, CONFIG.topbutton.fill);

  return sharp(buf, { raw: { width: w, height: h, channels: 4 } }).png();
}

// -----------------------------------------------------------------------------
// Button (40x20): two 20x20 frames, grey bg, dual monster, bevel border
// -----------------------------------------------------------------------------
function generateButton() {
  const { w: totalW, h: totalH } = CONFIG.buttonStripSize;
  const { w: fw, h: fh } = CONFIG.buttonFrameSize;
  const buf = createBuffer(totalW, totalH);

  function drawFrame(ox, oy, bg) {
    fillRect(buf, totalW, ox, oy, ox + fw - 1, oy + fh - 1, ...bg);
    // Inner shadow: 1px darker line just inside the edges (like originals)
    const [isR, isG, isB, isA] = CONFIG.button.innerShadow;
    for (let x = ox + 1; x < ox + fw - 1; x++) {
      setPixel(buf, totalW, x, oy + 1, isR, isG, isB, isA);
      setPixel(buf, totalW, x, oy + fh - 2, isR, isG, isB, isA);
    }
    for (let y = oy + 1; y < oy + fh - 1; y++) {
      setPixel(buf, totalW, ox + 1, y, isR, isG, isB, isA);
      setPixel(buf, totalW, ox + fw - 2, y, isR, isG, isB, isA);
    }
    // Bevel: lighter top/left, darker bottom/right on outer edge
    for (let x = ox; x < ox + fw; x++) {
      setPixel(buf, totalW, x, oy, ...CONFIG.button.bevelLight);
      setPixel(buf, totalW, x, oy + fh - 1, ...CONFIG.button.bevelDark);
    }
    for (let y = oy; y < oy + fh; y++) {
      setPixel(buf, totalW, ox, y, ...CONFIG.button.bevelLight);
      setPixel(buf, totalW, ox + fw - 1, y, ...CONFIG.button.bevelDark);
    }
    const cx = ox + 2, cy = oy + 3;
    drawFace(buf, totalW, cx + 3, cy + 2, CONFIG.button.shadowOutline, CONFIG.button.shadowFill);
    drawFace(buf, totalW, cx, cy, CONFIG.button.outline, CONFIG.button.fill);
  }

  drawFrame(0, 0, CONFIG.button.normalBg);
  drawFrame(20, 0, CONFIG.button.pressedBg);

  return sharp(buf, { raw: { width: totalW, height: totalH, channels: 4 } }).png();
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------
async function main() {
  const root = CONFIG.repoRoot;
  const topbuttonPath = path.join(root, CONFIG.topbuttonOut);
  const buttonPath = path.join(root, CONFIG.buttonOut);

  const topbuttonPng = await generateTopbutton();
  const buttonPng = await generateButton();

  await topbuttonPng.toFile(topbuttonPath);
  await buttonPng.toFile(buttonPath);

  console.log('Instance icons generated:');
  console.log('  ', topbuttonPath);
  console.log('  ', buttonPath);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
