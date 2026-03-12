/**
 * OTClient MCP Server v0.1
 * Entry point
 */

import path from 'path';
import { fileURLToPath } from 'url';
import { Storage } from './storage.js';
import { WebSocketBridge } from './websocket-bridge.js';
import { ScreenshotManager } from './screenshot-manager.js';
import { DiffEngine } from './diff-engine.js';
import { MCPServer } from './mcp-server.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  try {
    // Initialize storage with explicit path relative to this file
    const screenshotsDir = path.join(__dirname, '..', 'screenshots');
    console.error('[Main] Current working directory:', process.cwd());
    console.error('[Main] __dirname:', __dirname);
    console.error('[Main] Screenshots directory:', screenshotsDir);
    
    const storage = new Storage({ screenshotsDir });
    await storage.init();

    // Initialize WebSocket bridge
    const wsBridge = new WebSocketBridge(8765);

    // Initialize screenshot manager
    const screenshotManager = new ScreenshotManager(storage, wsBridge);

    // Initialize diff engine
    const diffEngine = new DiffEngine();

    // Initialize and start MCP server
    const mcpServer = new MCPServer(screenshotManager, diffEngine);
    await mcpServer.start();

    console.error('[Main] OTClient MCP Server v0.1 started');
    console.error('[Main] WebSocket server listening on port 8765');
    console.error('[Main] Waiting for OTClient to connect...');
  } catch (error) {
    console.error('[Main] Fatal error:', error);
    process.exit(1);
  }
}

main();
