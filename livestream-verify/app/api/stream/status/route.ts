import { NextResponse } from "next/server";
import { getStreamState } from "@/lib/stream-manager";

export async function GET() {
  return NextResponse.json(getStreamState());
}
