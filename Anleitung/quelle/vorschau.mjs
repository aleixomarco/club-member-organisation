import { js, schlaf, senden, ws } from "./schuss.mjs";
import { writeFileSync } from "node:fs";

await senden("Emulation.setDeviceMetricsOverride", { width: 1123, height: 794, deviceScaleFactor: 1.6, mobile: false });
await senden("Page.navigate", { url: process.env.HTML_URL });
await schlaf(6000);
await js(`await document.fonts.ready; return true;`);

const wieViele = await js(`return document.querySelectorAll(".seite").length;`);
console.log("Seiten im Dokument:", wieViele);

for (const i of (process.env.SEITEN || "1,2,3,4,5").split(",").map(Number)) {
  const kasten = await js(`
    const s = document.querySelectorAll(".seite")[${i - 1}];
    if (!s) return null;
    s.scrollIntoView();
    await new Promise(r => setTimeout(r, 500));
    const r = s.getBoundingClientRect();
    return { x: Math.round(r.left + window.scrollX), y: Math.round(r.top + window.scrollY), w: Math.round(r.width), h: Math.round(r.height) };
  `);
  if (!kasten) { console.log(`  ! Seite ${i} fehlt`); continue; }
  const { data } = await senden("Page.captureScreenshot", {
    format: "png", captureBeyondViewport: true,
    clip: { x: kasten.x, y: kasten.y, width: kasten.w, height: kasten.h, scale: 1 },
  });
  writeFileSync(`${process.env.VORSCHAU}/seite-${String(i).padStart(2, "0")}.png`, Buffer.from(data, "base64"));
  console.log(`  ✓ seite-${i}`);
}
ws.close();
