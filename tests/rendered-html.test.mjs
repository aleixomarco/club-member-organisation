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

/* Der Test hing lange auf einem alten Stand: Er verlangte den Titel
   "ERG Iserlohn Vereins-App" und Texte wie "Verein auswählen" im
   ausgelieferten HTML. Beides trifft nicht mehr zu - die App heisst
   "Club Member Organisation", und die Oberflaeche baut sich im Browser auf;
   serverseitig kommt nur die Huelle. Ausserdem lief er nie: Er laedt
   dist/server/index.js, und dieser Build fehlte im Testskript.
   Geprueft wird jetzt, was tatsaechlich gilt - dass die Startseite
   serverseitig ohne Absturz rendert und die Huelle stimmt. */
test("liefert die Huelle der Startseite serverseitig aus", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>Club Member Organisation<\/title>/i);
  assert.match(html, /<html lang="de"/i);
  /* Die Kennzeichen der App-Huelle - ohne sie startet die native App nicht
     richtig (Manifest, Statusleistenfarbe, Kurzname auf dem Homescreen). */
  assert.match(html, /rel="manifest"/i);
  assert.match(html, /name="theme-color"/i);
  assert.match(html, /apple-mobile-web-app-title"\s+content="CMO"/i);
  /* Und keine Reste der Projektvorlage. */
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
