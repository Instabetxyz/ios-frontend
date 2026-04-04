import { NextRequest, NextResponse } from "next/server";
import { writeFileSync, readFileSync, existsSync } from "fs";
import { join } from "path";

export const config = { api: { bodyParser: false } };

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ streamId: string }> }
) {
  const { streamId } = await params;
  const dir = join("/tmp", "streams", streamId);

  if (!existsSync(dir)) {
    return NextResponse.json({ error: "Stream not found" }, { status: 404 });
  }

  const formData = await req.formData();
  const segmentFile = formData.get("segment") as File | null;
  const duration = parseFloat((formData.get("duration") as string) ?? "3");

  if (!segmentFile) {
    return NextResponse.json({ error: "No segment file" }, { status: 400 });
  }

  const bytes = await segmentFile.arrayBuffer();
  const buf = Buffer.from(bytes);

  // Parse index from filename (segment_0.mp4 → 0) or use meta count
  const metaPath = join(dir, "meta.json");
  const meta = JSON.parse(readFileSync(metaPath, "utf-8"));
  const index: number = meta.segments.length;

  const filename = `segment_${index}.mp4`;
  writeFileSync(join(dir, filename), buf);

  meta.segments.push(index);
  meta.lastDuration = duration;
  writeFileSync(metaPath, JSON.stringify(meta));

  return NextResponse.json({ segmentIndex: index, filename });
}
