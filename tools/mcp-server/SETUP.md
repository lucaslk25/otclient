# Setup Guide - OTClient MCP Server v0.1

## Quick Start

### 1. Install Dependencies

```bash
cd tools/mcp-server
npm install
```

### 2. Build

```bash
npm run build
```

### 3. Configure MCP

Copy `mcp-settings.json` content and add to your Cursor MCP configuration.

**Note:** Update the path in `mcp-settings.json` to match your system.

### 4. Start and Test

1. Restart Cursor (MCP server starts automatically)
2. Start OTClient
3. Check console: `[MCP Bridge] Connected to MCP server`
4. Test: "Capture a screenshot of OTClient"

## Troubleshooting

### Connection Issues

If OTClient doesn't connect, check:
- MCP server is running (port 8765)
- OTClient console for error messages
- Firewall not blocking port 8765

### Build Issues

If build fails:
- Ensure Node.js 18+ is installed
- Run `npm install` again
- Check for TypeScript errors

## Verification

Test in OTClient terminal (Ctrl+T):
```lua
print(MCPBridge.connected)  -- Should return: true
```

Test via Cursor:
```
"List available MCP tools"
```

Should show 6 tools: capture_screenshot, get_screenshot, list_screenshots, diff_screenshots_visual, diff_screenshots_structural, annotate_screenshot
