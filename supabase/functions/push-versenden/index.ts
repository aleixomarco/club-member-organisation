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

/* Ein Tausch, der gerade laeuft. Kommen mehrere Aufrufe gleichzeitig in
   dieselbe Instanz, klopft nur der erste bei Google an; die anderen warten
   auf dasselbe Ergebnis. Danach - gelungen oder nicht - wird er geleert. */
let tokenAnfrage: Promise<string> | null = null;

async function zugangstoken(konto: Dienstkonto): Promise<string> {
  const jetzt = Math.floor(Date.now() / 1000);
  /* 60 Sekunden Sicherheitsabstand: Ein Token, das waehrend des Sendens
     ablaeuft, faellt sonst mitten in einem Schwung Mitteilungen aus. */
  if (tokenZwischenspeicher && tokenZwischenspeicher.laeuftAbUm > jetzt + 60) {
    return tokenZwischenspeicher.token;
  }
  if (!tokenAnfrage) {
    tokenAnfrage = tokenEintauschen(konto, jetzt).finally(() => {
      tokenAnfrage = null;
    });
  }
  return tokenAnfrage;
}

async function tokenEintauschen(konto: Dienstkonto, jetzt: number): Promise<string> {
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

  /* 20 Sekunden Frist. Seit alle gleichzeitigen Aufrufe einer Instanz auf
     DENSELBEN Tausch warten, wuerde ein haengender Google-Aufruf sonst alle
     festhalten, bis die Instanz nach 150 s stirbt. Normal dauert er unter
     einer Sekunde; die Frist bleibt bewusst unter den 30 s, die der Ausloeser
     wartet, damit ein Ausfall als lesbarer Fehler in net._http_response
     landet statt als stummes timed_out. */
  const antwort = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
    signal: AbortSignal.timeout(20000),
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
/* Gehalten wird das Versprechen, nicht nur der Wert: Kommen mehrere Aufrufe
   gleichzeitig in dieselbe Instanz, holt nur der erste das Geheimnis, die
   anderen warten auf ihn. Scheitert der Abruf, wird der Speicher geleert,
   damit der naechste Aufruf es neu versucht. */
let geheimnisZwischenspeicher: Promise<string> | null = null;

function erwartetesGeheimnis(): Promise<string> {
  if (!geheimnisZwischenspeicher) {
    geheimnisZwischenspeicher = geheimnisHolen().catch((fehler) => {
      geheimnisZwischenspeicher = null;
      throw fehler;
    });
  }
  return geheimnisZwischenspeicher;
}

async function geheimnisHolen(): Promise<string> {
  const url = Deno.env.get("SUPABASE_URL");
  const schluessel = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !schluessel) throw new Error("Supabase-Zugang fehlt in der Umgebung.");
  /* Zweiter Versuch bei einem Fehlschlag.
     Der Ausloeser in der Datenbank ruft diese Funktion und wirft die Antwort
     weg - es gibt keine Wiedervorlage. Scheitert hier also der Griff nach dem
     Geheimnis, ist die Mitteilung ENDGUELTIG verloren: In der Glocke steht
     sie, auf dem Telefon kommt nie etwas an, und niemand erfaehrt davon.
     Genau das ist am 06.09. um 21:48:18 passiert - eine von zwei Mitteilungen
     kam mit "Nicht bereit" zurueck, die andere ging durch.
     Ein kalter Start plus ein Schluckauf bei der Datenbank reicht dafuer.
     Zwei Versuche mit einer kurzen Pause dazwischen fangen das ab; hilft auch
     der zweite nicht, liegt wirklich etwas im Argen.
     Jeder Versuch hat eine eigene Frist von 5 Sekunden. Ohne sie kehrte ein
     haengender erster Versuch nie zurueck, warf also auch keinen Fehler - und
     der zweite Versuch kam nie an die Reihe. */
  let antwort: Response | null = null;
  for (let versuch = 0; versuch < 2; versuch++) {
    if (versuch > 0) await new Promise((fertig) => setTimeout(fertig, 250));
    try {
      antwort = await fetch(`${url}/rest/v1/rpc/push_geheimnis`, {
        method: "POST",
        headers: {
          apikey: schluessel,
          Authorization: `Bearer ${schluessel}`,
          "Content-Type": "application/json",
        },
        body: "{}",
        signal: AbortSignal.timeout(5000),
      });
      if (antwort.ok) break;
    } catch (fehler) {
      console.error(`Geheimnis-Abruf Versuch ${versuch + 1} fehlgeschlagen`, fehler);
      antwort = null;
    }
  }
  if (!antwort || !antwort.ok) {
    throw new Error(`Geheimnis nicht lesbar: ${antwort ? `${antwort.status} ${await antwort.text()}` : "keine Antwort"}`);
  }
  const wert = await antwort.json();
  if (typeof wert !== "string" || wert.length < 32) throw new Error("Geheimnis fehlt oder ist zu kurz.");
  return wert;
}

/* Nur die Zahl fuer das App-Symbol - Aufruf aus push_zaehler_anstossen, nach
   jedem Lesen und Loeschen.

   Die Fassung 1.2 im App Store kann die Zahl nicht selbst zuruecksetzen (das
   Badge-Plugin kam erst danach). Ohne diesen Weg blieb nach dem Lesen die
   Zahl der letzten Mitteilung auf dem Symbol stehen.

   Die Mitteilung hat keinen Titel, keinen Text und keinen Ton; iOS setzt nur
   die Zahl. push-type "alert" verlangt Apple auch fuer reine Zahl-Mitteilungen,
   Prioritaet 5 heisst: ohne Eile, schont den Akku.
   Nur an iPhones - im Browser zeigte eine Mitteilung ohne Text den Hinweis
   "im Hintergrund aktualisiert". Tote Token raeumt der normale Versand auf. */
async function zahlNachziehen(profil: string) {
  if (!/^[0-9a-f-]{36}$/i.test(profil)) return { uebersprungen: "kein Profil im Aufruf" };
  const [wartend, mitgliedschaften] = await Promise.all([
    supabaseAbfrage(`user_notifications?select=id&profile_id=eq.${profil}&read_at=is.null&limit=99`),
    supabaseAbfrage(`club_memberships?select=id&profile_id=eq.${profil}&status=eq.active`),
  ]);
  const zahl = Array.isArray(wartend) ? wartend.length : 0;
  if (!mitgliedschaften.length) return { uebersprungen: "keine aktive Mitgliedschaft", zahl };
  const ids = mitgliedschaften.map((m: { id: string }) => m.id).join(",");
  const geraete: { fcm_token: string }[] = await supabaseAbfrage(
    `push_subscriptions?select=fcm_token&platform=eq.ios&membership_id=in.(${ids})`,
  );
  const token = [...new Set(geraete.map((g) => g.fcm_token))];
  if (!token.length) return { uebersprungen: "kein iPhone", zahl };

  const konto = dienstkontoLesen();
  const zugang = await zugangstoken(konto);
  let zugestellt = 0;
  const abgelehnt: string[] = [];
  for (const geraet of token) {
    const antwort = await fetch(
      `https://fcm.googleapis.com/v1/projects/${konto.project_id || FCM_PROJEKT}/messages:send`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${zugang}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: geraet,
            apns: {
              headers: { "apns-push-type": "alert", "apns-priority": "5" },
              payload: { aps: { badge: zahl } },
            },
          },
        }),
      },
    );
    if (antwort.ok) { zugestellt++; continue; }
    abgelehnt.push(`${antwort.status}: ${(await antwort.text()).slice(0, 200)}`);
  }
  return { zahl, zugestellt, geraete: token.length, ...(abgelehnt.length ? { abgelehnt } : {}) };
}

/* Wann diese Instanz geladen wurde, und ob sie schon einen Aufruf hatte. */
const instanzGeladen = Date.now();
let ersterAufruf = true;

Deno.serve(async (anfrage) => {
  /* Dauer und Kaltstart reisen in jeder Antwort mit. Sie landen in
     net._http_response - dem einzigen Ort, an dem wir den Versand von aussen
     sehen. Beim naechsten langsamen Schwung steht dort, ob es der kalte Start
     war oder etwas anderes.
     "kalt" heisst: erster Aufruf dieser Instanz. "instanz_ms" ist ihr Alter
     beim Eintreffen - daran erkennt man auch die Aufrufe, die im selben
     Moment kamen und auf den Start des ersten mitgewartet haben. */
  const beginn = Date.now();
  const kalt = ersterAufruf;
  ersterAufruf = false;
  const instanz_ms = beginn - instanzGeladen;
  const messung = () => ({ dauer_ms: Date.now() - beginn, kalt, instanz_ms });

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
    if (nutzlast?.type === "ZAEHLER") {
      return Response.json({ ...(await zahlNachziehen(String(nutzlast.profile_id ?? ""))), ...messung() });
    }
    const zeile = nutzlast?.record;
    if (!zeile?.profile_id) {
      return Response.json({ uebersprungen: "keine Zeile im Aufruf", ...messung() });
    }

    /* Was nicht von den Geraeten abhaengt, laeuft sofort los: der Tausch bei
       Google und die Zahl fuer das App-Symbol. Beides kam vorher je als eigene
       Runde NACH den beiden Abfragen; bei einem kalten Start summierte sich
       das. Das leere catch verhindert nur, dass ein frueher Rueckweg (keine
       Mitgliedschaft) eine unbehandelte Ablehnung hinterlaesst - ausgewertet
       wird der Fehler weiter unten, dort wo auf den Versuch gewartet wird. */
    const tokenVersuch = (async () => {
      const konto = dienstkontoLesen();
      return { konto, token: await zugangstoken(konto) };
    })();
    tokenVersuch.catch(() => {});
    const offenVersuch = (async () => {
      try {
        const wartend = await supabaseAbfrage(
          `user_notifications?select=id&profile_id=eq.${zeile.profile_id}&read_at=is.null&limit=99`,
        );
        if (Array.isArray(wartend) && wartend.length > 0) return wartend.length;
      } catch (fehler) {
        console.error("Zahl der offenen Meldungen nicht ermittelbar", fehler);
      }
      return 1;
    })();

    /* Vom Profil zu den Geraeten: user_notifications kennt das Profil,
       push_subscriptions haengt aber an der Mitgliedschaft. Der Umweg ist
       gewollt - so bekommt jemand, der in zwei Vereinen ist, die Mitteilung
       nur fuer den Verein, um den es geht. */
    const mitgliedschaften = await supabaseAbfrage(
      `club_memberships?select=id&profile_id=eq.${zeile.profile_id}` +
      (zeile.club_id ? `&club_id=eq.${zeile.club_id}` : "") +
      `&status=eq.active`,
    );
    if (!mitgliedschaften.length) return Response.json({ uebersprungen: "keine aktive Mitgliedschaft", ...messung() });

    const ids = mitgliedschaften.map((m: { id: string }) => m.id).join(",");
    const geraete = await supabaseAbfrage(
      `push_subscriptions?select=fcm_token&membership_id=in.(${ids})`,
    );
    if (!geraete.length) {
      /* Kein Geraet - also nichts zu senden. Trotzdem wird hier der Schluessel
         geprueft und das Ergebnis mitgeteilt.
         Grund: Solange die native Registrierung nicht ausgeliefert ist, meldet
         sich kein iPhone an, und der Versand wird nie erreicht. Ohne diesen
         Zweig bliebe bis dahin unbekannt, ob das Firebase-Dienstkonto
         ueberhaupt taugt - und der Fehler faende sich erst, wenn die ersten
         echten Mitteilungen ausbleiben. So steht die Antwort schon jetzt in der
         Rueckgabe, ohne dass jemand etwas verschicken muss.
         Der Zweig laeuft fuer JEDEN Empfaenger ohne Geraet, nicht nur bis zur
         Auslieferung - der Tausch ist ohnehin schon unterwegs (tokenVersuch). */
      let schluessel: string;
      try {
        const { konto } = await tokenVersuch;
        schluessel = `in Ordnung (Projekt ${konto.project_id}, Konto ${konto.client_email})`;
      } catch (fehler) {
        schluessel = `UNBRAUCHBAR: ${String(fehler)}`;
      }
      return Response.json({ uebersprungen: "kein angemeldetes Geraet", schluessel, ...messung() });
    }

    const { konto, token } = await tokenVersuch;

    /* Die Zahl auf dem App-Symbol.
     *
     * Hier stand bisher fest badge: 1 - bei JEDER Mitteilung. Und weil nichts
     * in der App den Zaehler je zurueckgesetzt hat, trug jeder, der einmal
     * eine Push-Nachricht bekommen hatte, seitdem dauerhaft eine 1 auf dem
     * Symbol. Egal ob null oder zwanzig Meldungen offen waren, egal ob
     * laengst gelesen. Das ist schlechter als kein Zaehler: Man lernt, ihn zu
     * ignorieren.
     *
     * Gezaehlt wird ueber ALLE Vereine dieser Person, nicht nur ueber den,
     * aus dem die Mitteilung kommt. Das Symbol gibt es auf dem Geraet nur
     * einmal; es beantwortet die Frage "wie viel wartet auf mich", nicht "wie
     * viel wartet in diesem einen Verein".
     *
     * Die gerade eingefuegte Zeile zaehlt mit - sie ist ja das, was wartet.
     *
     * Bei 99 wird abgeschnitten: Mehr sagt kein Symbol aus, und die Abfrage
     * bleibt klein. Faellt sie aus, bleibt es bei der alten 1 - lieber eine
     * ungenaue Zahl als gar keine Mitteilung. */
    const offen = await offenVersuch;

    let zugestellt = 0;
    const totgeglaubt: string[] = [];
    /* Die Ablehnungsgruende reisen in der Antwort mit.
       Sie standen bisher nur in console.error - und an das Protokoll einer
       Edge Function kommt man von aussen nicht heran. Die Antwort dagegen
       landet in net._http_response und ist damit aus der Datenbank lesbar.
       Ohne das steht da nur "zugestellt: 0" und man raet, warum. */
    const abgelehnt: string[] = [];

    /* Ein Geraet steht einmal JE VEREIN in push_subscriptions. Fuer eine
       Kontomeldung ohne Verein (club_id null, etwa "Neues Geraet angemeldet")
       kaemen sonst so viele Pushes an, wie das Geraet Vereine hat. */
    const eindeutig = [...new Map((geraete as { fcm_token: string }[]).map((g) => [g.fcm_token, g])).values()];

    for (const geraet of eindeutig) {
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
                 richtige Stelle springen kann, statt nur zu oeffnen.
                 Dazu das Ziel selbst (ziel_art, ziel_id): Mit ihm springt die
                 App sofort, ohne die Zeile erst nachzuladen - auch dann, wenn
                 sie gerade erst startet und noch niemand angemeldet ist.
                 FCM nimmt in data nur Zeichenketten; ein fehlendes Ziel ist
                 deshalb "", nicht null. */
              data: {
                kind: String(zeile.kind ?? ""),
                club_id: String(zeile.club_id ?? ""),
                notification_id: String(zeile.id ?? ""),
                ziel_art: String(zeile.ziel_art ?? ""),
                ziel_id: String(zeile.ziel_id ?? ""),
              },
              apns: { payload: { aps: { sound: "default", badge: offen } } },
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
      abgelehnt.push(`${antwort.status}: ${fehlertext.slice(0, 200)}`);
    }

    for (const tot of totgeglaubt) {
      await supabaseAbfrage(`push_subscriptions?fcm_token=eq.${encodeURIComponent(tot)}`, "DELETE")
        .catch((e) => console.error("Aufraeumen fehlgeschlagen", e));
    }

    return Response.json({ zugestellt, aufgeraeumt: totgeglaubt.length, geraete: eindeutig.length, ...(abgelehnt.length ? { abgelehnt } : {}), ...messung() });
  } catch (fehler) {
    console.error("Versand fehlgeschlagen", fehler);
    return Response.json({ fehler: String(fehler), ...messung() }, { status: 500 });
  }
});
