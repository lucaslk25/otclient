# Instance Icons Generator

Generates the instance UI icons (topbutton + panel button) for the OTClient **game_instance** module. Outputs pixel-perfect PNGs with transparent background (topbutton), visible cloned silhouette, and borders matching other game icons.

## Requirements

- **Node.js** 18+ (or current LTS)
- **sharp** (installed via `npm install` in this folder)

## How to run

From the **repository root**:

```bash
cd tools/instance-icons
npm install
npm run generate
```

Or in one line:

```bash
cd tools/instance-icons && npm install && npm run generate
```

Output files (relative to repo root):

- `data/images/topbuttons/instance.png` — 22×22 miniwindow header icon
- `data/images/options/button_instance.png` — 40×20 panel button (two 20×20 frames: normal, pressed)

## Tweak guide

Edit **`generate.js`** and adjust the `CONFIG` object at the top:

| Key | Description |
|-----|-------------|
| **topbuttonOut** / **buttonOut** | Output paths relative to repo root |
| **topbutton.transparent** | RGBA for transparent pixels (default: full transparent) |
| **topbutton.outline** / **topbutton.fill** | Front monster outline and fill (dark grey / light grey) |
| **topbutton.shadowOutline** / **topbutton.shadowFill** | Cloned silhouette (mid grey) — increase RGB if it’s too dark |
| **topbutton** | No border; transparent background only. Shadow silhouette uses shadowOutline/shadowFill (keep visible). |
| **button.normalBg** / **button.pressedBg** | Panel button frame fill (lighter grey; not too dark) |
| **button.innerShadow** | 1px inner shadow at edges only (darker grey), like originals |
| **button.bevelLight** / **button.bevelDark** | Outer bevel (lighter top/left, darker bottom/right) |

Colors are **RGBA arrays** `[r, g, b, a]` with values 0–255. Re-run `npm run generate` after changes.

## Directives

- Icons are drawn at final size (no resize) so pixels stay sharp.
- Topbutton uses a **fully transparent** background so it matches other header icons.
- The **shadow (cloned) monster** uses mid grey (e.g. 100–120 RGB) so it stays visible.
- Panel button uses **grey backgrounds** (e.g. 72, 56) to match other option buttons, not black.
- **Topbutton**: no border, transparent background; shadow (cloned) silhouette must stay visible (lighter grey).
- **Button**: lighter base fill + 1px inner shadow at edges only (like original option buttons); outer bevel.
