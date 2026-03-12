/**
 * WebSocket bridge for communication with OTClient
 */

import { WebSocketServer, WebSocket } from 'ws';
import { WSMessage, ScreenshotCapturedResponse, CaptureScreenshotRequest } from './types.js';

export class WebSocketBridge {
  private wss: WebSocketServer;
  private client: WebSocket | null = null;
  private requestHandlers: Map<string, (data: any) => void> = new Map();
  private nextRequestId = 1;
  private port: number;

  constructor(port: number = 8765) {
    this.port = port;
    this.wss = new WebSocketServer({ 
      port,
      host: '0.0.0.0' // Listen on all interfaces (IPv4)
    });
    this.setupServer();
  }

  private setupServer(): void {
    this.wss.on('connection', (ws: WebSocket) => {
      console.log('[WebSocket] Client connected');
      this.client = ws;

      ws.on('message', (data: Buffer) => {
        try {
          const message: WSMessage = JSON.parse(data.toString());
          this.handleMessage(message);
        } catch (error) {
          console.error('[WebSocket] Error parsing message:', error);
        }
      });

      ws.on('close', () => {
        console.log('[WebSocket] Client disconnected');
        this.client = null;
      });

      ws.on('error', (error) => {
        console.error('[WebSocket] Error:', error);
      });
    });

    console.log(`[WebSocket] Server listening on port ${this.port}`);
  }

  private handleMessage(message: WSMessage): void {
    console.log('[WebSocket] Received message:', JSON.stringify(message).substring(0, 200));
    
    // Handle responses to our requests
    if (message.requestId && this.requestHandlers.has(message.requestId)) {
      const handler = this.requestHandlers.get(message.requestId);
      if (handler) {
        console.log('[WebSocket] Calling handler for request:', message.requestId);
        handler(message.data || message.error);
        this.requestHandlers.delete(message.requestId);
      }
      return;
    }

    // Handle unsolicited messages from client
    console.log('[WebSocket] No handler found for message type:', message.type, 'requestId:', message.requestId);
  }

  async sendCommand(command: string, params: any = {}): Promise<any> {
    if (!this.client || this.client.readyState !== WebSocket.OPEN) {
      throw new Error('WebSocket client not connected');
    }

    const requestId = `req-${this.nextRequestId++}`;
    
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.requestHandlers.delete(requestId);
        reject(new Error('Request timeout'));
      }, 30000); // 30 second timeout

      this.requestHandlers.set(requestId, (data) => {
        clearTimeout(timeout);
        if (data && data.error) {
          reject(new Error(data.error));
        } else {
          resolve(data);
        }
      });

      const message: WSMessage = {
        type: 'command',
        requestId,
        command,
        params,
      };

      console.log('[WebSocket] Sending command:', command, 'requestId:', requestId);
      this.client!.send(JSON.stringify(message));
    });
  }

  async captureScreenshot(type: 'full' | 'map', annotation?: string): Promise<ScreenshotCapturedResponse> {
    const params: CaptureScreenshotRequest = { type, annotation };
    return await this.sendCommand('capture_screenshot', params);
  }

  async getUITree(maxDepth: number = 5): Promise<any> {
    return await this.sendCommand('get_ui_tree', { maxDepth });
  }

  isConnected(): boolean {
    return this.client !== null && this.client.readyState === WebSocket.OPEN;
  }

  close(): void {
    if (this.client) {
      this.client.close();
    }
    this.wss.close();
  }
}
