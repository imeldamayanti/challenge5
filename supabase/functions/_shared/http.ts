// Shared HTTP plumbing for the three Edge Functions (b0 D7).
//
// No third-party imports anywhere in `supabase/functions/`. Everything these functions need —
// PostgREST, GoTrue admin, Storage — is a REST call, and `fetch` is already in the runtime. A
// driver or an SDK would be one more thing to pin, audit and keep in step for no capability.

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-sync-schema",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function preflight(req: Request): Response | null {
  return req.method === "OPTIONS" ? new Response("ok", { headers: corsHeaders }) : null;
}

export function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing environment variable ${name}`);
  return v;
}

/** The service_role key. Edge Function environment and CI secrets only — never the app (§8). */
export function serviceKey(): string {
  return env("SUPABASE_SERVICE_ROLE_KEY");
}

export function supabaseUrl(): string {
  return env("SUPABASE_URL");
}

/** Calls a PostgREST RPC as the service role. */
export async function rpc(name: string, args: unknown): Promise<Response> {
  return await fetch(`${supabaseUrl()}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: serviceKey(),
      Authorization: `Bearer ${serviceKey()}`,
      "Content-Type": "application/json",
      "Content-Profile": "app",
    },
    body: JSON.stringify(args),
  });
}

/** A PostgREST table request as the service role. `path` is everything after /rest/v1/. */
export async function rest(path: string, init: RequestInit = {}): Promise<Response> {
  const headers = new Headers(init.headers ?? {});
  headers.set("apikey", serviceKey());
  headers.set("Authorization", `Bearer ${serviceKey()}`);
  headers.set("Accept-Profile", "app");
  headers.set("Content-Profile", "app");
  if (init.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");
  return await fetch(`${supabaseUrl()}/rest/v1/${path}`, { ...init, headers });
}

/**
 * Resolves a bearer token to a user through GoTrue.
 *
 * This is the step §7.3 says a `security definer` SQL function cannot do: plpgsql cannot verify a
 * JWT signature without the signing secret, so a definer function that rewrites `user_id` would
 * rest its entire safety on argument validation. Here the token is proven before any uid is used.
 */
export async function userFromToken(
  token: string,
): Promise<{ id: string; is_anonymous: boolean; identities: unknown[] } | null> {
  const res = await fetch(`${supabaseUrl()}/auth/v1/user`, {
    headers: { apikey: serviceKey(), Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;
  const u = await res.json();
  if (!u?.id) return null;
  return { id: u.id, is_anonymous: !!u.is_anonymous, identities: u.identities ?? [] };
}

export function bearer(req: Request): string | null {
  const h = req.headers.get("Authorization") ?? "";
  return h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() : null;
}

/** Deletes an auth.users row through the admin API. */
export async function deleteAuthUser(id: string): Promise<Response> {
  return await fetch(`${supabaseUrl()}/auth/v1/admin/users/${id}`, {
    method: "DELETE",
    headers: { apikey: serviceKey(), Authorization: `Bearer ${serviceKey()}` },
  });
}
