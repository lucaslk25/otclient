# Special Condition HUD Module

**Living Document** - This documentation is continuously updated with new findings and architectural changes.

## Overview

The `game_specialconditionhud` module displays active player conditions (buffs/debuffs) in a draggable, resizable HUD that can be oriented horizontally or vertically.

## Architecture

### Widget Hierarchy

```
conditionHUDPanel (root)
├── conditionHUDBox (container with dashed border)
│   └── iconsContainer (verticalBox or horizontalBox layout)
│       ├── condition icon 1
│       ├── condition icon 2
│       └── ...
└── resizeHandle (bottom-right corner)
```

**Important**: The `editModeLabel` and `editActionStrip` are created by `game_ui_edit` as **siblings** of `conditionHUDPanel`, not as children. They anchor to `conditionHUDPanel` but live in the root panel.

### Key Files

- `conditionhud.lua`: Main module logic
- `conditionhud.otui`: UI style definitions
- `conditionhud.otmod`: Module descriptor

## Orientation System

The HUD supports two orientations:

### Vertical (Default)
- Icons stacked top-to-bottom
- Layout: `verticalBox`
- Minimum size: 26×36 (icon + margins)
- Label: Rotated 90° to the right of HUD
- Action strip: To the left of HUD, vertically oriented

### Horizontal
- Icons arranged left-to-right
- Layout: `horizontalBox`
- Minimum size: 42×26 (icon + margins)
- Label: Horizontal, centered above HUD
- Action strip: To the right of HUD, horizontally oriented

### Toggling Orientation

```lua
modules.game_specialconditionhud.toggleOrientation()
```

When orientation changes:
1. Icon container layout is recreated with new style
2. Panel size is adjusted (swapping width/height based on saved dimensions)
3. Edit mode label is repositioned and rotated
4. Action strip is destroyed and recreated with orientation-specific style

## Settings Persistence

Settings are saved per-character in `g_settings` under key `'CharConditionHUD'`:

```lua
{
  [characterName] = {
    vertical = true,              -- Current orientation
    verticalHeight = 120,        -- Saved height for vertical mode
    horizontalWidth = 150,       -- Saved width for horizontal mode
    offsetFromCenterX = -200,    -- Pixel offset from map center (x)
    offsetFromCenterY = 50,      -- Pixel offset from map center (y)
  }
}
```

The HUD is positioned relative to the **map center** (like health circles), not absolute screen coordinates. This ensures it stays in position when the UI layout changes.

## Edit Mode Integration

The module integrates with `game_ui_edit` for UI customization:

### Edit Mode Label
- Created via `game_ui_edit.createEditModeLabel()`
- Text: "special conditions"
- Rotated 90° when vertical, 0° when horizontal
- Positioned via `updateEditModeLabelLayout(vertical)`

### Action Strip
- Created via `game_ui_edit.createHudActionStrip()`
- Contains two buttons:
  - **Orientation toggle**: Calls `toggleOrientation()`
  - **Edit button**: Opens HUD manager
- Recreated when orientation changes to use correct style (`HudEditActionStrip` vs `HudEditActionStripVertical`)
- Positioned via `updateEditActionStripLayout(vertical)` or `recreateEditActionStrip(vertical)`

### Dragging and Resizing
- Only enabled in edit mode
- `conditionHudPanel:setDraggable(editMode)`
- `conditionHudPanel:setPhantom(not editMode)` - allows click-through when not editing
- Resize handle appears in bottom-right corner (4×4 pixels)

## Public API

### Main Functions

```lua
-- Toggle between horizontal and vertical orientation
function toggleOrientation()

-- Update panel size (called after orientation change or icon count change)
function updatePanelSize()

-- Initialize the module
function init()

-- Cleanup the module
function terminate()
```

### Module Exports

The module exports the following for external use:

```lua
M.toggleOrientation = toggleOrientation
```

All other functions are local and not accessible externally.

## Constants

```lua
ICON_SIZE = 20               -- Condition icon size
ICON_SPACING = 6             -- Gap between icons
PANEL_MARGIN = 3             -- Padding around icon container
BUTTON_SIZE = 18             -- HUD manager button size
MIN_WIDTH_V = 26             -- Minimum width in vertical mode
MIN_HEIGHT_H = 26            -- Minimum height in horizontal mode
MIN_HEIGHT_V = 36            -- Minimum height in vertical mode
MIN_WIDTH_H = 42             -- Minimum width in horizontal mode
MARGIN_VERTICAL_FLOW = 3     -- Top/bottom margin when vertical
MARGIN_HORIZONTAL_FLOW = 10  -- Left/right margin when horizontal
MARGIN_VERTICAL_PERP = 3     -- Left/right margin when vertical
MARGIN_HORIZONTAL_PERP = 3   -- Top/bottom margin when horizontal
```

## Layout Mechanism

### Dynamic Container Recreation

**Critical limitation**: OTClient does not support changing layout type at runtime via Lua.

To change from horizontal to vertical:
1. Old container is destroyed
2. New container is created with the correct OTUI style:
   - Vertical: `SpecialConditionIconContainerVertical` (verticalBox)
   - Horizontal: `SpecialConditionIconContainerHorizontal` (horizontalBox)
3. All condition icons are recreated in the new container

### Size Transitions

Panel size changes are animated:
- Duration: 220ms
- Step interval: 30ms
- Flag `sizeAnimating` prevents repositioning during animation
- Centering padding is recalculated at each step

## Common Debugging Scenarios

### HUD Not Visible
1. Check if option is enabled: `modules.client_options.getOption('showSpecialConditionHUD')`
2. Verify panel exists and is visible: `conditionHudPanel and conditionHudPanel:isVisible()`
3. Check if player is in-game: `g_game.isOnline()`

### Edit Mode Label Mispositioned
- For rotated labels (vertical mode), use `visualRect` from MCP, not `rect`
- `rect` is the unrotated layout box; `visualRect` is the actual visual position
- See `.cursor/rules/otclient-ui.md` for rotation details

### Action Strip Not Updating
- Action strip must be **recreated**, not just updated, when orientation changes
- Use `recreateEditActionStrip(vertical)` instead of `updateEditActionStripLayout(vertical)` when switching orientation

### Icons Overlapping or Offset
- Verify `MARGIN_HORIZONTAL_PERP` is set correctly (3px, not 6px)
- Check that `applyCenteringPadding()` is called after size changes
- Ensure layout type matches orientation (verticalBox vs horizontalBox)

## HUD Manager Integration

`game_specialconditionhud` exposes `getHudManagerDefinition()` which returns a definition table for `game_hud_manager`. This is auto-registered when the HUD Manager is opened.

### Condition Entries Format

`getConditionEntries()` returns a list of entries used by the HUD Manager's icon grid:

```lua
{
  id      = 'condition_burning',          -- unique ID (from Icons[].id)
  label   = 'You are burning',            -- tooltip / display name
  enabled = true,                         -- current per-condition toggle state
  icon    = {                             -- enables visual icon grid in HUD Manager
    source = '/images/game/states/player-state-flags',
    clip   = '9 0 9 9',                   -- (iconData.clip - 1) * 9 for x offset
  }
}
```

The `icon` field was added to allow the HUD Manager to display conditions as a visual grid of game icons (matching what the player sees in-game) instead of a text checkbox list. The clip formula is:
```lua
clip = string.format('%d 0 9 9', (iconData.clip - 1) * 9)
```

Conditions are defined in `modules/gamelib/player.lua` via `Icons[PlayerStates.X]` entries with `clip`, `tooltip`, and `id` fields. The list is **static and client-side** — the backend only sends a `PlayerStates` bitfield indicating which are currently active.

## Relationship with game_ui_edit

`game_specialconditionhud` **depends on** `game_ui_edit` for:
- Edit mode detection: `isEditMode()`
- Label creation: `createEditModeLabel()`
- Action strip creation: `createHudActionStrip()`
- HUD manager: `openHudManager()`
- Edit mode listeners: `addEditModeListener()`

The module registers an edit mode listener to show/hide draggability and edit UI elements.

## Development Notes

- Live reload is enabled - code changes are automatically reflected
- Check console for errors if HUD disappears after changes
- Verify `showSpecialConditionHUD` option is enabled if HUD is not visible

---

## 📝 Maintaining This Document

**This is a living document.** When you discover:
- New functions or API changes
- Additional constants or configuration options
- New integration patterns with other modules
- Common bugs or debugging scenarios
- Architecture changes or refactorings

**Update this file immediately** by adding the new information to the relevant section. Keep it concise and accurate.
