import { NextRequest, NextResponse } from "next/server";
import { validateStream } from "@/lib/machinefi";

export async function POST(req: NextRequest) {
  try {
    const { stream_url } = await req.json();
    if (!stream_url) {
      return NextResponse.json({ error: "stream_url is required" }, { status: 400 });
    }
    const result = await validateStream(stream_url);
    return NextResponse.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
