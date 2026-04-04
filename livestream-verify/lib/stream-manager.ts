import { ChildProcess, spawn } from "child_process";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";

interface StreamState {
  process: ChildProcess | null;
  rtspUrl: string | null;
  publicUrl: string | null;
  started: boolean;
}

// File-based state so all API route sandboxes share it (Turbopack isolates module globals)
const STATE_FILE = join("/tmp", "livestream-verify-state.json");

interface PersistedState {
  started: boolean;
  rtspUrl: string | null;
  publicUrl: string | null;
  pid: number | null;
}

function readPersistedState(): PersistedState {
  if (!existsSync(STATE_FILE)) return { started: false, rtspUrl: null, publicUrl: null, pid: null };
  try {
    return JSON.parse(readFileSync(STATE_FILE, "utf-8"));
  } catch {
    return { started: false, rtspUrl: null, publicUrl: null, pid: null };
  }
}

function writePersistedState(s: PersistedState) {
  writeFileSync(STATE_FILE, JSON.stringify(s));
}

// In-process process handle (only valid in the route that spawned it)
const state: StreamState = {
  process: null,
  rtspUrl: null,
  publicUrl: null,
  started: false,
};

export const MEDIAMTX_RTSP_PORT = 8554;
export const MEDIAMTX_HLS_PORT = 8888;
export const LOCAL_RTSP = `rtsp://localhost:${MEDIAMTX_RTSP_PORT}/live`;
export const LOCAL_HLS = `http://localhost:${MEDIAMTX_HLS_PORT}/live/index.m3u8`;

/**
 * Start FFmpeg to capture the default camera and push to MediaMTX.
 * On macOS uses AVFoundation; falls back to v4l2 on Linux.
 */
export function startFFmpeg(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (state.process) {
      resolve();
      return;
    }

    const isMac = process.platform === "darwin";
    const args = isMac
      ? [
          "-f", "avfoundation",
          "-framerate", "30",
          "-video_size", "1280x720",
          "-i", "0:none",
          "-pix_fmt", "yuv420p",     // force 4:2:0 so libx264 uses baseline/main profile
          "-c:v", "libx264",
          "-preset", "ultrafast",
          "-tune", "zerolatency",
          "-profile:v", "baseline",
          "-g", "30",
          "-f", "rtsp",
          "-rtsp_transport", "tcp",
          LOCAL_RTSP,
        ]
      : [
          "-f", "v4l2",
          "-framerate", "30",
          "-video_size", "1280x720",
          "-i", "/dev/video0",
          "-pix_fmt", "yuv420p",
          "-c:v", "libx264",
          "-preset", "ultrafast",
          "-tune", "zerolatency",
          "-profile:v", "baseline",
          "-g", "30",
          "-f", "rtsp",
          "-rtsp_transport", "tcp",
          LOCAL_RTSP,
        ];

    const proc = spawn("ffmpeg", args, { stdio: ["ignore", "pipe", "pipe"], detached: false });

    proc.stderr?.on("data", (data: Buffer) => {
      const line = data.toString();
      // "frame=" in stderr means FFmpeg is actively encoding and sending frames
      if (!state.started && line.includes("frame=")) {
        state.process = proc;
        state.started = true;
        state.rtspUrl = LOCAL_RTSP;
        writePersistedState({ started: true, rtspUrl: LOCAL_RTSP, publicUrl: null, pid: proc.pid ?? null });
        resolve();
      }
    });

    proc.on("error", (err) => {
      reject(new Error(`FFmpeg spawn error: ${err.message}`));
    });

    proc.on("exit", (code) => {
      state.process = null;
      state.started = false;
      writePersistedState({ started: false, rtspUrl: null, publicUrl: null, pid: null });
      if (code !== 0 && code !== null) {
        reject(new Error(`FFmpeg exited with code ${code}`));
      }
    });

    setTimeout(() => {
      if (!state.started) {
        proc.kill();
        reject(new Error("FFmpeg timed out connecting to MediaMTX"));
      }
    }, 8000);
  });
}

export function stopFFmpeg(): void {
  if (state.process) {
    state.process.kill("SIGTERM");
    state.process = null;
    state.started = false;
    state.rtspUrl = null;
  }
  // Also kill by PID in case we're in a different route context
  const persisted = readPersistedState();
  if (persisted.pid) {
    try { process.kill(persisted.pid, "SIGTERM"); } catch { /* already dead */ }
  }
  writePersistedState({ started: false, rtspUrl: null, publicUrl: null, pid: null });
}

export function getStreamState() {
  const persisted = readPersistedState();
  return {
    started: persisted.started,
    rtspUrl: persisted.rtspUrl,
    publicUrl: persisted.publicUrl,
  };
}

export function setPublicUrl(url: string) {
  const persisted = readPersistedState();
  persisted.publicUrl = url || null;
  writePersistedState(persisted);
}
