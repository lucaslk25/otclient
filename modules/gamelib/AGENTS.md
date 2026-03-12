# Gamelib Module

**Living Document** - This documentation is continuously updated with new findings.

## Overview

`gamelib` is the **core shared library** for all game modules. It is loaded once at client startup (before any game module) and exposes globals used throughout the codebase. It contains game protocol handling, entity models, utility functions, and the Glass UI design system.

## Load Order

Defined in `gamelib.otmod` via `@onLoad`:

```
const → util → protocol → protocollogin → protocolgame
→ position → game → creature → player → market
→ textmessages → thing → spells → tile → items
→ dofiles 'ui'   (uiminimap, uicreaturebutton)
→ glass          (Glass UI library)
```

Everything in this list is a global from the moment `gamelib` finishes loading.

## Key Files

| File | Global / Purpose |
|---|---|
| `const.lua` | Game constants (item IDs, flags, etc.) |
| `util.lua` | General Lua utilities |
| `protocolgame.lua` | Incoming packet parsing |
| `player.lua` | `Icons[]` table mapping `PlayerStates` bits to condition icons/tooltips |
| `game.lua` | `g_game` wrappers and helpers |
| `glass.lua` | `Glass` — reusable UI component library |

---

## Glass UI Library (`glass.lua`)

### Purpose

`Glass` provides **behavior helpers** for the glassmorphism design system. The visual styles (colors, borders, radius) are declared in `data/styles/10-glass.otui` and loaded globally at startup. `Glass` handles the Lua-side behavior: widget creation, animation, and state management.

### Globals

```lua
Glass          -- main table, always available after gamelib loads
Glass._anims   -- internal: active animation event handles, keyed by tostring(widget)
```

### API

#### `Glass.toggle(parent, initialState, onChange) -> UIWidget`

Creates a `GlassToggle` widget anchored to the right/verticalCenter of `parent`.

```lua
local toggle = Glass.toggle(row, isEnabled, function(newState)
    setEnabled(newState)
end)
```

- The toggle animates smoothly on click (~120ms, 8 steps)
- `onClick` returns `true` to prevent click propagation to the parent row
- Multiple toggles in the same parent are fully independent (closures are scoped per call)
- Safe to call `Glass.setToggleState` mid-animation — previous animation is cancelled

#### `Glass.setToggleState(toggle, on, animate?)`

Sets toggle state directly. Pass `animate = true` for the sliding animation, `false` (or nil) to snap immediately.

```lua
Glass.setToggleState(toggle, true, true)   -- animated
Glass.setToggleState(toggle, false)        -- instant snap (used on init)
```

#### `Glass.opacityControl(parent, initialValue, onChange) -> UIScrollBar`

Creates a compact inline opacity row: `[Opacity label]` `[value%]` then a `HorizontalQtScrollBar` on the next line. `parent` must use a vertical layout.

```lua
Glass.opacityControl(content, 27, function(value)
    setOpacity(value)
end)
```

#### `Glass.sectionTitle(parent, text) -> UIWidget`

Creates a `GlassSectionTitle` label with an accent underline.

```lua
Glass.sectionTitle(content, tr('Conditions'))
```

#### `Glass.separator(parent) -> UIWidget`

Creates a `GlassSeparator` (1px horizontal rule).

```lua
Glass.separator(content)
```

---

## Glass Style System (`data/styles/10-glass.otui`)

Loaded globally at startup by `client_styles`. Available to any module without importing.

### Available Styles

| Style | Base | Purpose |
|---|---|---|
| `GlassPanel` | `UIWidget` | Semi-transparent container with light/shadow borders |
| `GlassPanelDark` | `GlassPanel` | Darker variant |
| `GlassPanelLight` | `GlassPanel` | Lighter variant |
| `GlassWindow` | `UIWindow` | Full window; `color: alpha` hides native text (use a custom Label) |
| `GlassListRow` | `UIButton` | Selectable list item with hover/selected glow + `statusIndicator` dot |
| `GlassCheckBox` | `UICheckBox` | Checkbox matching the glass aesthetic |
| `GlassSectionTitle` | `Label` | Section header with `accentLine` underline child |
| `GlassButton` | `UIButton` | 80×26 action button |
| `GlassButtonSmall` | `UIButton` | 24×24 button (e.g. close button) |
| `GlassToggle` | `UIButton` | 32×16 animated pill toggle; use `Glass.toggle()` for behavior |
| `GlassConditionCell` | `UIButton` | 42×42 icon cell for condition grids; `$on` = full color, `$!on` = 27% opacity |
| `GlassSeparator` | `UIWidget` | 1px horizontal divider |
| `GlassSeparatorThick` | `UIWidget` | 2px divider with shadow |

### Toggle Dimensions (important for animation)

`GlassToggle` is 32×16px. The knob is 10×10px with 3px padding:

```
Off:  knob.marginLeft = 3
On:   knob.marginLeft = 32 - 10 - 3 = 19
```

The knob always uses `AnchorLeft` — `Glass.toggle()` sets this up on creation. **Never use `AnchorRight` for the knob**, as it breaks `marginLeft`-based animation.

### Design Token Summary

| Token | Value | Usage |
|---|---|---|
| Window background | `#08081acc` | GlassWindow bg |
| Panel background | `#0e0e22aa` | GlassPanel bg |
| Title bar bg | `#0a0a1eee` | Custom title bar in GlassWindow |
| Border light (top/left) | `#ffffff18–20` | Top-left highlight |
| Border shadow (bottom/right) | `#00000040–50` | Bottom-right shadow |
| Selected row | `#2040a0cc` | GlassListRow `$on` state |
| Active indicator | `#60c060ff` | statusIndicator dot, enabled |
| Inactive indicator | `#606080ff` | statusIndicator dot, disabled |
| Toggle on | `#30a050dd` | GlassToggle background when on |
| Toggle off | `#404060cc` | GlassToggle background when off |
| Text primary | `#c8c8e0ff` | Titles, headers |
| Text secondary | `#a0a0b8ff` | Labels, values |

---

## Extending the Glass System

### Adding a new style

Add to `data/styles/10-glass.otui` and sync the local copy in `modules/game_hud_manager/glass_styles.otui`:

```otui
GlassMyWidget < UIWidget
  background-color: #0e0e22aa
  background-radius: 8
  border-width-top: 1
  border-color-top: #ffffff18
  -- ... follow the pattern
```

### Adding a new Lua helper

Add to `modules/gamelib/glass.lua`. Since `Glass` is a global table, new functions are immediately available to all modules after a client restart.

```lua
function Glass.myHelper(parent, opts)
    -- create widgets, return handle
end
```

### Using Glass in a new module

Styles are available automatically (loaded at startup). `Glass.*` functions are available after `gamelib` loads. No import needed.

```lua
-- In your module's buildUI():
Glass.sectionTitle(content, tr('My Section'))
Glass.separator(content)
local toggle = Glass.toggle(row, getEnabled(), function(v) setEnabled(v) end)
```

---

## Known Limitations

### `border-width` does not follow `background-radius`
Borders are rendered as straight lines regardless of `background-radius`. The 1px gap at rounded corners is a rendering limitation of OTClient — accepted as a trade-off for the depth effect. Removing borders entirely makes panels look flat.

### `GlassWindow` native text
`UIWindow` draws its `text` property natively. `GlassWindow` sets `color: alpha` to hide it. Always use a custom `Label` child for the title; do not set `!text:` on a `GlassWindow` widget.

### No `setX` / `setY` in Lua
OTClient does not expose `widget:setX(n)` / `widget:setY(n)`. For absolute positioning in an anchor-layout container, use:
```lua
widget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
widget:addAnchor(AnchorTop,  'parent', AnchorTop)
widget:setMarginLeft(x)
widget:setMarginTop(y)
```
This is the only correct idiom for grid-like manual layouts in Lua.

### Hot-reload limitation
`gamelib` (including `glass.lua`) loads **once at client startup**. Hot-reloading a game module does not reload `gamelib`. Changes to `glass.lua` require a full client restart. Changes to `glass_styles.otui` take effect on module reload (it is re-imported via `g_ui.importStyle`).

---

## 📝 Maintaining This Document

**This is a living document.** When you discover:
- New Glass components or style tokens
- New gamelib utilities
- Changes to load order or module dependencies
- Rendering limitations or OTClient quirks

**Update this file immediately.** Keep it concise and actionable.
