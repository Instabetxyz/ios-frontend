import { NextRequest, NextResponse } from "next/server";
import { startLiveMonitor, getJob, deleteJob } from "@/lib/machinefi";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    if (!body.stream_url || !body.condition) {
      return NextResponse.json(
        { error: "stream_url and condition are required" },
        { status: 400 }
      );
    }
    const result = await startLiveMonitor({
      stream_url: body.stream_url,
      condition: body.condition,
      interval_seconds: body.interval_seconds ?? 10,
      input_mode: body.input_mode ?? "frames",
      monitor_duration_seconds: body.monitor_duration_seconds ?? 300,
      max_triggers: body.max_triggers ?? null,
    });
    return NextResponse.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function GET(req: NextRequest) {
  const job_id = req.nextUrl.searchParams.get("job_id");
  if (!job_id) {
    return NextResponse.json({ error: "job_id query param required" }, { status: 400 });
  }
  try {
    const result = await getJob(job_id);
    return NextResponse.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest) {
  const job_id = req.nextUrl.searchParams.get("job_id");
  if (!job_id) {
    return NextResponse.json({ error: "job_id query param required" }, { status: 400 });
  }
  try {
    await deleteJob(job_id);
    return NextResponse.json({ success: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
