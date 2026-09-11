import { createClient } from "@supabase/supabase-js";
import { fetchMitZweitemVersuch } from "./zeitversatz";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

export const isSupabaseConfigured = Boolean(url && publishableKey);

/* "Anmeldung speichern" - und was daran technisch haengt.
 *
 * Die Anmeldung lag bisher immer im localStorage: Sie ueberlebt das Schliessen
 * der App und bleibt, bis sich jemand abmeldet. Fuer das eigene Telefon ist das
 * richtig, auf einem geteilten Geraet im Vereinsheim aber nicht - dort bleibt
 * sonst das Konto des Vorgaengers offen.
 *
 * Der Haken im Anmeldeformular entscheidet darueber. Er wirkt ueber den
 * SPEICHERORT, nicht ueber persistSession: Der ganze Client wird einmal beim
 * Laden gebaut, lange bevor jemand den Haken gesetzt hat - eine feste
 * Einstellung koennte die Wahl also gar nicht abbilden. Ein Speicher, der bei
 * jedem Zugriff nachsieht, kann es.
 *
 *   Haken gesetzt (Vorgabe)  -> localStorage,   ueberlebt das Schliessen
 *   Haken entfernt           -> sessionStorage, endet mit dem Fenster
 *
 * Gelesen wird notfalls aus beiden: Wer den Haken mitten in einer laufenden
 * Sitzung umstellt, soll nicht auf der Stelle herausfliegen.
 */
export const ANMELDUNG_MERKEN = "cmo.anmeldungMerken";

const merkenGewuenscht = () => {
  if (typeof window === "undefined") return true;
  try {
    /* Vorgabe ist JA. Wer nichts gewaehlt hat - und das sind alle, die die App
       schon benutzen -, behaelt damit genau das Verhalten von vorher. */
    return window.localStorage.getItem(ANMELDUNG_MERKEN) !== "nein";
  } catch {
    /* Privater Modus, Speicher gesperrt: dann eben ohne Erinnerung. */
    return true;
  }
};

const beideSpeicher = (): Storage[] => {
  if (typeof window === "undefined") return [];
  const liste: Storage[] = [];
  try { liste.push(window.localStorage); } catch { /* nicht verfuegbar */ }
  try { liste.push(window.sessionStorage); } catch { /* nicht verfuegbar */ }
  return liste;
};

const gewaehlterSpeicher = (): Storage | null => {
  if (typeof window === "undefined") return null;
  try {
    return merkenGewuenscht() ? window.localStorage : window.sessionStorage;
  } catch {
    return null;
  }
};

const anmeldungsSpeicher = {
  getItem: (schluessel: string) => {
    const bevorzugt = gewaehlterSpeicher();
    try {
      const wert = bevorzugt?.getItem(schluessel);
      if (wert != null) return wert;
    } catch { /* weiter unten nachsehen */ }
    /* Der andere Speicher als Rueckfall - siehe Kopf. */
    for (const s of beideSpeicher()) {
      try { const wert = s.getItem(schluessel); if (wert != null) return wert; } catch { /* naechster */ }
    }
    return null;
  },
  setItem: (schluessel: string, wert: string) => {
    const ziel = gewaehlterSpeicher();
    try { ziel?.setItem(schluessel, wert); } catch { /* Speicher gesperrt */ }
    /* Im jeweils anderen aufraeumen, sonst laege die Anmeldung doppelt und
       ueberlebte das Schliessen trotz entferntem Haken. */
    for (const s of beideSpeicher()) {
      if (s === ziel) continue;
      try { s.removeItem(schluessel); } catch { /* egal */ }
    }
  },
  removeItem: (schluessel: string) => {
    for (const s of beideSpeicher()) {
      try { s.removeItem(schluessel); } catch { /* egal */ }
    }
  },
};

export const supabase = isSupabaseConfigured
  ? createClient(url!, publishableKey!, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
        storage: typeof window === "undefined" ? undefined : anmeldungsSpeicher,
      },
      /* Zeitversatz bei Supabase: siehe lib/zeitversatz.ts. */
      global: { fetch: fetchMitZweitemVersuch },
    })
  : null;
