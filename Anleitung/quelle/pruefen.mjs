import { js, schlaf, senden, ws } from "./schuss.mjs";
await senden("Emulation.setDeviceMetricsOverride", { width: 1123, height: 794, deviceScaleFactor: 1, mobile: false });
await senden("Page.navigate", { url: process.env.HTML_URL });
await schlaf(7000);
await js(`await document.fonts.ready; return true;`);
const bericht = await js(`
  const raus = [];
  document.querySelectorAll(".seite").forEach((s, i) => {
    const sr = s.getBoundingClientRect();
    let tiefster = 0, breitester = 0, wer = "";
    s.querySelectorAll("*").forEach(el => {
      const r = el.getBoundingClientRect();
      if (r.height === 0) return;
      const unten = r.bottom - sr.top, rechts = r.right - sr.left;
      if (unten > tiefster) { tiefster = unten; wer = el.className || el.tagName; }
      if (rechts > breitester) breitester = rechts;
    });
    const h = sr.height, b = sr.width;
    if (tiefster > h - 2 || breitester > b - 2) {
      raus.push({ seite: i + 1, ueber_unten: Math.round(tiefster - h), ueber_rechts: Math.round(breitester - b), wer: String(wer).slice(0, 40) });
    }
  });
  return raus;
`);
console.log(bericht.length === 0 ? "Keine Seite laeuft ueber." : JSON.stringify(bericht, null, 1));
ws.close();
