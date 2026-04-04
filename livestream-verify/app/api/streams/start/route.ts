import { NextRequest, NextResponse } from "next/server";
import { mkdirSync } from "fs";
import { join } from "path";
import { randomUUID } from "crypto";

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const streamId = `stream-${randomUUID().slice(0, 8)}`;
  const dir = join("/tmp", "streams", streamId);
  mkdirSync(dir, { recursive: true });

  // Store metadata
  const meta = { streamId, title: body.title ?? "", creatorAddress: body.creatorAddress ?? "", segments: [] as number[], startedAt: Date.now() };
  const { writeFileSync } = await import("fs");
  writeFileSync(join(dir, "meta.json"), JSON.stringify(meta));

  return NextResponse.json({ streamId });
}
