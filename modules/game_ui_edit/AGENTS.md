# UI Edit Mode Module

**Living Document** - This documentation is continuously updated with new findings and API changes.

## Overview

The `game_ui_edit` module provides a UI customization framework for OTClient. It enables users to drag, resize, and configure HUD elements through an "edit mode" system with visual feedback and a centralized HUD manager.

## Architecture

### Core Components

1. **Lock Button**: Top-left toggle button to enter/exit edit mode
2. **HUD Manager Button**: Below lock button, opens the HUD configuration panel
3. **Edit Mode Labels**: Text labels that appear on HUD elements in edit mode
4. **Action Strips**: Button strips attached to HUD elements with quick actions

### Widget Hierarchy

Lock and HUD Manager buttons are created as children of the map panel:

```
mapPanel
├── lockButtonPanel
│   └── lockButton (UIButton)
└── hudManagerButtonPanel
    └── hudManagerButton (UIButton)
```

Edit mode labels and action strips are created as **siblings** of HUD panels (in root panel or game panel), not as children:

```
rootPanel
├── someHudPanel (e.g., conditionHUDPanel)
├── editModeLabel (anchored to someHudPanel)
└── hudEditActionStrip (anchored to someHudPanel)
```

## Public API

### Edit Mode State

```lua
-- Check if edit mode is active
function isEditMode() -> boolean

-- Enable or disable edit mode
function setEditMode(enabled: boolean)

-- Register a callback for edit mode changes
-- Returns an unregister function
function addEditModeListener(callback: function(enabled: boolean)) -> function
```

### UI Element Creation

```lua
-- Create an edit mode label for a HUD element
-- parentWidget: The HUD panel to attach the label to
-- labelText: Text to display on the label
-- Returns: { widget, destroy } handle
function createEditModeLabel(parentWidget, labelText) -> table

-- Create an action strip for a HUD element
-- parentWidget: The HUD panel to attach the strip to
-- opts: Configuration options (see below)
-- Returns: { widget, refresh, destroy } handle
function createHudActionStrip(parentWidget, opts) -> table

-- Open the HUD manager dialog
-- initialHudId: Optional HUD ID to select initially
function openHudManager(initialHudId: string?)
```

### Action Strip Options

```lua
opts = {
  rootPanel = widgetRef,  -- Parent for the strip (default: parentWidget)
  vertical = false,       -- Use vertical layout (default: false)
  actions = {             -- Array of action button definitions
    {
      id = 'action-id',          -- Unique identifier
      icon = '/path/to/icon',    -- Icon path (optional)
      text = 'Text',             -- Button text (optional, if no icon)
      getText = function()       -- Dynamic text (optional)
        return 'Text'
      end,
      tooltip = 'Tooltip text',  -- Static tooltip
      tooltip = function(state)  -- Dynamic tooltip for checkable actions
        return state and 'On' or 'Off'
      end,
      onClick = function(state?) -- Click handler
        -- For checkable actions, receives new state
        -- For regular actions, receives no arguments
      end,
      checkable = false,         -- If true, button acts as toggle
      getState = function()      -- Get current state for checkable actions
        return true/false
      end,
      forceIconSize = false      -- Force icon to ACTION_BUTTON_SIZE (18px)
    }
  }
}
```

### Return Handle Structure

Both `createEditModeLabel` and `createHudActionStrip` return handles with:

```lua
{
  widget = widgetRef,        -- The created widget
  destroy = function()       -- Cleanup function (removes widget and unregisters listeners)
  refresh = function()       -- (Action strip only) Refresh button states
}
```

## OTUI Styles

### Edit Mode Label

Defined in `edit_mode_label.otui`:

```otui
EditModeLabel < UILabel
  font: verdana-11px-rounded
  text-auto-resize: true
  color: #dfdfdfff
  background-color: #00000088
  text-offset: 4 2
  phantom: true
  focusable: false
  opacity: 0.85
```

### Action Strip Styles

Defined in `edit_action_strip.otui`:

#### Horizontal (default)

```otui
HudEditActionStrip < UIWidget
  height: 20
  layout:
    type: horizontalBox
    spacing: 2
    fit-children: true
  image-source: /images/ui/1pixel_down_frame
  image-border: 1
  background-color: #00000066
  padding-left: 2
  padding-right: 2
  padding-top: 1
  padding-bottom: 1
  phantom: true
  focusable: false
  opacity: 0.95
```

#### Vertical

```otui
HudEditActionStripVertical < UIWidget
  width: 22
  layout:
    type: verticalBox
    spacing: 2
    fit-children: true
  image-source: /images/ui/1pixel_down_frame
  image-border: 1
  background-color: #00000066
  padding-left: 1
  padding-right: 1
  padding-top: 2
  padding-bottom: 2
  phantom: true
  focusable: false
  opacity: 0.95
```

### Action Button Styles

```otui
HudEditActionButton < UIButton
  size: 18 18
  image-source: /images/ui/button_square_flat
  image-color: #dfdfdfff
  icon-color: #dfdfdfff
  $hover:
    image-color: #f2f2f2ff
    icon-color: #f2f2f2ff
  $pressed:
    image-color: #c2c2c2ff
    icon-color: #c2c2c2ff

HudEditActionToggle < HudEditActionButton
  $on:
    image-color: #4CAF50
    icon-color: white
```

## Important Limitations

### Layout Type Cannot Be Changed at Runtime

There is **no `layout:setType()` method** in the Lua API. To support both horizontal and vertical orientations:

1. Create two separate OTUI styles (`HudEditActionStrip` and `HudEditActionStripVertical`)
2. When orientation changes, destroy the old strip and recreate it with the correct style
3. Use the `opts.vertical` parameter in `createHudActionStrip()` to select the style

Example:

```lua
-- Destroy old strip
if editActionStripHandle and editActionStripHandle.destroy then
  editActionStripHandle.destroy()
  editActionStripHandle = nil
end

-- Recreate with vertical orientation
editActionStripHandle = modules.game_ui_edit.createHudActionStrip(parentWidget, {
  rootPanel = rootPanel,
  vertical = true,  -- Selects HudEditActionStripVertical
  actions = { ... }
})
```

### Action Strip Placement

Action strips are typically created on the **rootPanel**, not inside the HUD panel itself. This is because:

1. Strips need to draw in the same layer as lock/HUD manager buttons
2. Creating them inside the HUD panel can cause rendering issues
3. Anchoring to the HUD panel from outside works correctly

```lua
local rootPanel = modules.game_interface.getRootPanel()
editActionStripHandle = modules.game_ui_edit.createHudActionStrip(hudPanel, {
  rootPanel = rootPanel,  -- Strip is created on rootPanel, not hudPanel
  -- ...
})
```

## Constants

```lua
LOCK_BUTTON_SIZE = 24
HUD_MANAGER_BUTTON_MARGIN_TOP = 6
MARGIN_LEFT_PING = 28
EDIT_LABEL_MARGIN_TOP = -12
ACTION_BUTTON_SIZE = 18
STRIP_BUTTON_TEXT_FONT = 'verdana-7px-rounded'
```

## Settings Persistence

Edit mode state is saved per-character in `g_settings` under key `'UIEditMode'`:

```lua
{
  [characterName] = {
    enabled = false  -- Whether edit mode is enabled
  }
}
```

## Integration Pattern

Typical usage in a HUD module:

```lua
local editModeLabelHandle = nil
local editActionStripHandle = nil

local function setupEditMode(hudPanel)
  -- Create edit mode label
  editModeLabelHandle = modules.game_ui_edit.createEditModeLabel(
    hudPanel,
    tr('my hud name')
  )
  
  -- Create action strip
  local rootPanel = modules.game_interface.getRootPanel()
  editActionStripHandle = modules.game_ui_edit.createHudActionStrip(hudPanel, {
    rootPanel = rootPanel,
    vertical = isVerticalMode(),
    actions = {
      {
        id = 'orientation',
        tooltip = tr('Toggle orientation'),
        icon = '/game_cyclopedia/images/icon-refresh',
        onClick = function()
          toggleOrientation()
        end
      },
      {
        id = 'settings',
        tooltip = tr('Open settings'),
        icon = '/images/ui/icon-edit',
        onClick = function()
          openSettings()
        end
      }
    }
  })
  
  -- Listen for edit mode changes
  local unregister = modules.game_ui_edit.addEditModeListener(function(enabled)
    hudPanel:setDraggable(enabled)
    hudPanel:setPhantom(not enabled)
  end)
end

local function terminateEditMode()
  if editModeLabelHandle and editModeLabelHandle.destroy then
    editModeLabelHandle.destroy()
    editModeLabelHandle = nil
  end
  
  if editActionStripHandle and editActionStripHandle.destroy then
    editActionStripHandle.destroy()
    editActionStripHandle = nil
  end
end
```

## Dependencies

`game_ui_edit` depends on:
- `game_interface`: For map panel and root panel access
- `game_hud_manager`: For HUD configuration dialog

Other modules depend on `game_ui_edit` for:
- Edit mode detection
- Label and action strip creation
- Edit mode state synchronization

## Common Debugging Scenarios

### Action Strip Not Visible in Edit Mode
1. Verify `strip:setVisible(editMode)` is called
2. Check `strip:raise()` is called to bring to front
3. Ensure strip is created on `rootPanel`, not inside HUD panel

### Edit Mode Label Mispositioned with Rotation
- Use `visualRect` from MCP Inspector for rotated labels
- See `.cursor/rules/otclient-ui.md` for rotation details
- `rect` is the layout box; `visualRect` is the actual visual position

### Action Strip Orientation Not Updating
- Must **recreate** the strip with the correct style, not just update anchors
- Use `editActionStripHandle.destroy()` then call `createHudActionStrip()` again
- Pass `vertical: true` or `vertical: false` in options

### Buttons Not Updating State
- Call `editActionStripHandle.refresh()` after state changes
- Ensure `getState()` function is provided for checkable actions
- Refresh is automatically called on clicks and edit mode changes

## Development Notes

- Live reload is enabled - code changes are automatically reflected
- Reloading destroys existing edit mode UI elements - dependent modules must recreate their labels and action strips
- Check console for errors if edit mode elements disappear after changes

---

## 📝 Maintaining This Document

**This is a living document.** When you discover:
- New API functions or parameter options
- Additional OTUI styles or variants
- New integration patterns or use cases
- Common issues or debugging scenarios
- Changes to constants or default values

**Update this file immediately** by adding the new information to the relevant section. Keep it concise and accurate.
