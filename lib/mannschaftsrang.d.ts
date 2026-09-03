/* Typen zu mannschaftsrang.mjs.
   Das Modul selbst ist bewusst reines JavaScript: So laesst es sich in
   tests/mannschaftsrang.test.mjs direkt mit "node --test" pruefen, ohne
   Uebersetzungsschritt. Diese Datei liefert TypeScript die Signaturen dazu. */

export const STUFE_ERWACHSEN: 0;
export const STUFE_ALTERSKLASSE: 1;
export const STUFE_JUGEND: 2;
export const STUFE_UNBEKANNT: 3;

export interface Mannschaftsrang {
  /** Kleinere Stufe heisst hoeherer Rang. */
  stufe: number;
  /** Innerhalb der Stufe: kleinere Zahl heisst hoeherer Rang. */
  ordnung: number;
  /** Der Name, wie er hereingegeben wurde. */
  name: string;
}

export function mannschaftsRang(rohname: unknown): Mannschaftsrang;
export function vergleicheMannschaften(a: unknown, b: unknown): number;
export function nachRangSortiert(namen: readonly (string | null | undefined)[] | null | undefined): string[];
export function hoechsteMannschaft(namen: readonly (string | null | undefined)[] | null | undefined): string;

export interface StandardMannschaftEingabe {
  /** Gespeicherter Filter der Person; "alle" zaehlt nicht als Mannschaft. */
  gespeichert?: string | null;
  /** Mannschaften, in denen die Person spielt. */
  spielt?: readonly (string | null | undefined)[] | null;
  /** Weitere Zuordnungen - Trainer, Teammanager, Kapitaen. */
  zugeordnet?: readonly (string | null | undefined)[] | null;
  /** Mannschaften, fuer die es ueberhaupt Termine gibt. */
  vorhanden?: readonly (string | null | undefined)[] | null;
}

export function standardMannschaft(eingabe?: StandardMannschaftEingabe): string;
export function auswahlReihenfolge(
  vorhanden: readonly (string | null | undefined)[] | null | undefined,
  eigene: readonly (string | null | undefined)[] | null | undefined,
): string[];
