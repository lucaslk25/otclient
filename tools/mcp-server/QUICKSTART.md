# Quick Start - OTClient MCP Server

## Installation (One-time)

```bash
cd tools/mcp-server
npm install
npm run build
```

## Configuration

1. Copy the path from `mcp-settings.json`
2. Add to your Cursor MCP configuration
3. Restart Cursor

## Usage

1. Start OTClient
2. Verify connection: `[MCP Bridge] Connected to MCP server`
3. Use via Cursor AI:

```
"Capture a screenshot of OTClient"
"List all screenshots"
"Compare the last two screenshots"
```

## Available Tools

- `capture_screenshot` - Capture full window or map
- `get_screenshot` - Get screenshot by ID
- `list_screenshots` - List all screenshots
- `diff_screenshots_visual` - Visual pixel comparison
- `diff_screenshots_structural` - UI widget tree comparison
- `annotate_screenshot` - Add notes to screenshots

## Troubleshooting

**OTClient won't connect?**
- Check MCP server is running (Cursor starts it automatically)
- Verify port 8765 is not blocked
- Check OTClient console for errors

**Screenshot fails?**
- Ensure OTClient has write permissions
- Try `type="map"` instead of `type="full"`

## Documentation

- `README.md` - Complete documentation
- `SETUP.md` - Detailed setup guide
- `IMPLEMENTATION_SUMMARY.md` - Technical details
- `FIXES_APPLIED.md` - C++ fixes applied
