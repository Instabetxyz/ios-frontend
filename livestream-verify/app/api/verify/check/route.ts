import { NextRequest, NextResponse } from "next/server";
import { checkOnce } from "@/lib/machinefi";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    if (!body.stream_url || !body.condition) {
      return NextResponse.json(
        { error: "stream_url and condition are required" },
        { status: 400 }
      );
    }
    const result = await checkOnce({
      stream_url: body.stream_url,
      condition: body.condition,
      include_frame: body.include_frame ?? true,
      input_mode: body.input_mode ?? "frames",
    });
    return NextResponse.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
