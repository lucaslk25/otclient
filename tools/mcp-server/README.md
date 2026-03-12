# OTClient MCP Server v0.1

MCP (Model Context Protocol) server for OTClient that enables AI-assisted development through screenshot capture and UI diff analysis.

## Features

- 📸 **Screenshot Capture**: Full window or map-only screenshots
- 🔍 **Visual Diff**: Pixel-by-pixel comparison with highlighted changes
- 🌳 **Structural Diff**: UI widget tree comparison
- 💾 **Hybrid Storage**: Memory cache + disk persistence
- 🏷️ **Annotations**: Tag and annotate screenshots
- 🔄 **Real-time**: WebSocket communication with OTClient

## Installation

### Prerequisites

- Node.js 18+ 
- OTClient compiled with WebSocket support

### Setup

1. Install dependencies:

```bash
cd tools/mcp-server
npm install
```

2. Build TypeScript:

```bash
npm run build
```

3. Configure MCP in Cursor:

Add to your MCP configuration (see `mcp-settings.json` for example):

```json
{
  "mcpServers": {
    "otclient": {
      "command": "node",
      "args": ["FULL_PATH/otclient/tools/mcp-server/dist/index.js"]
    }
  }
}
```

Replace `FULL_PATH` with your actual path.

## Usage

### Starting the Server

1. Start the MCP server:

```bash
npm start
```

2. Start OTClient (the mcp_bridge module will auto-connect)

3. Use AI assistant with MCP tools

### Available Tools

#### 1. `capture_screenshot`

Capture a screenshot from OTClient.

**Parameters:**
- `type`: `"full"` (entire window) or `"map"` (game map only)
- `annotation` (optional): Description of the screenshot

**Example:**
```
AI: "Take a screenshot of the login screen"
→ capture_screenshot(type="full", annotation="Login screen")
```

#### 2. `get_screenshot`

Retrieve a screenshot by ID with image data.

**Parameters:**
- `id`: Screenshot ID

**Returns:** Screenshot metadata + base64 image

#### 3. `list_screenshots`

List all captured screenshots.

**Parameters:**
- `limit` (optional): Max results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

#### 4. `diff_screenshots_visual`

Compare two screenshots visually (pixel-by-pixel).

**Parameters:**
- `id1`: First screenshot ID
- `id2`: Second screenshot ID
- `threshold` (optional): Pixel difference threshold 0-1 (default: 0.1)

**Returns:**
- Diff percentage
- Diff image (base64)
- Changed regions coordinates

#### 5. `diff_screenshots_structural`

Compare UI widget trees structurally.

**Parameters:**
- `id1`: First screenshot ID
- `id2`: Second screenshot ID

**Returns:**
- Added widgets
- Removed widgets
- Modified widgets with property changes

#### 6. `annotate_screenshot`

Add or update annotation for a screenshot.

**Parameters:**
- `id`: Screenshot ID
- `annotation`: Annotation text
- `tags` (optional): Array of tags

### Available Resources

#### `screenshot://latest`

Returns the most recently captured screenshot (base64).

#### `screenshot://list`

Returns JSON list of all screenshots with metadata.

## Example Workflow

### Scenario: Adjusting UI padding

```
1. Developer: "Capture the current login panel"
   AI: [calls capture_screenshot]
   → Screenshot ss-001 captured

2. Developer: [Edits .otui file to adjust padding]

3. Developer: "Capture again and compare"
   AI: [calls capture_screenshot, then diff_screenshots_visual and diff_screenshots_structural]
   → Visual diff: 2.3% changed
   → Structural diff: loginPanel padding-left changed from 10 to 20

4. AI: "The padding was successfully increased by 10 pixels"
```

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐
│ AI Assistant│◄───────►│  MCP Server  │◄───────►│   OTClient   │
│  (Cursor)   │ JSON-RPC│   (Node.js)  │WebSocket│  (Lua Module)│
└─────────────┘  stdio  └──────────────┘  :8765  └──────────────┘
                              │
                              ├─► Storage (Memory + Disk)
                              ├─► Screenshot Manager
                              ├─► Diff Engine (Visual)
                              └─► Diff Engine (Structural)
```

## Storage

- **Memory Cache**: Last 10 screenshots for fast access
- **Disk Storage**: Full history in `screenshots/` directory
- **Auto Cleanup**: Keeps last 100 screenshots or 7 days
- **Format**: 
  - `{id}.png` - JPEG compressed image
  - `{id}.json` - Metadata + UI tree

## Configuration

Edit `src/storage.ts` to customize:

```typescript
{
  maxMemoryCache: 10,        // Screenshots in memory
  maxDiskScreenshots: 100,   // Max screenshots on disk
  maxAgeDays: 7,             // Auto-delete after N days
  screenshotsDir: './screenshots'
}
```

## Troubleshooting

### OTClient not connecting

1. Check WebSocket server is running (port 8765)
2. Check OTClient console for connection errors
3. Verify `mcp_bridge` module is loaded

### Screenshot capture fails

1. Ensure OTClient has write permissions
2. Check if `g_app.doScreenshot()` is available
3. Verify `g_resources.readFileContents()` works

### Base64 encoding issues

The Lua base64 encoder is simple and may have issues with large files. If screenshots fail to transfer:

1. Reduce screenshot size (use map-only mode)
2. Check OTClient console for errors
3. Consider implementing C++ binding for base64

## Development

### Build

```bash
npm run build
```

### Watch mode

```bash
npm run dev
```

### Clean

```bash
npm run clean
```

## Limitations (v0.1)

- ❌ No terminal logs (planned for v0.2)
- ❌ No command execution (planned for v0.2)
- ❌ No performance metrics (planned for v0.4)
- ❌ Single client only
- ❌ No authentication

## License

MIT

## Author

Lucas
