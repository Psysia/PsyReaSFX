export interface Waveform {
  count: number;
  peaks: number[];
  channels?: number[][];
  channelCount?: number;
  spectralFrequency?: number[];
  spectralTonality?: number[];
}

export interface Asset {
  path: string;
  name: string;
  index?: number;
  duration: number;
  channels: number;
  sampleRate: number;
  bitDepth: number;
  library: string;
  description: string;
  keywords: string;
  category: string;
  subcategory: string;
  catid: string;
  notes: string;
  favorite: boolean;
  marked?: boolean;
  played?: boolean;
  previewCount?: number;
  usedCount?: number;
  workflowLabel?: string;
  workflow_status?: string;
  format?: string;
  similarity?: string;
  artwork_path?: string;
  channelsSelected?: boolean[];
  channelMode?: "original" | "left" | "right" | "mono" | "custom";
  regions?: { start: number; finish: number; name: string }[];
  loudness?: { label: string; value: string; accent?: boolean }[];
  ucsCandidates?: { catid: string; label: string; score: number }[];
  truncated?: Record<string, boolean>;
  selected?: boolean;
  waveform?: Waveform | null;
  waveError?: boolean;
}

export interface DetailWaveform {
  path: string;
  duration: number;
  waveform?: Waveform | null;
  error?: string;
}

export interface CatalogPage {
  revision: number;
  offset: number;
  total: number;
  pending: boolean;
  items: Asset[];
}

export interface HostRequest {
  protocol: 1;
  id: string;
  method: string;
  params: Record<string, unknown>;
}

export interface HostResponse {
  protocol: 1;
  id: string;
  ok: boolean;
  result?: unknown;
  error?: string;
}

export interface Session {
  protocol: 1;
  version?: string;
  host: "reaper" | "desktop";
  capabilities: Record<string, boolean>;
  runtimePolicy?: {
    protocol: number;
    runtime_contracts: number[];
    web_contracts: number[];
    minimum_message_bytes: number;
    baseline_versions: string[];
    validation_status: string;
  };
}

export class HostConnection extends EventTarget {
  state: Record<string, unknown> | null;
  session: Session | null;
  runtime?: { version: string; status: string; notice: string };
  constructor(send: (message: HostRequest) => unknown);
  request<T = unknown>(
    method: string,
    params?: Record<string, unknown>,
  ): Promise<T>;
  receive(message: string | HostResponse): void;
  dragFiles(paths: string[]): Promise<boolean>;
  reveal(path: string): Promise<boolean>;
  artworkUrl(path: string): Promise<string | null>;
  subscribeDrops?(
    callback: (payload: {
      files: string[];
      text?: string;
      x: number;
      y: number;
    }) => void,
  ): Promise<void>;
  close(): void;
}
export function connectHost(): Promise<HostConnection>;
