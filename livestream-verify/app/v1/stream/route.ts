import { NextRequest, NextResponse } from "next/server";
import { mkdirSync, writeFileSync, readdirSync, readFileSync } from "fs";
import { join } from "path";
import { randomUUID, randomBytes } from "crypto";
import { startLiveMonitor } from "@/lib/machinefi";

const MARKETS_DIR = join("/tmp", "markets");

function ensureMarketsDir() {
  mkdirSync(MARKETS_DIR, { recursive: true });
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const { stream_url, condition, title, initial_liquidity_wei } = body;

  if (!stream_url || !condition) {
    return NextResponse.json(
      { error: "stream_url and condition are required" },
      { status: 400 }
    );
  }

  const liquidityWei = BigInt(initial_liquidity_wei ?? "1000000000000000000");
  const halfWei = (liquidityWei / 2n).toString();
  const totalWei = liquidityWei.toString();

  const streamId = `stream-${randomUUID().slice(0, 8)}`;
  const marketId = `market-${randomUUID().slice(0, 8)}`;
  const txHash = "0x" + randomBytes(32).toString("hex");
  const now = Math.floor(Date.now() / 1000);
  const endsAt = now + 30 * 24 * 60 * 60; // 30 days

  // Start MachineFi live monitor for condition resolution
  let trioJobId = "none";
  try {
    const job = await startLiveMonitor({
      stream_url,
      condition,
      interval_seconds: 10,
      input_mode: "frames",
      monitor_duration_seconds: 30 * 24 * 60 * 60,
    });
    trioJobId = job.job_id;
  } catch {
    // Non-fatal: market is still created without monitoring
    trioJobId = `local-${randomUUID().slice(0, 8)}`;
  }

  const market = {
    stream_id: streamId,
    market_id: marketId,
    trio_job_id: trioJobId,
    stream_url,
    condition,
    title: title ?? "",
    status: "active",
    created_by: "user",
    is_agent_stream: false,
    market: {
      yes_pool_wei: halfWei,
      no_pool_wei: halfWei,
      yes_odds: 0.5,
      no_odds: 0.5,
      total_volume_wei: totalWei,
      bettors_count: 0,
    },
    starts_at: now,
    ends_at: endsAt,
    resolved: false,
    tx_hash: txHash,
  };

  ensureMarketsDir();
  writeFileSync(join(MARKETS_DIR, `${marketId}.json`), JSON.stringify(market));

  return NextResponse.json(market, { status: 201 });
}

export async function GET() {
  ensureMarketsDir();
  const files = readdirSync(MARKETS_DIR).filter((f) => f.endsWith(".json"));
  const markets = files
    .map((f) => {
      try {
        return JSON.parse(readFileSync(join(MARKETS_DIR, f), "utf-8"));
      } catch {
        return null;
      }
    })
    .filter(Boolean);

  return NextResponse.json({ markets, total: markets.length, next_cursor: null });
}
