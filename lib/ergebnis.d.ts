/* Typen zu ergebnis.mjs - reines JavaScript, damit die Tests es direkt
   mit "node --test" laden koennen. */

import type { Mitglied } from "./mannschaften";

export type SpielOrt = "heim" | "auswaerts";
export type Tore = string | number;

/** Gespeicherte Form: home = UNSERE Tore, away = die des Gegners. Nie Heim/Gast. */
export interface WirGegner {
  home?: Tore | null;
  away?: Tore | null;
}

/** Angezeigte Form: links die Gastgeber, rechts die Gaeste. */
export interface HeimGast {
  heim?: Tore | null;
  gast?: Tore | null;
}

export interface OrtQuelle {
  ort?: string | null;
  home?: boolean | null;
  home_away?: string | null;
}

export interface Seite {
  schluessel: "home" | "away";
  name: string;
  rolle: "heim" | "gast" | "wir" | "gegner";
}

export interface ErgebnisTermin extends OrtQuelle {
  id?: string;
  type?: string;
  date?: string | null;
  team?: string | null;
  cancelled?: boolean;
  status?: string | null;
}

export interface ErgebnisNutzer extends Mitglied {
  roles?: readonly string[] | null;
}

export function spielOrt(x: OrtQuelle | null | undefined): SpielOrt | null;
export function zuHeimGast<W extends WirGegner>(wg: W | null | undefined, ort: SpielOrt | null | undefined): { heim: W["home"]; gast: W["away"] };
export function ausHeimGast<H extends HeimGast>(hg: H | null | undefined, ort: SpielOrt | null | undefined): { home: H["heim"]; away: H["gast"] };
export function feldSchluessel(ort: SpielOrt | null | undefined): { links: "home" | "away"; rechts: "home" | "away" };
export function seitenFuer(
  ort: SpielOrt | null | undefined,
  namen?: { wir?: string; gegner?: string },
): { links: Seite; rechts: Seite; ortBekannt: boolean };
export function stand(wg: WirGegner | null | undefined, ort: SpielOrt | null | undefined): string;
export function ausgang(wg: WirGegner | null | undefined): "sieg" | "remis" | "niederlage" | null;
export function tippPunkte(prediction: WirGegner | null | undefined, result: WirGegner | null | undefined): number;
export function toreGueltig(v: unknown): boolean;
export function ergebnisGueltig(wg: WirGegner | null | undefined): boolean;
export function darfErgebnisEintragen(
  user: ErgebnisNutzer | null | undefined,
  ev: ErgebnisTermin | null | undefined,
  optionen?: { jetzt?: Date; streng?: boolean },
): boolean;
export function ergebnisFehlerSchluessel(
  err: { code?: string | null; hint?: string | null } | null | undefined,
  ersatz?: string,
): string;
export function ergebnisseJeMannschaft<E extends ErgebnisTermin, R extends WirGegner>(
  events: readonly E[] | null | undefined,
  results: Record<string, R> | null | undefined,
  optionen?: { jetzt?: Date; favorit?: string | null },
): { team: string | null; spiele: { ev: E; ergebnis: R | null; wartet: boolean }[] }[];
