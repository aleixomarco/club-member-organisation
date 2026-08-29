-- Kontolöschung darf nicht an einer Neuigkeit scheitern.
--
-- news_posts.author_id verwies mit "on delete restrict" auf profiles. Das war der
-- einzige Fremdschlüssel im ganzen Schema, der eine Löschung blockiert, statt sie
-- weiterzureichen. Die Folge: Wer je eine Neuigkeit verfasst hat - also jeder
-- Redakteur, Vorstand und Vereinsadmin - konnte sein Konto nicht mehr löschen.
-- auth.users -> profiles kaskadiert, lief hier auf, und /api/account/delete
-- antwortete mit "Deletion failed".
--
-- Apple verlangt unter Richtlinie 5.1.1(v) ausdrücklich, dass ein Konto AUS DER
-- APP HERAUS löschbar ist. Der Prüfer meldet sich mit einem Vorstandskonto an,
-- und Artikel 17 DSGVO verlangt dasselbe unabhängig davon.
--
-- Die Tabelle führt author_name als eigene Spalte. Die Neuigkeit kann den Autor
-- also überleben, ohne dass etwas fehlt - genau dafür war die Spalte gedacht.
-- Damit ist "set null" die passende Regel und fügt sich zu den übrigen
-- created_by-Verweisen im Schema, die es längst so halten.

alter table public.news_posts alter column author_id drop not null;

alter table public.news_posts drop constraint if exists news_posts_author_id_fkey;

alter table public.news_posts
  add constraint news_posts_author_id_fkey
  foreign key (author_id) references public.profiles(id) on delete set null;

-- Die Richtlinien bleiben unberührt: Das Einfügen verlangt weiterhin
-- author_id = auth.uid() und ist damit nie leer; gelöscht wird über die Rolle,
-- nicht über die Urheberschaft. Verwaiste Beiträge lassen sich also weiterhin
-- von der Vereinsleitung entfernen, aber von niemandem mehr bearbeiten.
