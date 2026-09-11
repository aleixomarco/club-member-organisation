import { bild, js, schlaf, senden, ws } from "./schuss.mjs";

/* Breitbild: Die Konsole ist ein Arbeitsplatz am Rechner, kein Telefon. */
await senden("Emulation.setDeviceMetricsOverride", { width: 1360, height: 900, deviceScaleFactor: 2, mobile: false });

/* Beispieldaten. Die Konsole spricht sonst mit dem Dienstschlüssel, den es
   hier nicht gibt - und ein Handbuch mit lauter Nullen hilft niemandem.
   Die Zahlen sind erfunden, der Aufbau ist echt. */
const STUB = `
(() => {
  const K = {stand:new Date().toISOString(),zeitraum:{von:"2026-08-12",bis:"2026-09-10",tage:30},
    gesamt:{impressionen:4210,klicks:548},fenster:{impressionen:1668,klicks:213,oeffnungen:174,kontakte:39,tage_mit_kontakt:29},
    elemente:[{element:"anzeige",klicks:174},{element:"website",klicks:28},{element:"telefon",klicks:6},{element:"email",klicks:5}],
    vereine:[{verein:"TSV Beispielstadt",club_id:"a",impressionen:834,klicks:126},{verein:"SV Musterdorf",club_id:"b",impressionen:834,klicks:87}],
    reichweite:284,anzeige:{id:"a1",titel:"Sparkasse Märkischer Kreis",platz:"dashboard_top",herkunft:"betreiber",aktiv:true,laeuft_von:"2026-07-01",laeuft_bis:"2026-11-09",laeuft_gerade:true,ziel_url:"https://example.org",telefon:"02371 900",email:"werbung@example.org"},
    verlauf:[["08-12",60,12],["08-13",46,4],["08-14",78,10],["08-15",64,4],["08-16",50,6],["08-17",36,12],["08-18",68,5],["08-19",54,9],["08-20",40,5],["08-21",72,7],["08-22",58,10],["08-23",44,6],["08-24",76,9],["08-25",62,3],["08-26",48,9],["08-27",80,11],["08-28",66,4],["08-29",52,10],["08-30",38,4],["08-31",70,6],["09-01",56,12],["09-02",42,6],["09-03",74,8],["09-04",60,5],["09-05",46,7],["09-06",78,10],["09-07",64,6],["09-08",50,9],["09-09",36,4],["09-10",28,3]].map(p=>({tag:"2026-"+p[0],impressionen:p[1],klicks:p[2]}))};
  const D = {
    vereine:[
      {id:"a",name:"TSV Beispielstadt",short_name:"TSV",city:"Beispielstadt",sport:"handball",created_at:"2026-03-01T10:00:00Z",vereinbarte_zugaenge:150,sponsoring_freigeschaltet:true,tarif:"pro",grenze:150,konten:118,laeuft_bis:"2027-03-01T00:00:00Z",beleg:"RE-2026-004",referral_credit_months:0,mitglieder:184,offene_aufnahmen:2,eigene_sponsoren:3,ansprechpartner:"A. Berger <berger@example.org>",hidden:false,letzte_aktivitaet:new Date().toISOString(),aktive_30:96,termine_30:41,nachrichten_30:212},
      {id:"b",name:"SV Musterdorf",short_name:"SVM",city:"Musterdorf",sport:"fussball",created_at:"2026-06-14T10:00:00Z",vereinbarte_zugaenge:60,sponsoring_freigeschaltet:false,tarif:"plus",grenze:60,konten:57,laeuft_bis:"2027-06-14T00:00:00Z",beleg:"RE-2026-011",referral_credit_months:3,mitglieder:71,offene_aufnahmen:0,eigene_sponsoren:0,ansprechpartner:"M. Klein <klein@example.org>",hidden:false,letzte_aktivitaet:"2026-09-02T09:00:00Z",aktive_30:38,termine_30:12,nachrichten_30:48},
      {id:"c",name:"RSC Nordheim",short_name:"RSC",city:"Nordheim",sport:"rollhockey",created_at:"2026-08-20T10:00:00Z",vereinbarte_zugaenge:null,sponsoring_freigeschaltet:false,tarif:"none",grenze:3,konten:3,laeuft_bis:null,beleg:null,referral_credit_months:0,mitglieder:9,offene_aufnahmen:1,eigene_sponsoren:0,ansprechpartner:null,hidden:false,letzte_aktivitaet:null,aktive_30:0,termine_30:0,nachrichten_30:0}],
    anfragen:[{id:"r1",created_at:"2026-09-08T08:00:00Z",quelle:"website",verein:"RSC Nordheim",club_id:"c",contact_name:"L. Sommer",contact_email:"sommer@example.org",contact_phone:"02371 4455",expected_accounts:40,sponsoring_gewuenscht:true,note:"Wir starten zur neuen Saison.",status:"offen",konten_jetzt:3,tarif_jetzt:"none",sponsoren_jetzt:false,rechnungsnummer:null,betrag:null,zahlweise:null,rechnung_erstellt_am:null,rechnung_versendet_am:null,bezahlt_am:null,freigeschaltet_am:null,bestaetigung_versendet_am:null,ablehnungsgrund:null}],
    anzeigen:[
      {id:"a1",platz:"dashboard_top",titel:"Sparkasse Märkischer Kreis",text:"Ihre Bank vor Ort.",ziel_url:"https://example.org",telefon:"02371 900",email:"werbung@example.org",aktion_titel:null,aktion_bis:null,laeuft_bis:"2026-11-09T00:00:00Z",aktiv:true,impressionen:4210,klicks:548},
      {id:"a2",platz:"profile_bottom",titel:"Autohaus Weber",text:null,ziel_url:null,telefon:null,email:null,aktion_titel:"10 % auf Winterreifen",aktion_bis:"2026-10-01T00:00:00Z",laeuft_bis:"2026-10-01T00:00:00Z",aktiv:true,impressionen:1320,klicks:141}],
    sponsoren:[
      {id:"s1",platz:"dashboard_bottom",titel:"Bäckerei Schulte",aktiv:true,laeuft_bis:"2027-01-01T00:00:00Z",impressionen:890,klicks:77,club_id:"a",verein:"TSV Beispielstadt"},
      {id:"s2",platz:"events_header",titel:"Stadtwerke Nordheim",aktiv:true,laeuft_bis:null,impressionen:540,klicks:33,club_id:"a",verein:"TSV Beispielstadt"}],
    kennzahlen:{vereine:3,freigeschaltet:2,gesperrt:0,neu_30:1,konten:178,mitglieder:264,basic:0,plus:1,pro:1,ohne_tarif:1,still_30:1,fast_voll:1},
    kontenStand:{belegt:312,grenze:50000}};
  const echt = window.fetch.bind(window);
  window.fetch = async (e, o) => {
    const u = typeof e === "string" ? e : (e && e.url) || "";
    const ok = (i) => new Response(JSON.stringify(i), { status: 200, headers: { "Content-Type": "application/json" } });
    if (u.includes("/api/betreiber/anmelden")) return ok({ ok: true });
    if (u.includes("/api/betreiber/daten")) return ok(D);
    if (u.includes("/api/betreiber/kpi")) { const t = Number(new URL(u, location.origin).searchParams.get("tage")) || 30;
      return ok({ kennzahlen: { ...K, zeitraum: { ...K.zeitraum, tage: t }, verlauf: K.verlauf.slice(-t) } }); }
    return echt(e, o);
  };
})();
`;
await senden("Page.addScriptToEvaluateOnNewDocument", { source: STUB });
await senden("Page.navigate", { url: (process.env.APP_URL || "http://localhost:3100") + "/betreiber" });
await schlaf(3500);

/* Anmelden - der Stub beantwortet es. */
await js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const setzen = (el, v) => { const s = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set; s.call(el, v); el.dispatchEvent(new Event("input", { bubbles: true })); };
  const pw = document.querySelector("input[type=password]");
  if (pw) { setzen(pw, "x"); await w(200); [...document.querySelectorAll("button")].find(b => /Anmelden/.test(b.textContent))?.click(); await w(2500); }
  return true;
`);
await schlaf(1200);
await bild("13-betreiber-vereine");

const reiter = (t) => js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const b = [...document.querySelectorAll("button")].find(x => (x.textContent||"").trim() === ${JSON.stringify(t)});
  if (!b) return "nicht gefunden"; b.click(); await w(1600); return "ok";
`).then(r => { if (r !== "ok") console.log(`  ! ${t}: ${r}`); });

await reiter("Werbeanzeigen");
await bild("14-betreiber-anzeigen");
await reiter("KPI");
await js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const s = document.querySelector("select");
  if (s) { const set = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, "value").set;
    set.call(s, s.options[1].value); s.dispatchEvent(new Event("change", { bubbles: true })); await w(2200); }
  return true;
`);
await schlaf(1200);
await bild("15-betreiber-kpi");
ws.close();
console.log("fertig");
