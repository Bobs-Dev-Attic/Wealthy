// Wealthy price-quote proxy.
// Fetches recent (delayed / end-of-day) prices server-side so the browser never
// hits CORS. Tries Yahoo Finance first (open v8 chart endpoint, no API key) and
// falls back to Stooq per symbol. Authenticated users only.
//   POST { symbols: ["AAPL", "VTI", "VTSAX"] }
//   ->   { prices: {"AAPL": 192.34}, details: [...], requested: [...] }

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

interface Detail {
  symbol: string;
  price: number | null;
  source: string | null;
  status: string;
}

// Yahoo Finance v8 chart endpoint — no API key, works server-side.
async function yahoo(sym: string): Promise<number | null> {
  const url =
    `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(sym)}?range=1d&interval=1d`;
  const res = await fetch(url, {
    headers: { "User-Agent": "Mozilla/5.0 (compatible; wealthy/1.0)" },
  });
  if (!res.ok) return null;
  const data = await res.json();
  const meta = data?.chart?.result?.[0]?.meta;
  const p = meta?.regularMarketPrice ?? meta?.previousClose ?? meta?.chartPreviousClose;
  return typeof p === "number" && Number.isFinite(p) && p > 0 ? p : null;
}

// Stooq CSV fallback. US tickers need a `.us` suffix.
async function stooq(sym: string): Promise<number | null> {
  const s = sym.includes(".") ? sym.toLowerCase() : `${sym.toLowerCase()}.us`;
  const url = `https://stooq.com/q/l/?s=${encodeURIComponent(s)}&f=sd2t2ohlcv&h&e=csv`;
  const res = await fetch(url, { headers: { "User-Agent": "wealthy/1.0" } });
  if (!res.ok) return null;
  const text = await res.text();
  const lines = text.trim().split(/\r?\n/);
  if (lines.length < 2) return null;
  const cols = lines[1].split(",");
  if (cols.length < 7) return null;
  const close = parseFloat(cols[6]);
  return Number.isFinite(close) ? close : null;
}

async function lookup(sym: string): Promise<Detail> {
  try {
    let price = await yahoo(sym);
    let source: string | null = price != null ? "yahoo" : null;
    if (price == null) {
      price = await stooq(sym);
      if (price != null) source = "stooq";
    }
    return { symbol: sym, price, source, status: price != null ? "ok" : "not found" };
  } catch (e) {
    return {
      symbol: sym,
      price: null,
      source: null,
      status: "error: " + (e instanceof Error ? e.message : String(e)),
    };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json().catch(() => ({}));
    let symbols: string[] = Array.isArray(body?.symbols) ? body.symbols : [];
    symbols = symbols
      .map((s) => String(s).trim().toUpperCase())
      .filter((s) => s.length > 0 && s.length <= 12)
      .slice(0, 50);
    if (symbols.length === 0) return json({ prices: {}, details: [], requested: [] });

    const details = await Promise.all(symbols.map(lookup));
    const prices: Record<string, number> = {};
    for (const d of details) {
      if (d.price != null) prices[d.symbol] = d.price;
    }
    return json({ prices, details, requested: symbols });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
