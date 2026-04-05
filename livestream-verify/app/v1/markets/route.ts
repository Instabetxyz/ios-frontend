import { NextRequest, NextResponse } from "next/server";
import { mkdirSync, readdirSync, readFileSync } from "fs";
import { join } from "path";

const MARKETS_DIR = join("/tmp", "markets");

function ensureMarketsDir() {
  mkdirSync(MARKETS_DIR, { recursive: true });
}

export async function GET(req: NextRequest) {
  ensureMarketsDir();

  const { searchParams } = req.nextUrl;
  const status = searchParams.get("status");
  const limit = parseInt(searchParams.get("limit") ?? "20", 10);

  const files = readdirSync(MARKETS_DIR).filter((f) => f.endsWith(".json"));
  let markets = files
    .map((f) => {
      try {
        return JSON.parse(readFileSync(join(MARKETS_DIR, f), "utf-8"));
      } catch {
        return null;
      }
    })
    .filter(Boolean);

  if (status) {
    markets = markets.filter((m) => m.status === status);
  }

  // Sort newest first by starts_at
  markets.sort((a, b) => b.starts_at - a.starts_at);

  const paginated = markets.slice(0, limit);

  return NextResponse.json({
    markets: paginated,
    total: markets.length,
    next_cursor: null,
  });
}
