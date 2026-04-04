import { NextResponse } from "next/server";
import { stopFFmpeg } from "@/lib/stream-manager";

export async function POST() {
  stopFFmpeg();
  return NextResponse.json({ success: true });
}
