import { NextResponse } from "next/server";
import { startFFmpeg, getStreamState } from "@/lib/stream-manager";

export async function POST() {
  try {
    await startFFmpeg();
    const state = getStreamState();
    return NextResponse.json({ success: true, ...state });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ success: false, error: message }, { status: 500 });
  }
}
