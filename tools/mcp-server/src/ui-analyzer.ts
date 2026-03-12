/**
 * UI Analyzer - Layout analysis and widget querying
 */

import { UIWidget, LayoutIssue, IssueType, IssueSeverity } from './types.js';

export class UIAnalyzer {
  /**
   * Find widgets by ID patterns (supports glob-like matching)
   */
  queryByPattern(tree: UIWidget, patterns: string[]): UIWidget[] {
    const results: UIWidget[] = [];
    const visited = new Set<string>();

    const search = (widget: UIWidget) => {
      if (visited.has(widget.id)) return;
      visited.add(widget.id);

      for (const pattern of patterns) {
        if (this.matchesPattern(widget.id, pattern)) {
          results.push(widget);
          break;
        }
      }

      for (const child of widget.children) {
        search(child);
      }
    };

    search(tree);
    return results;
  }

  /**
   * Find widgets by class names
   */
  queryByClass(tree: UIWidget, classes: string[]): UIWidget[] {
    const results: UIWidget[] = [];
    const classSet = new Set(classes);

    const search = (widget: UIWidget) => {
      if (classSet.has(widget.class)) {
        results.push(widget);
      }

      for (const child of widget.children) {
        search(child);
      }
    };

    search(tree);
    return results;
  }

  /**
   * Find widgets within a specific region
   */
  queryByRegion(tree: UIWidget, region: { x: number; y: number; width: number; height: number }): UIWidget[] {
    const results: UIWidget[] = [];

    const search = (widget: UIWidget) => {
      if (this.rectsIntersect(widget.rect, region)) {
        results.push(widget);
      }

      for (const child of widget.children) {
        search(child);
      }
    };

    search(tree);
    return results;
  }

  /**
   * Get ancestor chain from root to a specific widget
   */
  getAncestorChain(tree: UIWidget, widgetId: string): UIWidget[] {
    const chain: UIWidget[] = [];

    const search = (widget: UIWidget, path: UIWidget[]): boolean => {
      const currentPath = [...path, widget];

      if (widget.id === widgetId) {
        chain.push(...currentPath);
        return true;
      }

      for (const child of widget.children) {
        if (search(child, currentPath)) {
          return true;
        }
      }

      return false;
    };

    search(tree, []);
    return chain;
  }

  /**
   * Find overlapping widgets (siblings with intersecting rects)
   */
  findOverlaps(tree: UIWidget): LayoutIssue[] {
    const issues: LayoutIssue[] = [];

    const checkSiblings = (parent: UIWidget) => {
      const visibleChildren = parent.children.filter(c => c.visible);

      for (let i = 0; i < visibleChildren.length; i++) {
        for (let j = i + 1; j < visibleChildren.length; j++) {
          const widget1 = visibleChildren[i];
          const widget2 = visibleChildren[j];

          const rect1 = this.getVisualRect(widget1);
          const rect2 = this.getVisualRect(widget2);

          if (this.rectsIntersect(rect1, rect2)) {
            const area = this.getIntersectionArea(rect1, rect2);
            const severity = area > 100 ? IssueSeverity.ERROR : IssueSeverity.WARNING;

            issues.push({
              type: IssueType.OVERLAP,
              severity,
              description: `Widget "${widget1.id}" overlaps with "${widget2.id}" (${area}px² intersection)`,
              widgets: [
                { id: widget1.id, rect: widget1.rect },
                { id: widget2.id, rect: widget2.rect },
              ],
              details: { intersectionArea: area },
            });
          }
        }
      }

      for (const child of parent.children) {
        checkSiblings(child);
      }
    };

    checkSiblings(tree);
    return issues;
  }

  /**
   * Find widgets completely covered by other widgets
   */
  findCoverage(tree: UIWidget): LayoutIssue[] {
    const issues: LayoutIssue[] = [];

    const checkSiblings = (parent: UIWidget) => {
      const visibleChildren = parent.children.filter(c => c.visible);

      for (let i = 0; i < visibleChildren.length; i++) {
        for (let j = 0; j < visibleChildren.length; j++) {
          if (i === j) continue;

          const covered = visibleChildren[i];
          const covering = visibleChildren[j];

          const coveredRect = this.getVisualRect(covered);
          const coveringRect = this.getVisualRect(covering);

          if (this.rectContains(coveringRect, coveredRect)) {
            issues.push({
              type: IssueType.COVERAGE,
              severity: IssueSeverity.WARNING,
              description: `Widget "${covered.id}" is completely covered by "${covering.id}"`,
              widgets: [
                { id: covered.id, rect: covered.rect },
                { id: covering.id, rect: covering.rect },
              ],
            });
          }
        }
      }

      for (const child of parent.children) {
        checkSiblings(child);
      }
    };

    checkSiblings(tree);
    return issues;
  }

  /**
   * Find widgets outside their parent bounds
   */
  findOutOfBounds(tree: UIWidget): LayoutIssue[] {
    const issues: LayoutIssue[] = [];

    const check = (parent: UIWidget) => {
      for (const child of parent.children) {
        if (!child.visible) continue;

        if (!this.rectContains(parent.rect, child.rect)) {
          issues.push({
            type: IssueType.OUT_OF_BOUNDS,
            severity: IssueSeverity.INFO,
            description: `Widget "${child.id}" extends outside parent "${parent.id}"`,
            widgets: [
              { id: child.id, rect: child.rect },
              { id: parent.id, rect: parent.rect },
            ],
          });
        }

        check(child);
      }
    };

    check(tree);
    return issues;
  }

  /**
   * Find visible widgets with zero size
   */
  findZeroSize(tree: UIWidget): LayoutIssue[] {
    const issues: LayoutIssue[] = [];

    const search = (widget: UIWidget) => {
      if (widget.visible && (widget.rect.width === 0 || widget.rect.height === 0)) {
        issues.push({
          type: IssueType.ZERO_SIZE,
          severity: IssueSeverity.WARNING,
          description: `Widget "${widget.id}" is visible but has ${widget.rect.width === 0 ? 'zero width' : 'zero height'}`,
          widgets: [{ id: widget.id, rect: widget.rect }],
        });
      }

      for (const child of widget.children) {
        search(child);
      }
    };

    search(tree);
    return issues;
  }

  /**
   * Run all layout checks
   */
  analyzeLayout(tree: UIWidget, checks: string[], scope?: string[]): LayoutIssue[] {
    let allIssues: LayoutIssue[] = [];

    if (checks.includes('overlaps')) {
      allIssues.push(...this.findOverlaps(tree));
    }

    if (checks.includes('coverage')) {
      allIssues.push(...this.findCoverage(tree));
    }

    if (checks.includes('out_of_bounds')) {
      allIssues.push(...this.findOutOfBounds(tree));
    }

    if (checks.includes('zero_size')) {
      allIssues.push(...this.findZeroSize(tree));
    }

    // Filter by scope if provided
    if (scope && scope.length > 0) {
      const scopeSet = new Set(scope);
      allIssues = allIssues.filter(issue =>
        issue.widgets.some(w => scopeSet.has(w.id) || scope.some(pattern => this.matchesPattern(w.id, pattern)))
      );
    }

    return allIssues;
  }

  /**
   * Get the visual rect of a widget (uses visualRect if available for rotated widgets, otherwise uses rect)
   */
  private getVisualRect(widget: UIWidget): { x: number; y: number; width: number; height: number } {
    return widget.visualRect || widget.rect;
  }

  /**
   * Match widget ID against pattern (supports * wildcard)
   */
  private matchesPattern(id: string, pattern: string): boolean {
    if (pattern === '*') return true;
    if (!pattern.includes('*')) return id === pattern;

    const regex = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
    return regex.test(id);
  }

  /**
   * Check if two rectangles intersect
   */
  private rectsIntersect(
    r1: { x: number; y: number; width: number; height: number },
    r2: { x: number; y: number; width: number; height: number }
  ): boolean {
    return !(
      r1.x + r1.width <= r2.x ||
      r2.x + r2.width <= r1.x ||
      r1.y + r1.height <= r2.y ||
      r2.y + r2.height <= r1.y
    );
  }

  /**
   * Check if rect1 completely contains rect2
   */
  private rectContains(
    r1: { x: number; y: number; width: number; height: number },
    r2: { x: number; y: number; width: number; height: number }
  ): boolean {
    return (
      r2.x >= r1.x &&
      r2.y >= r1.y &&
      r2.x + r2.width <= r1.x + r1.width &&
      r2.y + r2.height <= r1.y + r1.height
    );
  }

  /**
   * Calculate intersection area between two rectangles
   */
  private getIntersectionArea(
    r1: { x: number; y: number; width: number; height: number },
    r2: { x: number; y: number; width: number; height: number }
  ): number {
    const x1 = Math.max(r1.x, r2.x);
    const y1 = Math.max(r1.y, r2.y);
    const x2 = Math.min(r1.x + r1.width, r2.x + r2.width);
    const y2 = Math.min(r1.y + r1.height, r2.y + r2.height);

    if (x2 <= x1 || y2 <= y1) return 0;

    return (x2 - x1) * (y2 - y1);
  }

  /**
   * Clone widget without children (for compact results)
   */
  cloneWidgetWithoutChildren(widget: UIWidget): UIWidget {
    return {
      ...widget,
      children: [],
    };
  }

  /**
   * Clone widget with children up to specified depth
   */
  cloneWidgetWithDepth(widget: UIWidget, maxDepth: number, currentDepth: number = 0): UIWidget {
    if (currentDepth >= maxDepth) {
      return this.cloneWidgetWithoutChildren(widget);
    }

    return {
      ...widget,
      children: widget.children.map(child => this.cloneWidgetWithDepth(child, maxDepth, currentDepth + 1)),
    };
  }
}
