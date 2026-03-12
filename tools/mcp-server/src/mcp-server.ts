/**
 * MCP Server implementation with 4 smart tools for screenshot and UI analysis
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

import { ScreenshotManager } from './screenshot-manager.js';
import { DiffEngine } from './diff-engine.js';
import { UIAnalyzer } from './ui-analyzer.js';
import { InspectMode } from './types.js';

export class MCPServer {
  private server: Server;
  private screenshotManager: ScreenshotManager;
  private diffEngine: DiffEngine;
  private uiAnalyzer: UIAnalyzer;

  constructor(screenshotManager: ScreenshotManager, diffEngine: DiffEngine) {
    this.screenshotManager = screenshotManager;
    this.diffEngine = diffEngine;
    this.uiAnalyzer = new UIAnalyzer();

    this.server = new Server(
      {
        name: 'otclient-mcp-server',
        version: '0.2.0',
      },
      {
        capabilities: {
          tools: {},
          resources: {},
        },
      }
    );

    this.setupHandlers();
  }

  private setupHandlers(): void {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'capture_screenshot',
          description: 'Capture new screenshot OR view existing one. Returns renderable image + compact metadata.',
          inputSchema: {
            type: 'object',
            properties: {
              type: {
                type: 'string',
                enum: ['full', 'map'],
                description: 'Type of screenshot to capture (required if capturing new)',
              },
              id: {
                type: 'string',
                description: 'Screenshot ID to view (optional - if provided, views existing instead of capturing)',
              },
              annotation: {
                type: 'string',
                description: 'Optional annotation for new screenshot',
              },
            },
          },
        },
        {
          name: 'inspect_ui',
          description: 'Query and analyze UI tree intelligently. Supports 3 modes: query (find widgets), analyze (detect issues), ancestors (widget hierarchy).',
          inputSchema: {
            type: 'object',
            properties: {
              mode: {
                type: 'string',
                enum: ['query', 'analyze', 'ancestors'],
                description: 'Inspection mode',
              },
              source: {
                type: 'string',
                description: 'Data source: "latest", screenshot-id, or "live"',
              },
              ids: {
                type: 'array',
                items: { type: 'string' },
                description: 'Widget ID patterns (supports glob: "conditionHUD*") - for query mode',
              },
              classes: {
                type: 'array',
                items: { type: 'string' },
                description: 'Widget class names - for query mode',
              },
              region: {
                type: 'object',
                properties: {
                  x: { type: 'number' },
                  y: { type: 'number' },
                  width: { type: 'number' },
                  height: { type: 'number' },
                },
                description: 'Screen region to search - for query mode',
              },
              include_children: {
                type: 'boolean',
                description: 'Include child widgets in results - for query mode',
              },
              checks: {
                type: 'array',
                items: { type: 'string', enum: ['overlaps', 'coverage', 'out_of_bounds', 'zero_size'] },
                description: 'Layout checks to run - for analyze mode',
              },
              scope: {
                type: 'array',
                items: { type: 'string' },
                description: 'Limit analysis to these widget IDs - for analyze mode',
              },
              widget_id: {
                type: 'string',
                description: 'Widget ID to trace - for ancestors mode',
              },
            },
            required: ['mode', 'source'],
          },
        },
        {
          name: 'diff_screenshots',
          description: 'Smart diff: visual + structural + layout issue detection in one call.',
          inputSchema: {
            type: 'object',
            properties: {
              id1: {
                type: 'string',
                description: 'First screenshot ID',
              },
              id2: {
                type: 'string',
                description: 'Second screenshot ID',
              },
              focus: {
                type: 'array',
                items: { type: 'string' },
                description: 'Optional: analyze only these widget ID patterns (glob supported)',
              },
              detect_issues: {
                type: 'boolean',
                description: 'Detect layout issues in new state (default: true)',
              },
              threshold: {
                type: 'number',
                description: 'Pixel difference threshold (0-1, default: 0.05)',
              },
            },
            required: ['id1', 'id2'],
          },
        },
        {
          name: 'list_screenshots',
          description: 'List all screenshots with metadata',
          inputSchema: {
            type: 'object',
            properties: {
              limit: {
                type: 'number',
                description: 'Maximum number of screenshots to return (default: 50)',
              },
              offset: {
                type: 'number',
                description: 'Offset for pagination (default: 0)',
              },
            },
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'capture_screenshot':
            return await this.handleCaptureScreenshot(args);

          case 'inspect_ui':
            return await this.handleInspectUI(args);

          case 'diff_screenshots':
            return await this.handleDiffScreenshots(args);

          case 'list_screenshots':
            return await this.handleListScreenshots(args);

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${errorMessage}`,
            },
          ],
        };
      }
    });

    // List available resources
    this.server.setRequestHandler(ListResourcesRequestSchema, async () => ({
      resources: [
        {
          uri: 'screenshot://latest',
          name: 'Latest Screenshot',
          description: 'The most recently captured screenshot',
          mimeType: 'image/png',
        },
        {
          uri: 'screenshot://list',
          name: 'Screenshot List',
          description: 'List of all screenshots',
          mimeType: 'application/json',
        },
      ],
    }));

    // Handle resource reads
    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const { uri } = request.params;

      if (uri === 'screenshot://latest') {
        const latest = await this.screenshotManager.getLatest();
        if (!latest) {
          throw new Error('No screenshots available');
        }
        const base64 = await this.screenshotManager.getImageBase64(latest.id);
        return {
          contents: [
            {
              uri,
              mimeType: 'image/png',
              text: base64 || '',
            },
          ],
        };
      }

      if (uri === 'screenshot://list') {
        const screenshots = await this.screenshotManager.list(100, 0);
        return {
          contents: [
            {
              uri,
              mimeType: 'application/json',
              text: JSON.stringify(screenshots, null, 2),
            },
          ],
        };
      }

      throw new Error(`Unknown resource: ${uri}`);
    });
  }

  private async handleCaptureScreenshot(args: any) {
    const { type, id, annotation } = args;

    let screenshot;
    
    // If ID provided, view existing screenshot
    if (id) {
      screenshot = await this.screenshotManager.get(id);
      if (!screenshot) {
        throw new Error(`Screenshot not found: ${id}`);
      }
    } else {
      // Capture new screenshot
      if (!type) {
        throw new Error('type is required when capturing new screenshot');
      }
      screenshot = await this.screenshotManager.capture(type, annotation);
    }

    const base64 = await this.screenshotManager.getImageBase64(screenshot.id);

    if (!base64) {
      throw new Error('Failed to get image data');
    }

    return {
      content: [
        {
          type: 'image',
          data: base64,
          mimeType: 'image/png',
        },
        {
          type: 'text',
          text: JSON.stringify({
            id: screenshot.id,
            timestamp: screenshot.timestamp,
            width: screenshot.width,
            height: screenshot.height,
            type: screenshot.type,
            annotation: screenshot.annotation,
            tags: screenshot.tags,
          }, null, 2),
        },
      ],
    };
  }

  private async handleInspectUI(args: any) {
    const { mode, source } = args;

    // Get UI tree from source
    let uiTree;
    if (source === 'latest') {
      uiTree = await this.screenshotManager.getLatestUITree();
      if (!uiTree) {
        throw new Error('No screenshots available');
      }
    } else if (source === 'live') {
      throw new Error('Live UI inspection not yet implemented');
    } else {
      uiTree = await this.screenshotManager.getUITree(source);
      if (!uiTree) {
        throw new Error(`Screenshot not found: ${source}`);
      }
    }

    // Handle different modes
    if (mode === InspectMode.QUERY) {
      return await this.handleInspectQuery(uiTree, args);
    } else if (mode === InspectMode.ANALYZE) {
      return await this.handleInspectAnalyze(uiTree, args);
    } else if (mode === InspectMode.ANCESTORS) {
      return await this.handleInspectAncestors(uiTree, args);
    } else {
      throw new Error(`Unknown inspect mode: ${mode}`);
    }
  }

  private async handleInspectQuery(uiTree: any, args: any) {
    const { ids, classes, region, include_children = false } = args;
    let results: any[] = [];

    // Query by IDs
    if (ids && ids.length > 0) {
      results.push(...this.uiAnalyzer.queryByPattern(uiTree, ids));
    }

    // Query by classes
    if (classes && classes.length > 0) {
      results.push(...this.uiAnalyzer.queryByClass(uiTree, classes));
    }

    // Query by region
    if (region) {
      results.push(...this.uiAnalyzer.queryByRegion(uiTree, region));
    }

    // Remove duplicates
    const uniqueResults = Array.from(new Map(results.map(w => [w.id, w])).values());

    // Strip children if not requested
    const finalResults = include_children
      ? uniqueResults
      : uniqueResults.map(w => this.uiAnalyzer.cloneWidgetWithoutChildren(w));

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            mode: 'query',
            count: finalResults.length,
            widgets: finalResults,
          }, null, 2),
        },
      ],
    };
  }

  private async handleInspectAnalyze(uiTree: any, args: any) {
    const { checks = ['overlaps', 'coverage', 'out_of_bounds', 'zero_size'], scope } = args;

    const issues = this.uiAnalyzer.analyzeLayout(uiTree, checks, scope);

    const summary = issues.length === 0
      ? 'No layout issues detected'
      : `Found ${issues.length} issue(s): ${issues.filter(i => i.severity === 'error').length} error(s), ${issues.filter(i => i.severity === 'warning').length} warning(s)`;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            mode: 'analyze',
            summary,
            issues,
          }, null, 2),
        },
      ],
    };
  }

  private async handleInspectAncestors(uiTree: any, args: any) {
    const { widget_id } = args;

    if (!widget_id) {
      throw new Error('widget_id is required for ancestors mode');
    }

    const chain = this.uiAnalyzer.getAncestorChain(uiTree, widget_id);

    if (chain.length === 0) {
      throw new Error(`Widget not found: ${widget_id}`);
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            mode: 'ancestors',
            depth: chain.length,
            chain: chain.map(w => this.uiAnalyzer.cloneWidgetWithoutChildren(w)),
          }, null, 2),
        },
      ],
    };
  }

  private async handleDiffScreenshots(args: any) {
    const { id1, id2, focus, detect_issues = true, threshold = 0.05 } = args;

    const screenshot1 = await this.screenshotManager.get(id1);
    const screenshot2 = await this.screenshotManager.get(id2);

    if (!screenshot1) throw new Error(`Screenshot not found: ${id1}`);
    if (!screenshot2) throw new Error(`Screenshot not found: ${id2}`);
    if (!screenshot1.imageBuffer) throw new Error(`Image buffer not available: ${id1}`);
    if (!screenshot2.imageBuffer) throw new Error(`Image buffer not available: ${id2}`);

    const result = await this.diffEngine.smartDiff(
      screenshot1.imageBuffer,
      screenshot2.imageBuffer,
      screenshot1.uiTree,
      screenshot2.uiTree,
      { threshold, focus, detectIssues: detect_issues }
    );

    return {
      content: [
        {
          type: 'image',
          data: result.visual.diffImageBase64,
          mimeType: 'image/png',
        },
        {
          type: 'text',
          text: JSON.stringify({
            summary: result.summary,
            visual: {
              diffPercentage: result.visual.diffPercentage,
              changedRegions: result.visual.changedRegions,
            },
            structural: result.structural,
            issues: result.issues,
          }, null, 2),
        },
      ],
    };
  }

  private async handleListScreenshots(args: any) {
    const { limit = 50, offset = 0 } = args;
    const screenshots = await this.screenshotManager.list(limit, offset);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            screenshots: screenshots.map(s => ({
              id: s.id,
              timestamp: s.timestamp,
              type: s.type,
              width: s.width,
              height: s.height,
              annotation: s.annotation,
              tags: s.tags,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async start(): Promise<void> {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[MCP Server] Started successfully');
  }
}
