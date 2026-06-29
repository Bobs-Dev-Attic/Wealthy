// Wealthy price-quote proxy.
// Fetches recent (end-of-day / delayed) prices from Stooq, a free no-API-key
// source, server-side so the browser never hits CORS. Authenticated users only.
//   POST { symbols: ["AAPL", "VTI", "VTSAX"] }  ->  { "AAPL": 192.34, ... }

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json().catch(() => ({}));
    let symbols: string[] = Array.isArray(body?.symbols) ? body.symbols : [];
    symbols = symbols
      .map((s) => String(s).trim().toUpperCase())
      .filter((s) => s.length > 0 && s.length <= 12)
      .slice(0, 50);
    if (symbols.length === 0) return json({});

    // Stooq wants lowercase, and US tickers need a `.us` suffix.
    const stooq = symbols
      .map((s) => (s.includes(".") ? s.toLowerCase() : `${s.toLowerCase()}.us`))
      .join(",");
    const url =
      `https://stooq.com/q/l/?s=${encodeURIComponent(stooq)}&f=sd2t2ohlcv&h&e=csv`;

    const res = await fetch(url, { headers: { "User-Agent": "wealthy/1.0" } });
    if (!res.ok) return json({ error: `quote source ${res.status}` }, 502);
    const text = await res.text();

    // Header: Symbol,Date,Time,Open,High,Low,Close,Volume
    const out: Record<string, number | null> = {};
    const lines = text.trim().split(/\r?\n/);
    for (let i = 1; i < lines.length; i++) {
      const cols = lines[i].split(",");
      if (cols.length < 7) continue;
      const sym = (cols[0] || "").replace(/\.[A-Za-z]+$/, "").toUpperCase();
      const close = parseFloat(cols[6]);
      out[sym] = Number.isFinite(close) ? close : null;
    }
    return json(out);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
