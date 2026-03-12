# HUD Manager Module

**Living Document** - This documentation is continuously updated with new findings and API changes.

## Overview

`game_hud_manager` is a **central registry and configuration UI** for all movable HUD elements. It provides a two-panel glassmorphism window where users can enable/disable HUDs, configure which conditions appear, and adjust opacity — without each HUD module implementing its own config UI.

## Architecture

### Design Pattern: Definition-Based Registry

Each HUD module registers a **definition table** via `registerHudDefinition(def)`. The manager never imports or directly references HUD modules — it only interacts through the definition API. This makes the system fully extensible without touching the manager code.

```
HUD Module (e.g. game_specialconditionhud)
  └── calls registerHudDefinition({ id, title, getEnabled, setEnabled, ... })

game_hud_manager
  └── stores definitions in hudDefinitions table
  └── renders list + detail panel from definition API
  └── calls definition callbacks on user interaction
```

### Window Layout

```
HudManagerWindow (GlassWindow, 760×500)
├── titleBar (UIWidget, 40px tall)
│   ├── titleLabel (Label, centered)
│   └── closeButton (GlassButtonSmall, "X")
├── hudListPanel (GlassPanel, 240px wide, left)
│   ├── listSectionLabel ("HUD Elements")
│   └── hudListContainer (verticalBox, spacing 2)
│       └── HudManagerListRow × N
│           ├── statusIndicator (8px dot: green=on, gray=off)
│           ├── text (HUD title, left-aligned)
│           └── GlassToggle (animated pill, right-anchored)
└── hudDetailsPanel (GlassPanel, fills remainder ~490px)
    └── hudDetailsContent (verticalBox, spacing 8, margin 10)
        ├── GlassSectionTitle (HUD name)
        │
        ├── [if def.getConditions]
        │   ├── GlassSeparator
        │   ├── UIWidget condRow (22px header)
        │   │   ├── Label "Conditions" (left)
        │   │   ├── Label "N / total" (count, right of [+])
        │   │   ├── GlassButtonSmall "+" (enable all, tooltip)
        │   │   └── GlassButtonSmall "-" (disable all, tooltip)
        │   └── GlassPanel (gridPanel, auto-height)
        │       └── GlassConditionCell × N  (anchor+margin grid)
        │           image: condition icon 28×28 in 42×42 cell
        │           tooltip: condition label
        │           $on: full color + green bg
        │           $!on: 27% opacity (dimmed)
        │
        └── [if def.getOpacity]
            ├── GlassSeparator
            ├── UIWidget opacityRow (16px: "Opacity" + "27%")
            └── HorizontalQtScrollBar (0–100)
```

### Grid Layout Parameters (Conditions Icon Grid)

```lua
COLS = 10   -- columns
CELL = 42   -- cell size px (fills ~466 of 470px available)
GAP  = 4    -- gap between cells px
PAD  = 5    -- padding inside GlassPanel px
```

Grid height = `PAD + nRows × CELL + (nRows-1) × GAP + PAD`
For 30 conditions: 3 rows × 42px = 5 + 126 + 8 + 5 = **144px**

**Cell positioning uses anchor+margin** (NOT setX/setY which don't exist):
```lua
cell:addAnchor(AnchorLeft, 'parent', AnchorLeft)
cell:addAnchor(AnchorTop, 'parent', AnchorTop)
cell:setMarginLeft(PAD + col * (CELL + GAP))
cell:setMarginTop(PAD + row * (CELL + GAP))
```

### Key Files

| File | Purpose |
|---|---|
| `hud_manager.lua` | Registry logic, window creation, list/detail rendering |
| `hud_manager.otui` | Window and row OTUI style definitions |
| `hud_manager.otmod` | Module descriptor |
| `glass_styles.otui` | Local copy of `data/styles/10-glass.otui` for hot-reload |

`glass_styles.otui` must be kept in sync with `data/styles/10-glass.otui` using:
```powershell
Copy-Item modules/game_hud_manager/glass_styles.otui data/styles/10-glass.otui -Force
```

## Public API

```lua
-- Register a HUD with the manager. Call from your module's init or onLoad.
function registerHudDefinition(def)

-- Unregister a HUD. Call from your module's terminate.
function unregisterHudDefinition(hudId: string)

-- Open the manager window, optionally pre-selecting a HUD.
function open(initialHudId: string?)

-- Close the manager window.
function close()
```

## HUD Definition Structure

```lua
{
  id      = 'my_hud_id',      -- unique string identifier
  title   = tr('My HUD'),     -- display name in the list

  -- Required: enable/disable state
  getEnabled = function() -> boolean,
  setEnabled = function(value: boolean),

  -- Optional: icon grid (shows Conditions section with GlassConditionCell grid)
  -- Each entry: { id, label, enabled, icon? }
  -- icon = { source = '/path/to/image', clip = 'x y w h' }  (optional, enables icon display)
  getConditions = function() -> { { id, label, enabled, icon? } },
  setConditionEnabled = function(id: string, enabled: boolean),

  -- Optional: opacity slider (shows Opacity section)
  getOpacity = function() -> number (0–100),
  setOpacity  = function(value: number),
}
```

### Condition Entry with Icon

If conditions include an `icon` field, the manager displays them as a visual icon grid instead of a text list:

```lua
-- In your getConditions() implementation:
return {
  {
    id      = 'condition_fire',
    label   = 'You are burning',
    enabled = true,
    icon    = {
      source = '/images/game/states/player-state-flags',
      clip   = '9 0 9 9',   -- (clip - 1) * 9 for sprite offset
    }
  },
  ...
}
```

Without `icon`, conditions render as `GlassCheckBox` rows (fallback). With `icon`, they render as 42×42 `GlassConditionCell` buttons in a 10-column grid.

## Integration Example

```lua
local HUD_ID = 'my_hud'

function init()
    modules.game_hud_manager.registerHudDefinition({
        id    = HUD_ID,
        title = tr('My HUD'),
        getEnabled = function() return isEnabled() end,
        setEnabled = function(v) setEnabled(v) end,
        getOpacity = function() return getOpacity() end,
        setOpacity  = function(v) setOpacity(v) end,
    })
end

function terminate()
    modules.game_hud_manager.unregisterHudDefinition(HUD_ID)
end
```

## Visual System

All UI is built with the Glass design system:
- **OTUI styles**: `GlassWindow`, `GlassPanel`, `GlassListRow`, `GlassToggle`, `GlassConditionCell`, `GlassSectionTitle`, `GlassSeparator` — `data/styles/10-glass.otui`
- **Lua helpers**: `Glass.toggle()`, `Glass.sectionTitle()`, `Glass.separator()`, `Glass.opacityControl()` — `modules/gamelib/glass.lua`

No raw colors or layout constants are defined inline in `hud_manager.lua` — everything goes through `Glass.*` or a glass style.

### GlassToggle in List Rows

Each HudManagerListRow has a `GlassToggle` created via `Glass.toggle()`:
- Animated slide (~120ms, 8 steps) on click
- `onClick` returns `true` to prevent propagation to parent row's `selectHud`
- State tracked in a closure per row, independent of other rows
- Indicator dot color updated on toggle (green = on, gray = off)

## Built-in HUD Registration

`game_specialconditionhud` is auto-registered in `open()` via `registerBuiltInHuds()`. External modules must call `registerHudDefinition` themselves — the manager has no hard dependencies on any HUD module.

## Dependencies

- `gamelib` (startup): provides the global `Glass` table
- `game_specialconditionhud` (optional, soft): auto-registered as built-in HUD

## Common Issues

### `Glass` is nil on module reload
`gamelib/glass.lua` loads **once at startup**. Hot-reloading `game_hud_manager` does not reload it. Full client restart required if `Glass` is nil.

### Conditions not showing as icon grid
The icon grid is only shown when `condition.icon` is present in each entry from `getConditions()`. If `icon` is absent, falls back to `GlassCheckBox` text list. Check your `getConditions()` implementation.

### Grid cells not positioning correctly
**Do not use `setX`/`setY`** — these methods do not exist in OTClient Lua. Use:
```lua
cell:addAnchor(AnchorLeft, 'parent', AnchorLeft)
cell:addAnchor(AnchorTop, 'parent', AnchorTop)
cell:setMarginLeft(x)
cell:setMarginTop(y)
```

### Grid has empty space on the right
Caused by COLS × CELL + gaps being less than the content width (470px). Tune CELL upward to fill the space. Current calibration: CELL=42, COLS=10, GAP=4 → 466px ≈ 470px.

### Conditions list shows all conditions, not just active ones
The Conditions section is a **configuration UI** — users choose which conditions to display when active. The backend sends `PlayerStates` bitfield separately; the list is static client-side config.

### HUD not appearing in list after registration
`registerHudDefinition` calls `rebuildHudList()` only if the window is already open. If registered before `open()`, it appears correctly on the next `open()` call.

---

## 📝 Maintaining This Document

**This is a living document.** When you discover:
- New definition fields or optional capabilities
- Changes to the window layout or glass components
- New built-in HUD registrations
- Common bugs, sizing calibrations, or integration issues

**Update this file immediately.** Keep it concise and accurate.
