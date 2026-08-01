import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(new Request("http://localhost/", { headers: { accept: "text/html" } }), {
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
  }, { waitUntil() {}, passThroughOnException() {} });
}

test("renders the Club Member Organisation entry screen", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>ERG Iserlohn Vereins-App<\/title>/i);
  assert.match(html, /Willkommen/);
  assert.match(html, /ERG Iserlohn/);
  assert.match(html, /Verein auswählen/);
  assert.doesNotMatch(html, /Your site is taking shape|codex-preview/);
});

test("contains the Supabase production integration and secured schema", async () => {
  const [page, client, migration] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../lib/supabase.ts", import.meta.url), "utf8"),
    readFile(new URL("../supabase/migrations/20260801160000_initial_schema.sql", import.meta.url), "utf8"),
  ]);
  assert.match(page, /signInWithPassword/);
  assert.match(page, /register_for_club/);
  assert.match(client, /NEXT_PUBLIC_SUPABASE_URL/);
  assert.match(client, /NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY/);
  assert.match(migration, /alter table public\.club_memberships enable row level security/);
  assert.match(migration, /create policy "finance manages fees"/);
  assert.match(migration, /'ERG Iserlohn'/);
});
