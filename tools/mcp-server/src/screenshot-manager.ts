/**
 * Screenshot manager with hybrid storage
 */

import sharp from 'sharp';
import { Screenshot, ScreenshotCapturedResponse } from './types.js';
import { Storage } from './storage.js';
import { WebSocketBridge } from './websocket-bridge.js';

export class ScreenshotManager {
  private storage: Storage;
  private wsBridge: WebSocketBridge;

  constructor(storage: Storage, wsBridge: WebSocketBridge) {
    this.storage = storage;
    this.wsBridge = wsBridge;
  }

  async capture(type: 'full' | 'map', annotation?: string): Promise<Screenshot> {
    if (!this.wsBridge.isConnected()) {
      throw new Error('OTClient not connected');
    }

    // Request screenshot from OTClient
    const response: ScreenshotCapturedResponse = await this.wsBridge.captureScreenshot(type, annotation);

    // Validate response
    if (!response || !response.imageBase64) {
      throw new Error('Invalid screenshot response from OTClient');
    }

    // Convert base64 to buffer
    const imageBuffer = Buffer.from(response.imageBase64, 'base64');

    // Keep as PNG for diff compatibility
    const pngBuffer = await sharp(imageBuffer)
      .png()
      .toBuffer();

    // Get image dimensions
    const metadata = await sharp(imageBuffer).metadata();
    const width = metadata.width || response.width;
    const height = metadata.height || response.height;

    // Create screenshot object
    const screenshot: Screenshot = {
      id: `screenshot-${Date.now()}`,
      timestamp: Date.now(),
      type,
      width,
      height,
      imagePath: '', // Will be set by storage
      imageBuffer: pngBuffer,
      uiTree: response.uiTree,
      annotation,
    };

    // Store screenshot
    await this.storage.store(screenshot);

    console.log(`[ScreenshotManager] Captured ${type} screenshot: ${screenshot.id}`);

    return screenshot;
  }

  async get(id: string): Promise<Screenshot | null> {
    return await this.storage.get(id);
  }

  async getImageBase64(id: string): Promise<string | null> {
    const screenshot = await this.storage.get(id);
    if (!screenshot || !screenshot.imageBuffer) {
      return null;
    }

    return screenshot.imageBuffer.toString('base64');
  }

  async list(limit: number = 50, offset: number = 0): Promise<Screenshot[]> {
    return await this.storage.list(limit, offset);
  }

  async annotate(id: string, annotation: string, tags?: string[]): Promise<boolean> {
    return await this.storage.annotate(id, annotation, tags);
  }

  async delete(id: string): Promise<void> {
    await this.storage.delete(id);
  }

  async getLatest(): Promise<Screenshot | null> {
    const screenshots = await this.storage.list(1, 0);
    return screenshots.length > 0 ? screenshots[0] : null;
  }

  async getUITree(id: string): Promise<any | null> {
    const screenshot = await this.storage.get(id);
    if (!screenshot) {
      return null;
    }
    return screenshot.uiTree;
  }

  async getLatestUITree(): Promise<any | null> {
    const latest = await this.getLatest();
    if (!latest) {
      return null;
    }
    return latest.uiTree;
  }
}
