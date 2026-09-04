/// <reference lib="deno.ns" />
/* Der Versender: macht aus einer Zeile in user_notifications eine echte
 * Mitteilung auf dem Telefon.
 *
 * WARUM ES IHN BRAUCHT
 * Die App sammelte seit jeher FCM-Token in push_subscriptions und konnte
 * Mitteilungen empfangen - aber im ganzen Projekt gab es kein Stueck Code, das
 * jemals etwas an Firebase geschickt haette. Keine Edge Function, kein
 * firebase-admin, kein Webhook. Die Token lagen ungenutzt herum, und die
 * Glocke in der App war die einzige Stelle, an der ueberhaupt etwas ankam.
 *
 * WIE ER GERUFEN WIRD
 * Als Datenbank-Webhook auf INSERT in public.user_notifications. Supabase
 * schickt dabei { type, table, record } als JSON. Ein Aufruf, eine Zeile.
 *
 * WARUM KEINE EIGENE EMPFAENGERLOGIK
 * Wer eine Zeile bekommt, hat sie verdient: Die Auswahl der Empfaenger und die
 * Beachtung der Einstellungen (notification_master, notification_preferences)
 * passieren bereits beim Schreiben, in den Triggern und in public.notify.
 * Hier noch einmal zu filtern hiesse, dieselbe Regel an zwei Stellen zu
 * pflegen - und irgendwann laufen sie auseinander.
 */

const FCM_PROJEKT = "club-member-organisation-acbf3";

type Dienstkonto = {
  client_email: string;
  private_key: string;
  project_id: string;
};

/* ---------------------------------------------------------------------------
   Zugangstoken fuer FCM.

   Die HTTP-v1-Schnittstelle von Firebase will ein OAuth2-Zugangstoken, kein
   API-Schluessel. Man bekommt es, indem man ein JWT mit dem privaten Schluessel
   des Dienstkontos signiert und bei Google gegen ein Token eintauscht.

   Das Token gilt eine Stunde. Es wird im Modulzustand gehalten, damit nicht
   jede einzelne Mitteilung einen zusaetzlichen Google-Aufruf ausloest - bei
   einer News an 40 Mitglieder waeren das 40 unnoetige Runden.
--------------------------------------------------------------------------- */
let tokenZwischenspeicher: { token: string; laeuftAbUm: number } | null = null;

function pemZuBytes(pem: string): ArrayBuffer {
  const roh = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binaer = atob(roh);
  const bytes = new Uint8Array(binaer.length);
  for (let i = 0; i < binaer.length; i++) bytes[i] = binaer.charCodeAt(i);
  return bytes.buffer;
}

function base64Url(daten: Uint8Array | string): string {
  const s = typeof daten === "string" ? daten : String.fromCharCode(...daten);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function zugangstoken(konto: Dienstkonto): Promise<string> {
  const jetzt = Math.floor(Date.now() / 1000);
  /* 60 Sekunden Sicherheitsabstand: Ein Token, das waehrend des Sendens
     ablaeuft, faellt sonst mitten in einem Schwung Mitteilungen aus. */
  if (tokenZwischenspeicher && tokenZwischenspeicher.laeuftAbUm > jetzt + 60) {
    return tokenZwischenspeicher.token;
  }

  const kopf = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const rumpf = base64Url(JSON.stringify({
    iss: konto.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: jetzt,
    exp: jetzt + 3600,
  }));

  const schluessel = await crypto.subtle.importKey(
    "pkcs8",
    pemZuBytes(konto.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signatur = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    schluessel,
    new TextEncoder().encode(`${kopf}.${rumpf}`),
  ));
  const jwt = `${kopf}.${rumpf}.${base64Url(signatur)}`;

  const antwort = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!antwort.ok) {
    throw new Error(`Zugangstoken abgelehnt (${antwort.status}): ${await antwort.text()}`);
  }
  const daten = await antwort.json();
  tokenZwischenspeicher = { token: daten.access_token, laeuftAbUm: jetzt + (daten.expires_in ?? 3600) };
  return daten.access_token;
}

/* ------------------------------------------------------------------------ */

function dienstkontoLesen(): Dienstkonto {
  /* Zwei moegliche Ablagen, in dieser Reihenfolge:
     FCM_DIENSTKONTO ist die neue, bewusst aus dem richtigen Firebase-Projekt
     erzeugte. FIREBASE_SERVICE_ACCOUNT liegt seit dem 05.08.2026 im Projekt und
     stammt aus einer frueheren Einrichtung - zu welchem der beiden
     gleichnamigen Firebase-Projekte, ist von aussen nicht feststellbar.
     Der Rueckfall ist trotzdem richtig: Passt der alte Schluessel, laeuft Push
     sofort und der Betreiber spart sich einen Schritt. Passt er nicht, meldet
     Google beim Eintausch einen Fehler, und der landet lesbar im Protokoll -
     das ist eine ehrliche Fehlermeldung statt stiller Untaetigkeit.
     Ein leer gesetztes Geheimnis zaehlt dabei als nicht gesetzt: "supabase
     secrets set" speichert eine leere Zeichenkette klaglos, wenn der
     Dateipfad im Befehl nicht stimmte. Genau das ist hier passiert. */
  const roh = Deno.env.get("FCM_DIENSTKONTO")?.trim() ||
              Deno.env.get("FIREBASE_SERVICE_ACCOUNT")?.trim();
  if (!roh) throw new Error("Weder FCM_DIENSTKONTO noch FIREBASE_SERVICE_ACCOUNT ist gesetzt (oder beide sind leer).");
  /* Base64 oder blankes JSON - beides wird angenommen. Base64 ist der Weg ueber
     "supabase secrets set", weil ein mehrzeiliger privater Schluessel sonst an
     den Zeilenumbruechen zerbricht. */
  const text = roh.trim().startsWith("{") ? roh : new TextDecoder().decode(
    Uint8Array.from(atob(roh.replace(/\s+/g, "")), (c) => c.charCodeAt(0)),
  );
  const konto = JSON.parse(text) as Dienstkonto;
  if (!konto.private_key || !konto.client_email) {
    throw new Error("FCM_DIENSTKONTO enthaelt kein vollstaendiges Dienstkonto.");
  }
  return konto;
}

async function supabaseAbfrage(pfad: string, methode = "GET", rumpf?: unknown) {
  const url = Deno.env.get("SUPABASE_URL");
  const schluessel = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !schluessel) throw new Error("Supabase-Zugang fehlt in der Umgebung.");
  const antwort = await fetch(`${url}/rest/v1/${pfad}`, {
    method: methode,
    headers: {
      apikey: schluessel,
      Authorization: `Bearer ${schluessel}`,
      "Content-Type": "application/json",
    },
    body: rumpf ? JSON.stringify(rumpf) : undefined,
  });
  if (!antwort.ok) throw new Error(`Supabase ${methode} ${pfad}: ${antwort.status} ${await antwort.text()}`);
  return methode === "DELETE" ? null : await antwort.json();
}

/* Das vereinbarte Geheimnis.

   Es liegt in intern.push_zustellung und wurde dort von der Datenbank selbst
   erzeugt (32 Zufallsbytes). Weder diese Datei noch eine Umgebungsvariable
   noch ein Protokoll kennt es - der Versender holt es sich einmal ab und
   behaelt es, solange die Instanz laeuft.

   Warum nicht der Dienstschluessel als Nachweis? Der Ausloeser sitzt IN der
   Datenbank; ihm den Dienstschluessel mitzugeben hiesse, ihn irgendwo zu
   hinterlegen - in einer Migration, also im Git. Das Geheimnis dagegen
   entsteht in der Datenbank und verlaesst sie nur auf diesem einen Weg. */
let geheimnisZwischenspeicher: string | null = null;

async function erwartetesGeheimnis(): Promise<string> {
  if (geheimnisZwischenspeicher) return geheimnisZwischenspeicher;
  const url = Deno.env.get("SUPABASE_URL");
  const schluessel = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !schluessel) throw new Error("Supabase-Zugang fehlt in der Umgebung.");
  const antwort = await fetch(`${url}/rest/v1/rpc/push_geheimnis`, {
    method: "POST",
    headers: {
      apikey: schluessel,
      Authorization: `Bearer ${schluessel}`,
      "Content-Type": "application/json",
    },
    body: "{}",
  });
  if (!antwort.ok) throw new Error(`Geheimnis nicht lesbar: ${antwort.status} ${await antwort.text()}`);
  const wert = await antwort.json();
  if (typeof wert !== "string" || wert.length < 32) throw new Error("Geheimnis fehlt oder ist zu kurz.");
  geheimnisZwischenspeicher = wert;
  return wert;
}

Deno.serve(async (anfrage) => {
  /* Die Funktion laeuft OHNE JWT-Pruefung, damit der Ausloeser in der Datenbank
     sie ohne Nutzer-Sitzung erreicht. Dieser Vergleich ist deshalb das einzige
     Tor: Ohne das Geheimnis passiert nichts. Sonst koennte jeder, der die
     Adresse kennt, beliebige Mitteilungen an alle Geraete des Vereins
     ausloesen. */
  let erwartet: string;
  try {
    erwartet = await erwartetesGeheimnis();
  } catch (fehler) {
    console.error("Geheimnis nicht verfuegbar", fehler);
    return new Response("Nicht bereit", { status: 503 });
  }
  const mitgeschickt = anfrage.headers.get("x-cmo-signatur") ?? "";
  if (mitgeschickt.length !== erwartet.length || mitgeschickt !== erwartet) {
    return new Response("Nicht berechtigt", { status: 401 });
  }

  try {
    const nutzlast = await anfrage.json();
    const zeile = nutzlast?.record;
    if (!zeile?.profile_id) {
      return Response.json({ uebersprungen: "keine Zeile im Aufruf" });
    }

    /* Vom Profil zu den Geraeten: user_notifications kennt das Profil,
       push_subscriptions haengt aber an der Mitgliedschaft. Der Umweg ist
       gewollt - so bekommt jemand, der in zwei Vereinen ist, die Mitteilung
       nur fuer den Verein, um den es geht. */
    const mitgliedschaften = await supabaseAbfrage(
      `club_memberships?select=id&profile_id=eq.${zeile.profile_id}` +
      (zeile.club_id ? `&club_id=eq.${zeile.club_id}` : "") +
      `&status=eq.active`,
    );
    if (!mitgliedschaften.length) return Response.json({ uebersprungen: "keine aktive Mitgliedschaft" });

    const ids = mitgliedschaften.map((m: { id: string }) => m.id).join(",");
    const geraete = await supabaseAbfrage(
      `push_subscriptions?select=fcm_token&membership_id=in.(${ids})`,
    );
    if (!geraete.length) return Response.json({ uebersprungen: "kein angemeldetes Geraet" });

    const konto = dienstkontoLesen();
    const token = await zugangstoken(konto);

    let zugestellt = 0;
    const totgeglaubt: string[] = [];

    for (const geraet of geraete as { fcm_token: string }[]) {
      const antwort = await fetch(
        `https://fcm.googleapis.com/v1/projects/${konto.project_id || FCM_PROJEKT}/messages:send`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            message: {
              token: geraet.fcm_token,
              notification: { title: zeile.title, body: zeile.body ?? "" },
              /* Die Kennung reist mit, damit die App spaeter direkt an die
                 richtige Stelle springen kann, statt nur zu oeffnen. */
              data: {
                kind: String(zeile.kind ?? ""),
                club_id: String(zeile.club_id ?? ""),
                notification_id: String(zeile.id ?? ""),
              },
              apns: { payload: { aps: { sound: "default", badge: 1 } } },
            },
          }),
        },
      );

      if (antwort.ok) { zugestellt++; continue; }

      /* 404 UNREGISTERED und 400 INVALID_ARGUMENT heissen: Dieses Geraet gibt
         es nicht mehr - App geloescht, Token abgelaufen. Solche Token bleiben
         sonst ewig stehen und kosten bei jeder Mitteilung einen vergeblichen
         Aufruf. */
      const fehlertext = await antwort.text();
      if (antwort.status === 404 || (antwort.status === 400 && fehlertext.includes("INVALID_ARGUMENT"))) {
        totgeglaubt.push(geraet.fcm_token);
      } else {
        console.error("FCM abgelehnt", antwort.status, fehlertext);
      }
    }

    for (const tot of totgeglaubt) {
      await supabaseAbfrage(`push_subscriptions?fcm_token=eq.${encodeURIComponent(tot)}`, "DELETE")
        .catch((e) => console.error("Aufraeumen fehlgeschlagen", e));
    }

    return Response.json({ zugestellt, aufgeraeumt: totgeglaubt.length, geraete: geraete.length });
  } catch (fehler) {
    console.error("Versand fehlgeschlagen", fehler);
    return Response.json({ fehler: String(fehler) }, { status: 500 });
  }
});
