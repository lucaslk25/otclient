# OTClient UI System Rules

**Living Document** - This rule is continuously updated with new findings and discoveries.

This rule documents the OTClient UI system for AI agents working on UI layout and visual debugging tasks.

> **Note**: OTClient has live reload enabled. Code changes are automatically reflected in the running client.

## Widget Rotation System

### How Rotation Works

Widget rotation in OTClient is **purely visual** and applied only during rendering:

- Rotation is applied via transform matrix around the widget's `rect.center()` during draw
- The widget's `m_rect` (layout bounding box) **never changes** due to rotation
- Rotation does **not** affect hit-testing, anchoring, or layout calculations
- See `src/framework/ui/uiwidget.cpp` lines 78-106 for implementation

### Rect vs VisualRect

- **`rect`**: The unrotated bounding box used for layout, anchors, and hit-testing
- **`visualRect`**: The actual visual bounding box after rotation (calculated by MCP Inspector)

**Always use `visualRect` when validating visual positioning of rotated widgets.**

### Example

A label with `rotation: 90` and `rect: {x: 846, y: 509, w: 127, h: 16}`:

- The `rect` is the layout box (horizontal, 127×16)
- After 90° rotation around center, the visual appearance is vertical (~16×127)
- The `visualRect` will be `{x: ~791, y: ~453, w: ~16, h: ~127}` (approximate, due to rotation)
- The label will appear ~55px to the left and ~55px above where `rect` indicates

## Anchoring System

### Available Anchors

- `AnchorLeft`, `AnchorRight`, `AnchorTop`, `AnchorBottom`
- `AnchorHorizontalCenter`, `AnchorVerticalCenter`

### Anchor Rules

1. Anchors define relationships between widget edges and reference widget edges
2. Syntax: `widget:addAnchor(AnchorType, 'referenceWidgetId', ReferenceAnchorType)`
3. Use `'parent'` as reference for parent widget
4. Multiple anchors can be combined to define size and position
5. Anchors use the **unrotated `rect`**, not `visualRect`

### Common Patterns

```lua
-- Anchor to parent's left edge with margin
widget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
widget:setMarginLeft(10)

-- Anchor to sibling's right edge
widget:addAnchor(AnchorLeft, 'siblingId', AnchorRight)
widget:setMarginLeft(4)  -- gap between widgets

-- Center horizontally in parent
widget:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)

-- Fill parent width
widget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
widget:addAnchor(AnchorRight, 'parent', AnchorRight)
```

## Margins vs Padding

- **Margins**: External spacing between widget and its anchor reference
  - `setMarginTop/Right/Bottom/Left(pixels)`
  - Margins affect positioning relative to anchors
  - Margins are applied **after** anchor calculation

- **Padding**: Internal spacing between widget's border and its content/children
  - Defined in OTUI styles: `padding-top/right/bottom/left: pixels`
  - Padding affects child widget positioning within parent
  - Padding is **not** exposed to Lua API (style-only)

## Layout Types

Layout types control how children are arranged within a container:

- **`horizontalBox`**: Children arranged left-to-right with `spacing`
- **`verticalBox`**: Children arranged top-to-bottom with `spacing`
- **`grid`**: Children arranged in grid with `cell-size`, `cell-spacing`, `num-columns`
- **`anchor`**: Children positioned via explicit anchors (default)

### Important Limitation

**You cannot change layout type at runtime via Lua.** There is no `layout:setType()` in the API.

To change layout type dynamically:
1. Create separate OTUI styles for each layout type
2. Destroy the widget
3. Recreate it with `g_ui.createWidget('StyleName', parent)`

Example: `HudEditActionStrip` (horizontal) vs `HudEditActionStripVertical` (vertical)

## Available Fonts

The following fonts are available (located in `data/fonts/`):

### Verdana Variants (Most Common)

- **Bold 11px**: `Verdana Bold-11px` (standard UI font)
- **Bold 10px**: `Verdana Bold-10px`
- **Bold 13px**: `Verdana Bold-13px`
- **Regular 11px**: `verdana-11px-antialised`, `verdana-11px-monochrome`, `verdana-11px-rounded`
- **Regular 10px**: `verdana-10px`, `Verdana-10px-antialiased`
- **Regular 9px**: `verdana-9px`, `Verdana-9px-antialiased`, `verdana-9px-bold`, `verdana-9px-rounded`
- **Regular 8px**: `Verdana-8px`, `Verdana-8px-antialiased`, `verdana-8px-rounded`
- **Regular 7px**: `verdana-7px-rounded`

### Other Fonts

- **Terminus**: `terminus-10px`, `terminus-14px-bold`
- **Sans**: `sans-bold-16px`
- **Small**: `small-9px`
- **Icon**: `Icon-VBold-11px`
- **CipSoft**: `cipsoftFont`

### Font Quality Notes

- **Antialiased** fonts are smoother but may be less crisp at small sizes
- **Monochrome** fonts are crisper but have hard edges
- **Rounded** fonts have slightly rounded glyphs for better readability
- **Low-space** variants have tighter character spacing

## Using MCP for Visual Debugging

The MCP (Model Context Protocol) server provides reliable tools for UI debugging:

### Trust the MCP Data

After Phase 1 enhancements, the MCP Inspector reports:
- `rotation`: Widget rotation in degrees
- `margins`: All four margins (top, right, bottom, left)
- `font`: Font name
- `parentId`: Parent widget ID for hierarchy understanding
- `visualRect`: **Accurate visual bounding box for rotated widgets**

### Recommended Workflow

1. **Capture**: Use `capture_screenshot` to take a snapshot
2. **Inspect**: Use `inspect_ui` with `mode: 'query'` to find widgets
   - For rotated widgets, check both `rect` and `visualRect`
   - Use `visualRect` for visual position validation
3. **Analyze**: Use `inspect_ui` with `mode: 'analyze'` to detect overlaps/coverage
   - Overlap detection uses `visualRect` for rotated widgets
4. **Diff**: Use `diff_screenshots` for before/after comparisons

### Validating Positioning

```typescript
// For non-rotated widgets: use rect
if (!widget.rotation || widget.rotation === 0) {
  validatePosition(widget.rect);
}

// For rotated widgets: use visualRect
if (widget.rotation && widget.rotation !== 0) {
  validatePosition(widget.visualRect); // This is the actual visual position
}
```

## Common Pitfalls

1. **Trying to change layout type dynamically**: Not possible - must recreate widget
2. **Using `rect` for rotated widgets**: Will give incorrect visual position - use `visualRect`
3. **Anchoring to rotated widgets**: Anchors use `rect`, not `visualRect` - expect unexpected results
4. **Setting width/height to nil**: May crash the widget - always provide valid dimensions
5. **Forgetting to call `widget:raise()`**: Widget may be drawn behind siblings
6. **Not breaking anchors before re-anchoring**: Old anchors persist - use `breakAnchors()` first
7. **No `setX`/`setY` in Lua**: OTClient does not expose `widget:setX(n)` or `widget:setY(n)` as standalone methods. To absolutely position a widget within a container (anchor layout), use `addAnchor(AnchorLeft, 'parent', AnchorLeft)` + `setMarginLeft(n)` and `addAnchor(AnchorTop, 'parent', AnchorTop)` + `setMarginTop(n)`. This is the correct idiom for grid-like manual layouts in Lua.
8. **`border-width` does not follow `background-radius`**: Borders are drawn as straight lines even when the background has rounded corners. This is a rendering limitation. Accept the 1px trade-off for the glass depth effect -- removing borders entirely makes the UI look flat
9. **UIWindow native text**: UIWindow draws its `text` property natively at the position set by `text-align` and `text-offset`. If you create a custom title Label inside, set `color: alpha` on the UIWindow to hide its native text and avoid duplication
10. **Unicode characters in bitmap fonts**: OTClient bitmap fonts (e.g. `Verdana Bold-11px`) only contain standard ASCII glyphs. Special characters like `×` (U+00D7) will render as broken/missing. Use ASCII equivalents (e.g. `X`) instead
11. **MCP `inspect_ui` ID collisions**: When querying by `ids`, the MCP matches ALL widgets with that ID across the entire UI tree (e.g. `closeButton` exists on every miniwindow). Always verify `parentId` in results or use `ancestors` mode to confirm the correct widget
12. **MCP `region` capture uses physical pixels**: The `region` parameter in `capture_screenshot` uses physical screen pixel coordinates (before DPI scaling), while the rendered screenshot image uses logical coordinates. On high-DPI screens these don't match, causing region captures to show the wrong area. **Always use `type: "full"` for reliable analysis** and inspect the image directly — never rely on region coordinates derived from looking at a full screenshot.

## Glassmorphism Design System

Reusable glass-effect styles are defined in `data/styles/10-glass.otui` (global) and `modules/game_hud_manager/glass_styles.otui` (module-local). Available components:

- **GlassPanel**: Base container with semi-transparent background, rounded corners, and light/shadow borders
- **GlassWindow**: UIWindow variant with glass background, hidden native title text (`color: alpha`)
- **GlassListRow**: List item with hover/selected glow and status indicator dot
- **GlassCheckBox**: Checkbox matching the glass aesthetic
- **GlassSectionTitle**: Section header with accent underline
- **GlassButton** / **GlassButtonSmall**: Buttons with glass surface and hover effects
- **GlassSeparator**: Thin horizontal divider

### Loading Glass Styles in Modules

The `data/styles/` folder is loaded by `client_styles` module at startup via `importResources("styles", "otui", device)`. For modules that load lazily, also import via `g_ui.importStyle('glass_styles')` with a copy in the module folder.

## Additional Resources

- See `AGENTS.md` in module directories for architecture documentation
- See `C:\Users\lucas\.cursor\skills\otclient-mcp-visual-debug\SKILL.md` for MCP usage patterns
- See source code in `src/framework/ui/` for implementation details

---

## 📝 Maintaining This Document

**This is a living document.** When you discover:
- New UI system behaviors or limitations
- Additional anchor patterns or layout techniques
- New fonts or font-related issues
- Common pitfalls not documented here
- Better debugging approaches

**Update this file immediately** by adding the new information to the relevant section. Keep it concise and actionable.
