/**
 * Hybrid storage system for screenshots
 * - Memory: Last 10 screenshots for fast access
 * - Disk: Full history with automatic cleanup
 */

import fs from 'fs/promises';
import path from 'path';
import { Screenshot, StorageConfig } from './types.js';

export class Storage {
  private memoryCache: Screenshot[] = [];
  private diskIndex: Map<string, Screenshot> = new Map();
  private config: StorageConfig;

  constructor(config: Partial<StorageConfig> = {}) {
    this.config = {
      maxMemoryCache: config.maxMemoryCache || 10,
      maxDiskScreenshots: config.maxDiskScreenshots || 100,
      maxAgeDays: config.maxAgeDays || 7,
      screenshotsDir: config.screenshotsDir || path.join(process.cwd(), 'screenshots'),
    };
  }

  async init(): Promise<void> {
    // Create screenshots directory if it doesn't exist
    await fs.mkdir(this.config.screenshotsDir, { recursive: true });
    
    // Load existing screenshots index
    await this.loadIndex();
  }

  private async loadIndex(): Promise<void> {
    try {
      const files = await fs.readdir(this.config.screenshotsDir);
      const jsonFiles = files.filter(f => f.endsWith('.json'));

      for (const file of jsonFiles) {
        try {
          const filePath = path.join(this.config.screenshotsDir, file);
          const content = await fs.readFile(filePath, 'utf-8');
          const screenshot: Screenshot = JSON.parse(content);
          this.diskIndex.set(screenshot.id, screenshot);
        } catch (error) {
          console.error(`Error loading screenshot metadata ${file}:`, error);
        }
      }

      console.log(`Loaded ${this.diskIndex.size} screenshots from disk`);
    } catch (error) {
      console.error('Error loading screenshot index:', error);
    }
  }

  async store(screenshot: Screenshot): Promise<void> {
    console.error('[Storage] Storing screenshot:', screenshot.id);
    console.error('[Storage] Screenshots dir:', this.config.screenshotsDir);
    
    try {
      // Save to disk
      const imagePath = path.join(this.config.screenshotsDir, `${screenshot.id}.png`);
      const metadataPath = path.join(this.config.screenshotsDir, `${screenshot.id}.json`);

      console.error('[Storage] Image path:', imagePath);
      console.error('[Storage] Has buffer:', !!screenshot.imageBuffer, 'size:', screenshot.imageBuffer?.length);

      // Save image if buffer exists
      if (screenshot.imageBuffer) {
        await fs.writeFile(imagePath, screenshot.imageBuffer);
        console.error('[Storage] Image saved');
      } else {
        console.error('[Storage] WARNING: No image buffer to save!');
      }

      // Save metadata
      const metadata: Screenshot = {
        ...screenshot,
        imagePath,
        imageBuffer: undefined, // Don't save buffer to JSON
      };
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
      console.error('[Storage] Metadata saved');

      // Add to disk index
      this.diskIndex.set(screenshot.id, metadata);

      // Add to memory cache
      this.memoryCache.unshift(screenshot);
      if (this.memoryCache.length > this.config.maxMemoryCache) {
        const removed = this.memoryCache.pop();
        if (removed) {
          // Clear buffer from removed item
          removed.imageBuffer = undefined;
        }
      }

      // Cleanup old screenshots
      await this.cleanup();
      
      console.error('[Storage] Screenshot stored successfully');
    } catch (error) {
      console.error('[Storage] ERROR storing screenshot:', error);
      throw error;
    }
  }

  async get(id: string): Promise<Screenshot | null> {
    // Check memory cache first
    const cached = this.memoryCache.find(s => s.id === id);
    if (cached) {
      return cached;
    }

    // Load from disk
    const metadata = this.diskIndex.get(id);
    if (!metadata) {
      return null;
    }

    try {
      const imageBuffer = await fs.readFile(metadata.imagePath);
      return {
        ...metadata,
        imageBuffer,
      };
    } catch (error) {
      console.error(`Error loading screenshot ${id}:`, error);
      return null;
    }
  }

  async list(limit: number = 50, offset: number = 0): Promise<Screenshot[]> {
    const allScreenshots = Array.from(this.diskIndex.values())
      .sort((a, b) => b.timestamp - a.timestamp);
    
    return allScreenshots.slice(offset, offset + limit);
  }

  async cleanup(): Promise<void> {
    const now = Date.now();
    const maxAge = this.config.maxAgeDays * 24 * 60 * 60 * 1000;
    const allScreenshots = Array.from(this.diskIndex.values())
      .sort((a, b) => b.timestamp - a.timestamp);

    // Remove old screenshots
    for (const screenshot of allScreenshots) {
      const age = now - screenshot.timestamp;
      const shouldRemove = 
        age > maxAge || 
        allScreenshots.indexOf(screenshot) >= this.config.maxDiskScreenshots;

      if (shouldRemove) {
        await this.delete(screenshot.id);
      }
    }
  }

  async delete(id: string): Promise<void> {
    const screenshot = this.diskIndex.get(id);
    if (!screenshot) {
      return;
    }

    try {
      // Delete files
      await fs.unlink(screenshot.imagePath).catch(() => {});
      await fs.unlink(screenshot.imagePath.replace('.png', '.json')).catch(() => {});

      // Remove from indexes
      this.diskIndex.delete(id);
      this.memoryCache = this.memoryCache.filter(s => s.id !== id);
    } catch (error) {
      console.error(`Error deleting screenshot ${id}:`, error);
    }
  }

  async annotate(id: string, annotation: string, tags?: string[]): Promise<boolean> {
    const screenshot = this.diskIndex.get(id);
    if (!screenshot) {
      return false;
    }

    screenshot.annotation = annotation;
    if (tags) {
      screenshot.tags = tags;
    }

    // Update metadata file
    const metadataPath = path.join(this.config.screenshotsDir, `${id}.json`);
    await fs.writeFile(metadataPath, JSON.stringify(screenshot, null, 2));

    // Update memory cache if present
    const cached = this.memoryCache.find(s => s.id === id);
    if (cached) {
      cached.annotation = annotation;
      if (tags) {
        cached.tags = tags;
      }
    }

    return true;
  }
}
