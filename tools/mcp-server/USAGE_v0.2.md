# MCP Server v0.2 - Usage Guide

## Quick Start

### 1. Capture & View Screenshots

```typescript
// Capture new screenshot
capture_screenshot({ type: "full" })
// → Returns: Renderable image + { id, timestamp, width, height, type }

// View existing screenshot
capture_screenshot({ id: "screenshot-1773105551863" })
// → Returns: Same format, no new capture
```

### 2. Find Specific Widgets

```typescript
// Find all condition HUD widgets
inspect_ui({
  mode: "query",
  source: "latest",
  ids: ["conditionHUD*"]
})
// → Returns: { mode: "query", count: 3, widgets: [...] }

// Find all buttons in a region
inspect_ui({
  mode: "query",
  source: "screenshot-123",
  classes: ["UIButton"],
  region: { x: 700, y: 400, width: 300, height: 200 }
})
```

### 3. Detect Layout Issues

```typescript
// Analyze latest screenshot for problems
inspect_ui({
  mode: "analyze",
  source: "latest",
  checks: ["overlaps", "coverage", "zero_size"]
})
// → Returns: { mode: "analyze", summary: "...", issues: [...] }

// Focus analysis on specific widgets
inspect_ui({
  mode: "analyze",
  source: "latest",
  checks: ["overlaps"],
  scope: ["conditionHUD*", "editMode*", "hudAction_*"]
})
```

### 4. Compare Screenshots (Smart Diff)

```typescript
// Full smart diff
diff_screenshots({
  id1: "screenshot-1773105551863",
  id2: "screenshot-1773105606241",
  detect_issues: true
})
// → Returns:
//   - Diff image (renderable)
//   - Visual: { diffPercentage, changedRegions }
//   - Structural: { addedWidgets, removedWidgets, modifiedWidgets }
//   - Issues: [{ type, severity, description, widgets }]
//   - Summary: "Large visual change (12.3% pixels changed). 11 widgets changed..."

// Focused diff (analyze only specific widgets)
diff_screenshots({
  id1: "screenshot-123",
  id2: "screenshot-456",
  focus: ["conditionHUD*", "editMode*"],
  detect_issues: true
})
```

### 5. Get Widget Hierarchy

```typescript
// Trace widget's parent chain
inspect_ui({
  mode: "ancestors",
  source: "latest",
  widget_id: "editModeLabel"
})
// → Returns: { mode: "ancestors", depth: 5, chain: [root, ..., widget] }
```

## Real-World Example

**Scenario:** User changes condition HUD orientation, buttons cover label.

**v0.1 Workflow (6+ tool calls):**
```
1. capture_screenshot({ type: "full" })
2. (user changes orientation)
3. capture_screenshot({ type: "full" })
4. diff_screenshots_structural(id1, id2)
5. get_screenshot(id1) → 3MB JSON blob
6. grep "editModeLabel" in JSON
7. grep "hudAction_" in JSON
8. Manual rect overlap calculation
```

**v0.2 Workflow (3 tool calls):**
```
1. capture_screenshot({ type: "full" })
   → SEE image
2. (user changes orientation)
3. capture_screenshot({ type: "full" })
   → SEE image
4. diff_screenshots({
     id1: "screenshot-123",
     id2: "screenshot-456",
     focus: ["conditionHUD*", "editMode*", "hudAction_*"],
     detect_issues: true
   })
   → SEE diff image + automatic issue detection:
   "ISSUE: hudAction_orientation overlaps with editModeLabel (324px² intersection)"
```

## Layout Issue Types

### Overlap
Two sibling widgets with intersecting rects.
- **Severity:** ERROR if >100px², WARNING otherwise
- **Example:** Action buttons overlapping with label

### Coverage
Widget A completely covers widget B.
- **Severity:** WARNING
- **Example:** Modal covering background content

### Out of Bounds
Widget extends outside parent bounds.
- **Severity:** INFO
- **Example:** Tooltip extending beyond window

### Zero Size
Visible widget with width=0 or height=0.
- **Severity:** WARNING
- **Example:** Collapsed panel still marked visible

## Tips

1. **Always use `detect_issues: true`** in diffs - it's free and catches problems automatically
2. **Use glob patterns** for widget queries - `"conditionHUD*"` is more robust than exact IDs
3. **Focus diffs** when you know what changed - reduces noise in results
4. **Use `ancestors` mode** to understand widget hierarchy and anchoring
5. **Check `phantom` property** - phantom widgets don't block mouse events

## Performance

- **80% less data transfer** (no 3MB base64 in JSON)
- **3x fewer tool calls** for typical workflows
- **Zero grep needed** for widget queries
- **Images are renderable** - AI can see them directly
