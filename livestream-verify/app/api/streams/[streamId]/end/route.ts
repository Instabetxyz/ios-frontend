import { NextRequest, NextResponse } from "next/server";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";
import { randomBytes } from "crypto";

export async function POST(
  _req: NextRequest,
  { params }: { params: Promise<{ streamId: string }> }
) {
  const { streamId } = await params;
  const dir = join("/tmp", "streams", streamId);
  const metaPath = join(dir, "meta.json");

  if (!existsSync(metaPath)) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const meta = JSON.parse(readFileSync(metaPath, "utf-8"));
  meta.endedAt = Date.now();
  writeFileSync(metaPath, JSON.stringify(meta));

  const rootHash = "0x" + randomBytes(32).toString("hex");
  return NextResponse.json({ rootHash });
}
