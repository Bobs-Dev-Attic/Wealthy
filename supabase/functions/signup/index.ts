// Wealthy signup edge function.
// Public endpoint (verify_jwt=false): provisions a confirmed auth user whose
// login email is `<userId>@wealthy.local` and whose password is a generated
// high-entropy access code. The QR code on the client encodes {userId, accessCode};
// login is then a plain client-side signInWithPassword. RLS uses auth.uid().
//
// Deploy:  supabase functions deploy signup --no-verify-jwt
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Crockford-ish base32 without ambiguous chars (no 0/O/1/I).
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
function genAccessCode(groups = 4, len = 4): string {
  const bytes = new Uint8Array(groups * len);
  crypto.getRandomValues(bytes);
  const out: string[] = [];
  for (let g = 0; g < groups; g++) {
    let s = "";
    for (let i = 0; i < len; i++) s += ALPHABET[bytes[g * len + i] % ALPHABET.length];
    out.push(s);
  }
  return out.join("-"); // ~80 bits of entropy
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method not allowed" }), {
      status: 405, headers: { ...cors, "Content-Type": "application/json" },
    });
  }
  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const body = await req.json().catch(() => ({}));
    const name = typeof body?.name === "string" && body.name.trim() ? body.name.trim() : null;
    const accessCode = genAccessCode();

    // Create with a throwaway email first (we don't know the uuid yet).
    const tempEmail = `${crypto.randomUUID()}@wealthy.local`;
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email: tempEmail,
      password: accessCode,
      email_confirm: true,
      user_metadata: name ? { name } : {},
    });
    if (createErr || !created?.user) throw createErr ?? new Error("create failed");

    const userId = created.user.id;
    // Rebind email deterministically so the client can log in from just the QR.
    const finalEmail = `${userId}@wealthy.local`;
    const { error: updErr } = await admin.auth.admin.updateUserById(userId, {
      email: finalEmail,
      email_confirm: true,
    });
    if (updErr) throw updErr;

    return new Response(
      JSON.stringify({ userId, accessCode, email: finalEmail }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : String(e) }),
      { status: 400, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
