/**
 * Diff engine for visual and structural comparison
 */

import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';
import sharp from 'sharp';
import { VisualDiff, StructuralDiff, UIWidget, ModifiedWidget, PropertyChange, ChangedRegion, SmartDiffResult, LayoutIssue, IssueSeverity } from './types.js';
import { UIAnalyzer } from './ui-analyzer.js';

export class DiffEngine {
  private analyzer: UIAnalyzer;

  constructor() {
    this.analyzer = new UIAnalyzer();
  }

  /**
   * Smart diff: combines visual + structural + issue detection
   */
  async smartDiff(
    img1: Buffer,
    img2: Buffer,
    tree1: UIWidget,
    tree2: UIWidget,
    options: {
      threshold?: number;
      focus?: string[];
      detectIssues?: boolean;
    } = {}
  ): Promise<SmartDiffResult> {
    const { threshold = 0.05, focus, detectIssues = true } = options;

    // Run visual and structural diffs in parallel
    const [visualResult, structuralResult] = await Promise.all([
      this.visualDiff(img1, img2, threshold),
      this.structuralDiff(tree1, tree2),
    ]);

    // Filter structural changes if focus is specified
    let filteredStructural = structuralResult;
    if (focus && focus.length > 0) {
      filteredStructural = this.filterStructuralDiff(structuralResult, focus);
    }

    // Detect layout issues in the new state
    let issues: LayoutIssue[] = [];
    if (detectIssues) {
      const allChecks = ['overlaps', 'coverage', 'zero_size'];
      issues = this.analyzer.analyzeLayout(tree2, allChecks, focus);
    }

    // Generate smart summary
    const summary = this.generateSmartSummary(visualResult, filteredStructural, issues);

    return {
      visual: {
        diffPercentage: visualResult.diffPercentage,
        diffImageBase64: visualResult.diffImageBase64,
        changedRegions: visualResult.changedRegions,
      },
      structural: {
        addedWidgets: filteredStructural.addedWidgets,
        removedWidgets: filteredStructural.removedWidgets,
        modifiedWidgets: filteredStructural.modifiedWidgets,
      },
      issues,
      summary,
    };
  }

  /**
   * Compare two images visually using pixelmatch
   */
  async visualDiff(img1: Buffer, img2: Buffer, threshold: number = 0.05): Promise<VisualDiff> {
    // Load images as PNG
    const png1 = await this.loadPNG(img1);
    const png2 = await this.loadPNG(img2);

    // Ensure same dimensions
    if (png1.width !== png2.width || png1.height !== png2.height) {
      // Resize to smaller dimensions
      const width = Math.min(png1.width, png2.width);
      const height = Math.min(png1.height, png2.height);
      
      const resized1 = await this.resizePNG(img1, width, height);
      const resized2 = await this.resizePNG(img2, width, height);
      
      return this.visualDiff(resized1, resized2, threshold);
    }

    // Create diff image
    const diff = new PNG({ width: png1.width, height: png1.height });

    // Compare pixels
    const numDiffPixels = pixelmatch(
      png1.data,
      png2.data,
      diff.data,
      png1.width,
      png1.height,
      { threshold }
    );

    // Calculate percentage
    const totalPixels = png1.width * png1.height;
    const diffPercentage = (numDiffPixels / totalPixels) * 100;

    // Convert diff image to base64
    const diffBuffer = PNG.sync.write(diff);
    const diffImageBase64 = diffBuffer.toString('base64');

    // Detect changed regions with improved grouping
    const changedRegions = this.detectChangedRegions(diff.data, png1.width, png1.height);
    
    // Merge nearby regions (within 50px)
    const mergedRegions = this.mergeNearbyRegions(changedRegions, 50);

    return {
      diffPercentage: Number(diffPercentage.toFixed(2)),
      diffImageBase64,
      changedRegions: mergedRegions,
    };
  }

  /**
   * Compare two UI trees structurally
   */
  async structuralDiff(tree1: UIWidget, tree2: UIWidget): Promise<StructuralDiff> {
    // Create maps of widgets by ID
    const map1 = new Map<string, UIWidget>();
    const map2 = new Map<string, UIWidget>();

    this.flattenTree(tree1, map1);
    this.flattenTree(tree2, map2);

    // Find added widgets (in tree2 but not in tree1)
    const addedWidgets: UIWidget[] = [];
    for (const [id, widget] of map2) {
      if (!map1.has(id)) {
        addedWidgets.push(widget);
      }
    }

    // Find removed widgets (in tree1 but not in tree2)
    const removedWidgets: UIWidget[] = [];
    for (const [id, widget] of map1) {
      if (!map2.has(id)) {
        removedWidgets.push(widget);
      }
    }

    // Find modified widgets (in both but with different properties)
    const modifiedWidgets: ModifiedWidget[] = [];
    for (const [id, widget1] of map1) {
      const widget2 = map2.get(id);
      if (widget2) {
        const changes = this.compareWidgets(widget1, widget2);
        if (changes.length > 0) {
          modifiedWidgets.push({ id, changes });
        }
      }
    }

    // Generate summary
    const summary = `${addedWidgets.length + removedWidgets.length + modifiedWidgets.length} widgets changed: ${addedWidgets.length} added, ${removedWidgets.length} removed, ${modifiedWidgets.length} modified`;

    return {
      addedWidgets,
      removedWidgets,
      modifiedWidgets,
      summary,
    };
  }

  private async loadPNG(buffer: Buffer): Promise<PNG> {
    // First, ensure it's a valid PNG by re-encoding with sharp
    try {
      const pngBuffer = await sharp(buffer)
        .png()
        .toBuffer();
      
      return new Promise((resolve, reject) => {
        const png = new PNG();
        png.parse(pngBuffer, (error, data) => {
          if (error) reject(error);
          else resolve(data);
        });
      });
    } catch (error) {
      throw error;
    }
  }

  private async resizePNG(buffer: Buffer, width: number, height: number): Promise<Buffer> {
    return await sharp(buffer)
      .resize(width, height, { fit: 'fill' })
      .png()
      .toBuffer();
  }

  private detectChangedRegions(diffData: Uint8Array, width: number, height: number): ChangedRegion[] {
    const regions: ChangedRegion[] = [];
    const visited = new Set<string>();
    const threshold = 5; // Minimum region size (reduced for better detection)

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const key = `${x},${y}`;
        if (visited.has(key)) continue;

        const idx = (y * width + x) * 4;
        const isDiff = diffData[idx] > 0 || diffData[idx + 1] > 0 || diffData[idx + 2] > 0;

        if (isDiff) {
          // Find bounding box of this changed region
          const region = this.findRegion(diffData, width, height, x, y, visited);
          if (region.width >= threshold && region.height >= threshold) {
            regions.push(region);
          }
        }
      }
    }

    return regions;
  }

  private mergeNearbyRegions(regions: ChangedRegion[], distance: number): ChangedRegion[] {
    if (regions.length === 0) return regions;

    const merged: ChangedRegion[] = [];
    const used = new Set<number>();

    for (let i = 0; i < regions.length; i++) {
      if (used.has(i)) continue;

      let current = regions[i];
      used.add(i);

      // Try to merge with nearby regions
      let changed = true;
      while (changed) {
        changed = false;
        for (let j = 0; j < regions.length; j++) {
          if (used.has(j)) continue;

          const other = regions[j];
          // Check if regions are close enough
          const dx = Math.max(0, Math.max(current.x, other.x) - Math.min(current.x + current.width, other.x + other.width));
          const dy = Math.max(0, Math.max(current.y, other.y) - Math.min(current.y + current.height, other.y + other.height));

          if (dx <= distance && dy <= distance) {
            // Merge regions
            const minX = Math.min(current.x, other.x);
            const minY = Math.min(current.y, other.y);
            const maxX = Math.max(current.x + current.width, other.x + other.width);
            const maxY = Math.max(current.y + current.height, other.y + other.height);

            current = {
              x: minX,
              y: minY,
              width: maxX - minX,
              height: maxY - minY,
            };

            used.add(j);
            changed = true;
          }
        }
      }

      merged.push(current);
    }

    return merged.sort((a, b) => (b.width * b.height) - (a.width * a.height)); // Sort by area (largest first)
  }

  private findRegion(
    diffData: Uint8Array,
    width: number,
    height: number,
    startX: number,
    startY: number,
    visited: Set<string>
  ): ChangedRegion {
    let minX = startX, maxX = startX;
    let minY = startY, maxY = startY;

    const queue: [number, number][] = [[startX, startY]];
    visited.add(`${startX},${startY}`);

    while (queue.length > 0) {
      const [x, y] = queue.shift()!;

      // Check neighbors
      for (const [dx, dy] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        const nx = x + dx;
        const ny = y + dy;
        const key = `${nx},${ny}`;

        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if (visited.has(key)) continue;

        const idx = (ny * width + nx) * 4;
        const isDiff = diffData[idx] > 0 || diffData[idx + 1] > 0 || diffData[idx + 2] > 0;

        if (isDiff) {
          visited.add(key);
          queue.push([nx, ny]);
          minX = Math.min(minX, nx);
          maxX = Math.max(maxX, nx);
          minY = Math.min(minY, ny);
          maxY = Math.max(maxY, ny);
        }
      }
    }

    return {
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    };
  }

  private flattenTree(widget: UIWidget, map: Map<string, UIWidget>): void {
    map.set(widget.id, widget);
    for (const child of widget.children) {
      this.flattenTree(child, map);
    }
  }

  private compareWidgets(widget1: UIWidget, widget2: UIWidget): PropertyChange[] {
    const changes: PropertyChange[] = [];

    // Compare position
    if (widget1.rect.x !== widget2.rect.x) {
      changes.push({ property: 'x', oldValue: widget1.rect.x, newValue: widget2.rect.x });
    }
    if (widget1.rect.y !== widget2.rect.y) {
      changes.push({ property: 'y', oldValue: widget1.rect.y, newValue: widget2.rect.y });
    }

    // Compare size
    if (widget1.rect.width !== widget2.rect.width) {
      changes.push({ property: 'width', oldValue: widget1.rect.width, newValue: widget2.rect.width });
    }
    if (widget1.rect.height !== widget2.rect.height) {
      changes.push({ property: 'height', oldValue: widget1.rect.height, newValue: widget2.rect.height });
    }

    // Compare visibility
    if (widget1.visible !== widget2.visible) {
      changes.push({ property: 'visible', oldValue: widget1.visible, newValue: widget2.visible });
    }

    // Compare enabled state
    if (widget1.enabled !== widget2.enabled) {
      changes.push({ property: 'enabled', oldValue: widget1.enabled, newValue: widget2.enabled });
    }

    // Compare text
    if (widget1.text !== widget2.text) {
      changes.push({ property: 'text', oldValue: widget1.text, newValue: widget2.text });
    }

    // Compare new properties
    if (widget1.opacity !== widget2.opacity) {
      changes.push({ property: 'opacity', oldValue: widget1.opacity, newValue: widget2.opacity });
    }
    if (widget1.phantom !== widget2.phantom) {
      changes.push({ property: 'phantom', oldValue: widget1.phantom, newValue: widget2.phantom });
    }

    return changes;
  }

  /**
   * Filter structural diff by focus patterns
   */
  private filterStructuralDiff(diff: StructuralDiff, focus: string[]): StructuralDiff {
    const matches = (id: string) => focus.some(pattern => this.analyzer['matchesPattern'](id, pattern));

    return {
      addedWidgets: diff.addedWidgets.filter(w => matches(w.id)),
      removedWidgets: diff.removedWidgets.filter(w => matches(w.id)),
      modifiedWidgets: diff.modifiedWidgets.filter(w => matches(w.id)),
      summary: `Filtered: ${diff.addedWidgets.filter(w => matches(w.id)).length} added, ${diff.removedWidgets.filter(w => matches(w.id)).length} removed, ${diff.modifiedWidgets.filter(w => matches(w.id)).length} modified`,
    };
  }

  /**
   * Generate intelligent summary from diff results
   */
  private generateSmartSummary(visual: VisualDiff, structural: StructuralDiff, issues: LayoutIssue[]): string {
    const parts: string[] = [];

    // Visual changes
    if (visual.diffPercentage > 10) {
      parts.push(`Large visual change (${visual.diffPercentage.toFixed(1)}% pixels changed)`);
    } else if (visual.diffPercentage > 1) {
      parts.push(`Moderate visual change (${visual.diffPercentage.toFixed(1)}% pixels changed)`);
    } else if (visual.diffPercentage > 0) {
      parts.push(`Minor visual change (${visual.diffPercentage.toFixed(2)}% pixels changed)`);
    } else {
      parts.push('No visual changes detected');
    }

    // Structural changes
    const totalChanges = structural.addedWidgets.length + structural.removedWidgets.length + structural.modifiedWidgets.length;
    if (totalChanges > 0) {
      const details: string[] = [];
      if (structural.addedWidgets.length > 0) details.push(`${structural.addedWidgets.length} added`);
      if (structural.removedWidgets.length > 0) details.push(`${structural.removedWidgets.length} removed`);
      if (structural.modifiedWidgets.length > 0) details.push(`${structural.modifiedWidgets.length} modified`);
      parts.push(`${totalChanges} widget(s) changed: ${details.join(', ')}`);
    }

    // Layout issues
    if (issues.length > 0) {
      const errors = issues.filter(i => i.severity === IssueSeverity.ERROR).length;
      const warnings = issues.filter(i => i.severity === IssueSeverity.WARNING).length;
      const issueDetails: string[] = [];
      if (errors > 0) issueDetails.push(`${errors} error(s)`);
      if (warnings > 0) issueDetails.push(`${warnings} warning(s)`);
      parts.push(`${issues.length} layout issue(s) detected: ${issueDetails.join(', ')}`);
    }

    return parts.join('. ');
  }
}
