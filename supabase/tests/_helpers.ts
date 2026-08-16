// Shared helpers for the Deno suites.
//
// Everything here talks to the local stack over HTTP with REAL tokens, because that is the only
// way to prove what b3 §4 is about: pgTAP proves the POLICIES are correct, and three things sit
// between a policy and a request that pgTAP never touches — PostgREST's exposed-schema
// configuration, the grants attached to anon and authenticated, and the Storage service's own
// policy evaluation.
//
// The keys below are the well-known local development keys that `supabase start` prints on every
// machine. They are not secrets and they are not the project's. The prod service_role key never
// appears in this repository (design §8).

export const API_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
export const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
export const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";

export interface TestUser {
  id: string;
  email: string;
  password: string;
  token: string;
}

let counter = 0;
function uniqueEmail(): string {
  counter += 1;
  return `t${Date.now()}-${counter}-${crypto.randomUUID().slice(0, 8)}@example.test`;
}

/**
 * Creates a confirmed user through the admin API.
 *
 * config.toml sets `enable_confirmations = true` (b1 §2), so a plain signup would sit unconfirmed
 * and unable to sign in. Confirming through the admin API keeps that production-shaped setting
 * intact rather than weakening it for the tests.
 */
export async function createUser(): Promise<TestUser> {
  const email = uniqueEmail();
  const password = `pw-${crypto.randomUUID()}`;
  const res = await fetch(`${API_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!res.ok) throw new Error(`createUser failed: ${res.status} ${await res.text()}`);
  const user = await res.json();
  const token = await signIn(email, password);
  return { id: user.id, email, password, token };
}

export async function signIn(email: string, password: string): Promise<string> {
  const res = await fetch(`${API_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new Error(`signIn failed: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token;
}

/** design §7: a walk can start immediately; nothing is gated on an account. */
export async function signInAnonymously(): Promise<{ id: string; token: string }> {
  const res = await fetch(`${API_URL}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: ANON_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
  if (!res.ok) throw new Error(`anonymous sign-in failed: ${res.status} ${await res.text()}`);
  const body = await res.json();
  return { id: body.user.id, token: body.access_token };
}

/** A PostgREST request as a given token (or as `anon` when the token is the publishable key). */
export function rest(path: string, token: string, init: RequestInit = {}): Promise<Response> {
  const headers = new Headers(init.headers ?? {});
  headers.set("apikey", ANON_KEY);
  headers.set("Authorization", `Bearer ${token}`);
  headers.set("Accept-Profile", "app");
  headers.set("Content-Profile", "app");
  if (init.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");
  return fetch(`${API_URL}/rest/v1/${path}`, { ...init, headers });
}

export function serviceRest(path: string, init: RequestInit = {}): Promise<Response> {
  return rest(path, SERVICE_KEY, init);
}

export function fn(name: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${API_URL}/functions/v1/${name}`, init);
}

export async function upload(
  bucket: string,
  path: string,
  token: string,
  body: BodyInit,
  contentType = "image/heic",
): Promise<Response> {
  return await fetch(`${API_URL}/storage/v1/object/${bucket}/${path}`, {
    method: "POST",
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${token}`,
      "Content-Type": contentType,
    },
    body,
  });
}

export function newRun(userId: string) {
  const id = crypto.randomUUID();
  return {
    id,
    body: {
      id,
      user_id: userId,
      quest_id: `quest-${id.slice(0, 8)}`,
      content_version: "2026.08.1",
      language: "id",
      state: "active",
      started_at: new Date().toISOString(),
      device_id: crypto.randomUUID(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
  };
}

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Runs SQL against the local database as `postgres`, through the running container.
 *
 * Used only to INSPECT what a request did — never to prove isolation. b0 D9's rule applies to any
 * elevated connection, not only to the MCP: a query that bypasses RLS cannot prove who can read
 * what. Isolation is proved by the HTTP suites with real user tokens.
 */
export async function sql(query: string): Promise<string> {
  const container = await dbContainer();
  const cmd = new Deno.Command("docker", {
    args: ["exec", "-i", container, "psql", "-U", "postgres", "-d", "postgres", "-At", "-c", query],
    stdout: "piped",
    stderr: "piped",
  });
  const { code, stdout, stderr } = await cmd.output();
  if (code !== 0) throw new Error(`psql failed: ${new TextDecoder().decode(stderr)}`);
  return new TextDecoder().decode(stdout).trim();
}

let cachedContainer: string | null = null;
export async function dbContainer(): Promise<string> {
  if (cachedContainer) return cachedContainer;
  const cmd = new Deno.Command("docker", {
    args: ["ps", "--filter", "name=supabase_db_", "--format", "{{.Names}}"],
    stdout: "piped",
  });
  const { stdout } = await cmd.output();
  const name = new TextDecoder().decode(stdout).trim().split("\n")[0];
  if (!name) throw new Error("no running supabase_db_* container — is `supabase start` up?");
  cachedContainer = name;
  return name;
}
