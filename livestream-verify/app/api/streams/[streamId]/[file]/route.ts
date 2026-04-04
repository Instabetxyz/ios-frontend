import { NextRequest, NextResponse } from "next/server";
import { readFileSync, existsSync } from "fs";
import { join } from "path";

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ streamId: string; file: string }> }
) {
  const { streamId, file } = await params;

  // Only allow segment files
  if (!/^segment_\d+\.mp4$/.test(file)) {
    return new NextResponse("Not found", { status: 404 });
  }

  const filePath = join("/tmp", "streams", streamId, file);
  if (!existsSync(filePath)) {
    return new NextResponse("Segment not found", { status: 404 });
  }

  const buf = readFileSync(filePath);
  return new NextResponse(buf, {
    headers: {
      "Content-Type": "video/mp4",
      "Cache-Control": "public, max-age=31536000",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
