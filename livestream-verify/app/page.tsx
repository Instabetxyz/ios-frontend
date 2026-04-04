"use client";

import { useCallback, useEffect, useRef, useState } from "react";

type StreamState = {
  started: boolean;
  rtspUrl: string | null;
  publicUrl: string | null;
};

type ValidateResult = {
  is_live: boolean;
  platform: string | null;
  title: string | null;
  channel: string | null;
  viewer_count: number | null;
  error_hint: string | null;
};

type CheckResult = {
  triggered: boolean;
  explanation: string;
  latency_ms: number;
  frame_b64?: string;
};

type MonitorJob = {
  job_id: string;
  status: string;
  created_at: string;
};

export default function Home() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [cameraActive, setCameraActive] = useState(false);
  const [streamState, setStreamState] = useState<StreamState>({
    started: false,
    rtspUrl: null,
    publicUrl: null,
  });
  const [tunnelLoading, setTunnelLoading] = useState(false);
  const [streamLoading, setStreamLoading] = useState(false);

  const [validateResult, setValidateResult] = useState<ValidateResult | null>(null);
  const [validateLoading, setValidateLoading] = useState(false);

  const [condition, setCondition] = useState("Is there a person visible in the frame?");
  const [checkResult, setCheckResult] = useState<CheckResult | null>(null);
  const [checkLoading, setCheckLoading] = useState(false);

  const [monitorJob, setMonitorJob] = useState<MonitorJob | null>(null);
  const [monitorLoading, setMonitorLoading] = useState(false);
  const [monitorIntervalId, setMonitorIntervalId] = useState<ReturnType<typeof setInterval> | null>(null);

  const [error, setError] = useState<string | null>(null);

  const startCamera = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 1280, height: 720, facingMode: "user" },
        audio: false,
      });
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
      }
      setCameraActive(true);
      setError(null);
    } catch (err) {
      setError("Camera access denied: " + (err instanceof Error ? err.message : String(err)));
    }
  }, []);

  const stopCamera = useCallback(() => {
    if (videoRef.current?.srcObject) {
      (videoRef.current.srcObject as MediaStream).getTracks().forEach((t) => t.stop());
      videoRef.current.srcObject = null;
    }
    setCameraActive(false);
  }, []);

  const startStream = useCallback(async () => {
    setStreamLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/stream/start", { method: "POST" });
      const data = await res.json();
      if (!data.success) throw new Error(data.error);
      setStreamState(data);
    } catch (err) {
      setError("Stream start failed: " + (err instanceof Error ? err.message : String(err)));
    } finally {
      setStreamLoading(false);
    }
  }, []);

  const stopStream = useCallback(async () => {
    await fetch("/api/stream/stop", { method: "POST" });
    setStreamState({ started: false, rtspUrl: null, publicUrl: null });
    setValidateResult(null);
    setCheckResult(null);
  }, []);

  const startTunnel = useCallback(async () => {
    setTunnelLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/tunnel", { method: "POST" });
      const data = await res.json();
      if (!data.success) throw new Error(data.error);
      setStreamState((prev) => ({ ...prev, publicUrl: data.publicUrl }));
    } catch (err) {
      setError("Tunnel failed: " + (err instanceof Error ? err.message : String(err)));
    } finally {
      setTunnelLoading(false);
    }
  }, []);

  const validateStream = useCallback(async () => {
    const url = streamState.publicUrl;
    if (!url) return;
    setValidateLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/verify/validate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stream_url: url }),
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error);
      setValidateResult(data);
    } catch (err) {
      setError("Validate failed: " + (err instanceof Error ? err.message : String(err)));
    } finally {
      setValidateLoading(false);
    }
  }, [streamState.publicUrl]);

  const checkOnce = useCallback(async () => {
    const url = streamState.publicUrl;
    if (!url || !condition) return;
    setCheckLoading(true);
    setError(null);
    setCheckResult(null);
    try {
      const res = await fetch("/api/verify/check", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stream_url: url, condition }),
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error);
      setCheckResult(data);
    } catch (err) {
      setError("Check failed: " + (err instanceof Error ? err.message : String(err)));
    } finally {
      setCheckLoading(false);
    }
  }, [streamState.publicUrl, condition]);

  const startMonitor = useCallback(async () => {
    const url = streamState.publicUrl;
    if (!url || !condition) return;
    setMonitorLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/verify/monitor", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stream_url: url, condition, interval_seconds: 10 }),
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error);
      setMonitorJob(data);

      const id = setInterval(async () => {
        const poll = await fetch(`/api/verify/monitor?job_id=${data.job_id}`);
        const pollData = await poll.json();
        setMonitorJob(pollData);
        if (pollData.status === "completed" || pollData.status === "failed") {
          clearInterval(id);
          setMonitorIntervalId(null);
        }
      }, 5000);
      setMonitorIntervalId(id);
    } catch (err) {
      setError("Monitor failed: " + (err instanceof Error ? err.message : String(err)));
    } finally {
      setMonitorLoading(false);
    }
  }, [streamState.publicUrl, condition]);

  const stopMonitor = useCallback(async () => {
    if (!monitorJob) return;
    if (monitorIntervalId) {
      clearInterval(monitorIntervalId);
      setMonitorIntervalId(null);
    }
    await fetch(`/api/verify/monitor?job_id=${monitorJob.job_id}`, { method: "DELETE" });
    setMonitorJob(null);
  }, [monitorJob, monitorIntervalId]);

  useEffect(() => {
    return () => {
      if (monitorIntervalId) clearInterval(monitorIntervalId);
    };
  }, [monitorIntervalId]);

  const streamUrl = streamState.publicUrl || streamState.rtspUrl;

  return (
    <main className="min-h-screen bg-gray-950 text-white p-6">
      <div className="max-w-4xl mx-auto space-y-6">
        <div className="text-center space-y-1">
          <h1 className="text-3xl font-bold tracking-tight">LiveStream Verify</h1>
          <p className="text-gray-400 text-sm">
            Stream your local camera · Verify with MachineFi Trio
          </p>
        </div>

        {error && (
          <div className="bg-red-900/50 border border-red-700 rounded-lg p-3 text-red-300 text-sm">
            {error}
          </div>
        )}

        <Section title="1. Camera Preview">
          <div className="relative bg-black rounded-xl overflow-hidden aspect-video">
            <video ref={videoRef} autoPlay muted playsInline className="w-full h-full object-cover" />
            {!cameraActive && (
              <div className="absolute inset-0 flex items-center justify-center text-gray-500">
                Camera off
              </div>
            )}
          </div>
          <div className="flex gap-3 mt-3">
            <Button onClick={startCamera} disabled={cameraActive} variant="primary">Start Camera</Button>
            <Button onClick={stopCamera} disabled={!cameraActive} variant="danger">Stop Camera</Button>
          </div>
        </Section>

        <Section title="2. Start RTSP Stream (FFmpeg → MediaMTX)">
          <p className="text-gray-400 text-sm mb-3">
            FFmpeg captures your camera and pushes to a local MediaMTX server at{" "}
            <code className="text-blue-400">rtsp://localhost:8554/live</code>.
            Run <code className="text-yellow-400">./scripts/start-mediamtx.sh</code> first.
          </p>
          <div className="flex gap-3">
            <Button onClick={startStream} disabled={streamState.started || streamLoading} variant="primary">
              {streamLoading ? "Starting..." : "Start Stream"}
            </Button>
            <Button onClick={stopStream} disabled={!streamState.started} variant="danger">Stop Stream</Button>
          </div>
          {streamState.started && <StatusBadge color="green" label="Local RTSP" value={streamState.rtspUrl!} />}
        </Section>

        <Section title="3. Expose via ngrok (public URL)">
          <p className="text-gray-400 text-sm mb-3">
            Creates a public TCP tunnel so MachineFi can reach your RTSP stream.
            Requires <code className="text-yellow-400">NGROK_AUTHTOKEN</code> in <code className="text-yellow-400">.env.local</code>.
          </p>
          <Button
            onClick={startTunnel}
            disabled={!streamState.started || !!streamState.publicUrl || tunnelLoading}
            variant="primary"
          >
            {tunnelLoading ? "Connecting..." : "Open Tunnel"}
          </Button>
          {streamState.publicUrl && <StatusBadge color="blue" label="Public HLS" value={streamState.publicUrl} />}
        </Section>

        <Section title="4. MachineFi — Validate Stream">
          <p className="text-gray-400 text-sm mb-3">
            Confirm MachineFi can reach and parse the public stream.
          </p>
          <Button onClick={validateStream} disabled={!streamUrl || validateLoading} variant="primary">
            {validateLoading ? "Validating..." : "Validate Stream"}
          </Button>
          {validateResult && (
            <div className="mt-3 bg-gray-800 rounded-lg p-4 text-sm space-y-1">
              <Row label="Live" value={validateResult.is_live ? "✅ Yes" : "❌ No"} />
              {validateResult.platform && <Row label="Platform" value={validateResult.platform} />}
              {validateResult.title && <Row label="Title" value={validateResult.title} />}
              {validateResult.error_hint && <Row label="Error" value={validateResult.error_hint} />}
            </div>
          )}
        </Section>

        <Section title="5. MachineFi — Check Condition (once)">
          <textarea
            className="w-full bg-gray-800 border border-gray-600 rounded-lg p-3 text-sm resize-none focus:outline-none focus:border-blue-500"
            rows={2}
            value={condition}
            onChange={(e) => setCondition(e.target.value)}
            placeholder="e.g. Is there a person visible in the frame?"
          />
          <Button onClick={checkOnce} disabled={!streamUrl || !condition || checkLoading} variant="primary">
            {checkLoading ? "Checking..." : "Check Once"}
          </Button>
          {checkResult && (
            <div className="mt-3 bg-gray-800 rounded-lg p-4 text-sm space-y-2">
              <Row label="Triggered" value={checkResult.triggered ? "✅ Yes" : "❌ No"} />
              <Row label="Latency" value={`${checkResult.latency_ms}ms`} />
              <p className="text-gray-300 italic">{checkResult.explanation}</p>
              {checkResult.frame_b64 && (
                <img src={`data:image/jpeg;base64,${checkResult.frame_b64}`} alt="Frame" className="rounded-lg w-full mt-2" />
              )}
            </div>
          )}
        </Section>

        <Section title="6. MachineFi — Live Monitor (continuous)">
          <p className="text-gray-400 text-sm mb-3">
            Continuously watches the stream every 10s for the condition above.
          </p>
          <div className="flex gap-3">
            <Button
              onClick={startMonitor}
              disabled={!streamUrl || !condition || monitorLoading || !!monitorJob}
              variant="primary"
            >
              {monitorLoading ? "Starting..." : "Start Monitor"}
            </Button>
            <Button onClick={stopMonitor} disabled={!monitorJob} variant="danger">Stop Monitor</Button>
          </div>
          {monitorJob && (
            <div className="mt-3 bg-gray-800 rounded-lg p-4 text-sm space-y-1">
              <Row label="Job ID" value={monitorJob.job_id} />
              <Row label="Status" value={monitorJob.status} />
              <Row label="Created" value={new Date(monitorJob.created_at).toLocaleTimeString()} />
            </div>
          )}
        </Section>
      </div>
    </main>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 space-y-3">
      <h2 className="font-semibold text-lg text-gray-100">{title}</h2>
      {children}
    </div>
  );
}

function Button({ onClick, disabled, variant, children }: {
  onClick: () => void;
  disabled?: boolean;
  variant: "primary" | "danger";
  children: React.ReactNode;
}) {
  const styles = { primary: "bg-blue-600 hover:bg-blue-500", danger: "bg-red-700 hover:bg-red-600" };
  return (
    <button
      className={`px-4 py-2 rounded-lg text-sm font-medium text-white transition-colors disabled:opacity-40 disabled:cursor-not-allowed ${styles[variant]}`}
      onClick={onClick}
      disabled={disabled}
    >
      {children}
    </button>
  );
}

function StatusBadge({ color, label, value }: { color: "green" | "blue"; label: string; value: string }) {
  const styles = { green: "bg-green-900/40 border-green-700 text-green-300", blue: "bg-blue-900/40 border-blue-700 text-blue-300" };
  return (
    <div className={`mt-3 border rounded-lg px-4 py-2 text-sm ${styles[color]}`}>
      <span className="font-medium">{label}:</span> <code className="break-all">{value}</code>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex gap-2">
      <span className="text-gray-400 w-24 shrink-0">{label}</span>
      <span className="text-gray-100">{value}</span>
    </div>
  );
}
