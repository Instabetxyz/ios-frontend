const BASE_URL = "https://trio.machinefi.com/api";

function authHeaders() {
  const key = process.env.MACHINEFI_API_KEY;
  if (!key) throw new Error("MACHINEFI_API_KEY not set");
  return {
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  };
}

export interface ValidateResponse {
  is_live: boolean;
  platform: string | null;
  stream_id: string | null;
  title: string | null;
  channel: string | null;
  thumbnail_url: string | null;
  viewer_count: number | null;
  parsed_url: string | null;
  error_hint: string | null;
}

export interface CheckOnceRequest {
  stream_url: string;
  condition: string;
  include_frame?: boolean;
  input_mode?: "frames" | "clip" | "hybrid";
  clip_duration_seconds?: number;
}

export interface CheckOnceResponse {
  triggered: boolean;
  explanation: string;
  latency_ms: number;
  frame_b64?: string;
}

export interface LiveMonitorRequest {
  stream_url: string;
  condition: string;
  webhook_url?: string;
  interval_seconds?: number;
  input_mode?: "frames" | "clip" | "hybrid";
  clip_duration_seconds?: number;
  monitor_duration_seconds?: number;
  trigger_cooldown_seconds?: number;
  max_triggers?: number | null;
}

export interface JobResponse {
  job_id: string;
  status: string;
  created_at: string;
  stream_url: string;
  job_type: string;
  details?: unknown;
  message?: string;
}

export async function validateStream(stream_url: string): Promise<ValidateResponse> {
  const res = await fetch(`${BASE_URL}/streams/validate`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ stream_url }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`MachineFi validate error ${res.status}: ${err}`);
  }
  return res.json();
}

export async function checkOnce(req: CheckOnceRequest): Promise<CheckOnceResponse> {
  const res = await fetch(`${BASE_URL}/check-once`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`MachineFi check-once error ${res.status}: ${err}`);
  }
  return res.json();
}

export async function startLiveMonitor(req: LiveMonitorRequest): Promise<JobResponse> {
  const res = await fetch(`${BASE_URL}/live-monitor`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(req),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`MachineFi live-monitor error ${res.status}: ${err}`);
  }
  return res.json();
}

export async function getJob(job_id: string): Promise<JobResponse> {
  const res = await fetch(`${BASE_URL}/jobs/${job_id}`, {
    headers: authHeaders(),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`MachineFi get-job error ${res.status}: ${err}`);
  }
  return res.json();
}

export async function deleteJob(job_id: string): Promise<void> {
  const res = await fetch(`${BASE_URL}/jobs/${job_id}`, {
    method: "DELETE",
    headers: authHeaders(),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`MachineFi delete-job error ${res.status}: ${err}`);
  }
}
