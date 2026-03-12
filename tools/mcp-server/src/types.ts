/**
 * Type definitions for OTClient MCP Server v0.2
 */

// UI Widget structure from OTClient
export interface UIWidget {
  id: string;
  class: string;
  rect: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  visible: boolean;
  enabled: boolean;
  text?: string;
  opacity?: number;
  phantom?: boolean;
  clipping?: boolean;
  focusable?: boolean;
  draggable?: boolean;
  rotation?: number;
  margins?: {
    top?: number;
    right?: number;
    bottom?: number;
    left?: number;
  };
  font?: string;
  parentId?: string;
  visualRect?: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  children: UIWidget[];
}

// Screenshot metadata
export interface Screenshot {
  id: string;
  timestamp: number;
  type: 'full' | 'map';
  width: number;
  height: number;
  imagePath: string;
  imageBuffer?: Buffer;
  uiTree: UIWidget;
  annotation?: string;
  tags?: string[];
}

// Visual diff result
export interface VisualDiff {
  diffPercentage: number;
  diffImageBase64: string;
  changedRegions: ChangedRegion[];
}

export interface ChangedRegion {
  x: number;
  y: number;
  width: number;
  height: number;
}

// Structural diff result
export interface StructuralDiff {
  addedWidgets: UIWidget[];
  removedWidgets: UIWidget[];
  modifiedWidgets: ModifiedWidget[];
  summary: string;
}

export interface ModifiedWidget {
  id: string;
  changes: PropertyChange[];
}

export interface PropertyChange {
  property: string;
  oldValue: any;
  newValue: any;
}

// Layout issue types
export enum IssueType {
  OVERLAP = 'overlap',
  COVERAGE = 'coverage',
  OUT_OF_BOUNDS = 'out_of_bounds',
  ZERO_SIZE = 'zero_size',
}

export enum IssueSeverity {
  ERROR = 'error',
  WARNING = 'warning',
  INFO = 'info',
}

export interface LayoutIssue {
  type: IssueType;
  severity: IssueSeverity;
  description: string;
  widgets: {
    id: string;
    rect: { x: number; y: number; width: number; height: number };
  }[];
  details?: any;
}

// Inspect UI modes
export enum InspectMode {
  QUERY = 'query',
  ANALYZE = 'analyze',
  ANCESTORS = 'ancestors',
}

export interface InspectQueryParams {
  mode: InspectMode.QUERY;
  source: string; // 'latest' | screenshot-id | 'live'
  ids?: string[]; // Glob patterns supported
  classes?: string[];
  region?: { x: number; y: number; width: number; height: number };
  include_children?: boolean;
}

export interface InspectAnalyzeParams {
  mode: InspectMode.ANALYZE;
  source: string;
  checks: string[]; // 'overlaps', 'coverage', 'out_of_bounds', 'zero_size'
  scope?: string[]; // Widget IDs to limit analysis
}

export interface InspectAncestorsParams {
  mode: InspectMode.ANCESTORS;
  source: string;
  widget_id: string;
}

export type InspectParams = InspectQueryParams | InspectAnalyzeParams | InspectAncestorsParams;

export interface InspectQueryResult {
  mode: 'query';
  widgets: UIWidget[];
  count: number;
}

export interface InspectAnalyzeResult {
  mode: 'analyze';
  issues: LayoutIssue[];
  summary: string;
}

export interface InspectAncestorsResult {
  mode: 'ancestors';
  chain: UIWidget[];
  depth: number;
}

export type InspectResult = InspectQueryResult | InspectAnalyzeResult | InspectAncestorsResult;

// Smart diff result (combines visual + structural + issues)
export interface SmartDiffResult {
  visual: {
    diffPercentage: number;
    diffImageBase64: string;
    changedRegions: ChangedRegion[];
  };
  structural: {
    addedWidgets: UIWidget[];
    removedWidgets: UIWidget[];
    modifiedWidgets: ModifiedWidget[];
  };
  issues: LayoutIssue[];
  summary: string;
}

// WebSocket protocol messages
export interface WSMessage {
  type: string;
  requestId?: string;
  command?: string;
  params?: any;
  data?: any;
  error?: string;
}

export interface CaptureScreenshotRequest {
  type: 'full' | 'map';
  annotation?: string;
}

export interface ScreenshotCapturedResponse {
  imageBase64: string;
  width: number;
  height: number;
  type: 'full' | 'map';
  uiTree: UIWidget;
}

// Storage configuration
export interface StorageConfig {
  maxMemoryCache: number;
  maxDiskScreenshots: number;
  maxAgeDays: number;
  screenshotsDir: string;
}
