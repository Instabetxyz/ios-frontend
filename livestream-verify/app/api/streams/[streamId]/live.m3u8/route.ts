import { NextRequest, NextResponse } from "next/server";
import { readFileSync, existsSync } from "fs";
import { join } from "path";

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ streamId: string }> }
) {
  const { streamId } = await params;
  const dir = join("/tmp", "streams", streamId);
  const metaPath = join(dir, "meta.json");

  if (!existsSync(metaPath)) {
    return new NextResponse("Stream not found", { status: 404 });
  }

  const meta = JSON.parse(readFileSync(metaPath, "utf-8"));
  const segments: number[] = meta.segments ?? [];
  const duration: number = meta.lastDuration ?? 3;

  const origin = req.nextUrl.origin;
  const baseUrl = `${origin}/api/streams/${streamId}`;

  const lines = [
    "#EXTM3U",
    "#EXT-X-VERSION:3",
    `#EXT-X-TARGETDURATION:${Math.ceil(duration)}`,
    `#EXT-X-MEDIA-SEQUENCE:0`,
  ];

  for (const idx of segments) {
    lines.push(`#EXTINF:${duration.toFixed(3)},`);
    lines.push(`${baseUrl}/segment_${idx}.mp4`);
  }

  const playlist = lines.join("\n") + "\n";

  return new NextResponse(playlist, {
    headers: {
      "Content-Type": "application/vnd.apple.mpegurl",
      "Cache-Control": "no-cache",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
