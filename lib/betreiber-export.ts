import ExcelJS from "exceljs";

/* Die Mappe bauen - Aufbau, Formate, Beschriftungen.
 *
 * Getrennt von der Route, damit das Zusammenstellen der Daten (dort) und das
 * Aussehen der Tabelle (hier) sich nicht vermischen. Wer eine Spalte umbenennen
 * will, muss nicht durch Abfragen lesen.
 *
 * GRUNDSAETZE
 * - Ueberschriften auf Deutsch und ausgeschrieben. Ein Export, in dem
 *   "vereinbarte_zugaenge" steht, ist ein Datenbankauszug, keine Auswertung.
 * - Datum als echtes Datum, Zahl als echte Zahl, Geld mit zwei Stellen. Wer
 *   in Excel sortiert oder summiert, soll das Ergebnis nicht nachbessern
 *   muessen. Text-Zahlen sind der haeufigste Grund, warum ein Export
 *   unbrauchbar ist.
 * - Kopfzeile eingefroren und mit Filter. Bei tausend Mitgliedern ist das der
 *   Unterschied zwischen "arbeiten" und "scrollen".
 * - Spaltenbreite nach Inhalt, gedeckelt. Ohne Deckel zieht ein langer
 *   Beschreibungstext eine Spalte ueber den halben Bildschirm.
 */

export type Spalte = {
  titel: string;
  feld: string;
  breite?: number;
  art?: "text" | "zahl" | "geld" | "datum" | "zeitpunkt" | "ja_nein" | "liste";
};

export type Blatt = {
  name: string;
  spalten: Spalte[];
  zeilen: Record<string, unknown>[];
  hinweis?: string;
};

const KOPF_HINTERGRUND = "FF14151A";
const KOPF_SCHRIFT = "FFFFFFFF";
const STREIFEN = "FFF7F4F6";

/* Excel erlaubt keine 31 Zeichen ueberschreitenden Blattnamen und verbietet
   : \ / ? * [ ]. Ein Verstoss laesst die Datei gar nicht erst oeffnen. */
function blattname(roh: string): string {
  return roh.replace(/[:\\/?*[\]]/g, "-").slice(0, 31);
}

function wertFuer(art: Spalte["art"], roh: unknown): unknown {
  if (roh === null || roh === undefined) return null;
  switch (art) {
    case "zahl":
    case "geld": {
      if (typeof roh === "number") return Number.isFinite(roh) ? roh : null;
      const n = Number(roh);
      /* NaN waere in Excel eine Fehlerzelle (#NUM!) und liesse sich weder
         sortieren noch summieren. Lieber leer als kaputt. */
      return Number.isFinite(n) ? n : null;
    }
    case "datum":
    case "zeitpunkt": {
      const d = new Date(String(roh));
      return Number.isNaN(d.getTime()) ? String(roh) : d;
    }
    case "ja_nein":
      return roh === true ? "Ja" : roh === false ? "Nein" : String(roh);
    case "liste":
      /* Aus einem Feld wie rollen[] wird "Trainer/in, Mitglied" - eine Zelle,
         die man lesen kann, statt {trainer,mitglied}. */
      return Array.isArray(roh) ? roh.join(", ") : String(roh);
    default:
      return typeof roh === "object" ? JSON.stringify(roh) : roh;
  }
}

function zahlenformat(art: Spalte["art"]): string | undefined {
  switch (art) {
    case "geld": return '#,##0.00 "€"';
    case "zahl": return "#,##0";
    case "datum": return "DD.MM.YYYY";
    case "zeitpunkt": return "DD.MM.YYYY HH:mm";
    default: return undefined;
  }
}

export function mappeBauen(blaetter: Blatt[], erzeugtAm: Date): ExcelJS.Workbook {
  const mappe = new ExcelJS.Workbook();
  mappe.creator = "Club Member Organisation";
  mappe.created = erzeugtAm;

  for (const blatt of blaetter) {
    const bogen = mappe.addWorksheet(blattname(blatt.name), {
      views: [{ state: "frozen", ySplit: blatt.hinweis ? 2 : 1 }],
    });

    /* Ein Hinweis oben, wo einer noetig ist - etwa welcher Zeitraum gemeint
       ist. Er steht in Zeile 1, die Kopfzeile rutscht dann auf Zeile 2. */
    let kopfZeile = 1;
    if (blatt.hinweis) {
      bogen.getCell("A1").value = blatt.hinweis;
      bogen.getCell("A1").font = { italic: true, color: { argb: "FF6B6570" }, size: 10 };
      kopfZeile = 2;
    }

    const kopf = bogen.getRow(kopfZeile);
    blatt.spalten.forEach((spalte, i) => {
      const zelle = kopf.getCell(i + 1);
      zelle.value = spalte.titel;
      zelle.font = { bold: true, color: { argb: KOPF_SCHRIFT }, size: 11 };
      zelle.fill = { type: "pattern", pattern: "solid", fgColor: { argb: KOPF_HINTERGRUND } };
      zelle.alignment = { vertical: "middle", horizontal: "left" };
    });
    kopf.height = 22;

    blatt.zeilen.forEach((quelle, index) => {
      const zeile = bogen.getRow(kopfZeile + 1 + index);
      blatt.spalten.forEach((spalte, i) => {
        const zelle = zeile.getCell(i + 1);
        zelle.value = wertFuer(spalte.art, quelle[spalte.feld]) as ExcelJS.CellValue;
        const format = zahlenformat(spalte.art);
        if (format) zelle.numFmt = format;
        /* Jede zweite Zeile leicht hinterlegt - bei zwanzig Spalten verrutscht
           man sonst beim Lesen in die Nachbarzeile. */
        if (index % 2 === 1) {
          zelle.fill = { type: "pattern", pattern: "solid", fgColor: { argb: STREIFEN } };
        }
      });
    });

    blatt.spalten.forEach((spalte, i) => {
      const spaltenObjekt = bogen.getColumn(i + 1);
      if (spalte.breite) { spaltenObjekt.width = spalte.breite; return; }
      let breiteste = spalte.titel.length;
      for (const quelle of blatt.zeilen) {
        const wert = wertFuer(spalte.art, quelle[spalte.feld]);
        const laenge = wert instanceof Date ? 16 : String(wert ?? "").length;
        if (laenge > breiteste) breiteste = laenge;
      }
      spaltenObjekt.width = Math.min(Math.max(breiteste + 2, 10), 48);
    });

    if (blatt.zeilen.length > 0) {
      bogen.autoFilter = {
        from: { row: kopfZeile, column: 1 },
        to: { row: kopfZeile + blatt.zeilen.length, column: blatt.spalten.length },
      };
    }
  }

  return mappe;
}

/* Der Dateiname traegt den Zeitpunkt. Wer im Monat drei Exporte zieht, hat
   sonst dreimal "export.xlsx" im Ordner und weiss bei keinem, wie alt er ist. */
export function dateiname(erzeugtAm: Date): string {
  const zwei = (z: number) => String(z).padStart(2, "0");
  return `CMO-Vereinsdaten_${erzeugtAm.getFullYear()}-${zwei(erzeugtAm.getMonth() + 1)}-${zwei(erzeugtAm.getDate())}_${zwei(erzeugtAm.getHours())}${zwei(erzeugtAm.getMinutes())}.xlsx`;
}
