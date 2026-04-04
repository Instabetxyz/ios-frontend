import { NextResponse } from "next/server";
import type { Tunnel } from "localtunnel";
import { setPublicUrl, getStreamState, MEDIAMTX_HLS_PORT } from "@/lib/stream-manager";

// Module-level tunnel reference so we can close it on DELETE
let activeTunnel: Tunnel | null = null;

export async function POST() {
  const state = getStreamState();
  if (!state.started) {
    return NextResponse.json(
      { error: "Stream not started. Start FFmpeg first." },
      { status: 400 }
    );
  }

  try {
    const localtunnel = (await import("localtunnel")).default;
    const tunnel = await localtunnel({ port: MEDIAMTX_HLS_PORT });
    activeTunnel = tunnel;

    // MediaMTX HLS path — tunnel.url is a string like https://abc.loca.lt
    const publicUrl = `${tunnel.url}/live/index.m3u8`;
    setPublicUrl(publicUrl);

    tunnel.on("close", () => {
      activeTunnel = null;
      setPublicUrl("");
    });

    return NextResponse.json({ success: true, publicUrl });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}

export async function DELETE() {
  try {
    if (activeTunnel) {
      await activeTunnel.close();
      activeTunnel = null;
    }
    setPublicUrl("");
    return NextResponse.json({ success: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
