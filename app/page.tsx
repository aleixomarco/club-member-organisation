"use client";
import React, { useState, useEffect, useRef, useCallback } from "react";
import Script from "next/script";
import {
  Home, CalendarDays, Wallet, MessageCircle, User, ChevronRight, Trash2,
  Check, X, Users, Award, Gift, MapPin, Clock, Send,
  Trophy, Flame, Cake, Megaphone, Euro, CheckCircle2, Circle, Car,
  Sparkles, Image as ImageIcon, ChevronDown, Star, Mail, Lock, LogOut,
  ShieldCheck, ArrowRight, ArrowLeft, AlertCircle, UserPlus, Eye, EyeOff,
  Target, ClipboardList, Newspaper, Bell, KeyRound, Settings, RefreshCw,
  Bug, Smartphone, Save, Plus, Building2, ExternalLink, Phone, Copy, PlayCircle, ChevronUp
, ListFilter,
} from "lucide-react";
import { isSupabaseConfigured, supabase } from "@/lib/supabase";
import { enablePushNotifications, disablePushNotifications, listenForForegroundMessages } from "@/lib/firebase-push";
import { Capacitor } from "@capacitor/core";
import { legal } from "./legal-shell";
/* Preise werden in der App nicht mehr angezeigt - siehe SubscriptionPanel.
   Geblieben sind die Bezeichnungen der Stufen, die weiterhin gebraucht werden,
   um einen laufenden Tarif zu benennen. */
import { CLUB_TIER_INFO } from "@/lib/preise";
import { standardMannschaft, auswahlReihenfolge, hoechsteMannschaft, nachRangSortiert } from "@/lib/mannschaftsrang";
import { memberPlayerTeams, memberTrainerTeams, memberCaptainTeams, memberManagedTeams, memberAllTeams, memberInTeam, hoechstesTeam } from "@/lib/mannschaften";

/* ------------------------------------------------------------------ */
/* Tokens                                                              */
/* ------------------------------------------------------------------ */
/* Design: Glas-Optik (Apple-Stil). Flächen sind durchscheinend und liegen über einer
   farbigen Verlaufs-Wäsche im Hintergrund (siehe .erg-canvas); die Unschärfe dahinter
   kommt zentral über CSS (siehe FONTS), damit sie nicht an jeder der ~350 Flächen
   einzeln gesetzt werden muss. `glass` = Kartenfläche, `glassDim` = eingelassene
   Fläche (Eingabefelder, sekundäre Buttons, Chips). */
/* Die Farben der App.
 *
 * Grundsatz seit dem 04.09.2026: In der Vereins-App kommen NUR die beiden
 * Farben vor, die der Verein selbst eingestellt hat, dazu neutrale Toene.
 * Ein Verein mit Schwarz und Gelb soll Schwarz und Gelb sehen - kein Amber,
 * kein Petrol, kein Violett.
 *
 * Genau zwei Ausnahmen, und sie sind es aus einem Grund: Rot fuer Fehler und
 * Gruen fuer Erfolg sind keine Gestaltung, sondern Bedeutung. Wer eine
 * Fehlermeldung in Vereinsgelb faerbt, nimmt ihr das, was sie ausmacht.
 *
 * Vorher war das anders herum falsch: C.red IST die Vereinsfarbe, und
 * Fehlermeldungen benutzten sie. Ein Verein mit gelber Primaerfarbe bekam
 * gelbe Fehlermeldungen - und ein Verein mit gruener bekam Fehlermeldungen in
 * derselben Farbe wie seine Erfolgsmeldungen. */
const C = {
  /* --- Die beiden Vereinsfarben --- */
  red: "var(--club-primary)",              // historischer Name, ist die Primaerfarbe
  redDark: "var(--club-primary-dark)",
  secondary: "var(--club-secondary)",
  /* Weiche Flaechen aus den Vereinsfarben.
     Ausgerechnet wird in JavaScript (mischeHex) und als eigene CSS-Variable
     gesetzt - nicht mit color-mix. Das gibt es erst ab iOS 16.2, die App
     unterstuetzt aber iOS 15; dort waeren die Regeln ungueltig und die Flaechen
     schlicht farblos. */
  primaerWeich: "var(--club-primary-soft)",
  primaerRand: "var(--club-primary-border)",
  sekundaerWeich: "var(--club-secondary-soft)",
  sekundaerRand: "var(--club-secondary-border)",
  /* Auf dunklen Flaechen muss ein Akzent hell genug sein. Ist die
     Sekundaerfarbe selbst dunkel (Schwarz etwa), waere sie dort unsichtbar. */
  aufDunkel: "var(--club-secondary-light)",

  /* --- Neutral --- */
  ink: "#2A2028",
  asphalt: "#3B2F38",
  paper: "transparent",
  paperDim: "rgba(92,72,86,0.07)",
  white: "#FFFFFF",
  glass: "rgba(255,255,255,0.55)",
  glassDim: "rgba(92,72,86,0.07)",
  line: "rgba(70,50,65,0.12)",
  edge: "rgba(255,255,255,0.65)",
  textDim: "#8A7F85",

  /* --- Nur fuer Zustandsmeldungen, nie fuer Gestaltung --- */
  fehler: "#C0392B",
  fehlerFlaeche: "rgba(253,236,236,0.85)",
  fehlerRand: "#F0C0BB",
  erfolg: "#1E7A45",
  erfolgFlaeche: "rgba(231,243,236,0.85)",
  erfolgRand: "#BEDFC9",
};

/* Vereinsfarben: Primär (ersetzt C.red/redDark überall) + Sekundär (für
   Logo-Kachel, Trainings-/Spielkarten-Akzent, Bottom-Nav). Über CSS-Custom-
   Properties injiziert (siehe globals.css für die Default-Werte und den
   Wrapper in ClubMemberOrganisationApp fürs Überschreiben pro Verein) —
   dadurch muss keiner der hunderten C.red-Aufrufe im Code angefasst werden. */
const DEFAULT_CLUB_COLORS = { primary: "#C8102E", secondary: "#14151A" };
const CLUB_COLOR_PRESETS = [
  { label: "Rot & Schwarz", primary: "#C8102E", secondary: "#14151A" },
  { label: "Schwarz & Gelb", primary: "#14151A", secondary: "#F2B134" },
  { label: "Blau & Weiß", primary: "#1E5FA8", secondary: "#FFFFFF" },
  { label: "Rot & Weiß", primary: "#C8102E", secondary: "#FFFFFF" },
  { label: "Grün & Weiß", primary: "#1F7A5C", secondary: "#FFFFFF" },
  { label: "Dunkelblau & Rot", primary: "#1B2A6B", secondary: "#C8102E" },
  { label: "Orange & Schwarz", primary: "#D66B1F", secondary: "#14151A" },
  { label: "Violett & Weiß", primary: "#6F5B9A", secondary: "#FFFFFF" },
];
/* Eine Vereinsfarbe mit Weiss oder Schwarz mischen.
 *
 * Bewusst hier und nicht per color-mix in CSS: Das gibt es erst ab iOS 16.2,
 * und die App laeuft ab iOS 15. Dort waere jede solche Regel ungueltig - die
 * Flaeche bliebe farblos, und zwar ohne jede Fehlermeldung. */
function mischeHex(hex, anteil, mitWeiss = true) {
  const clean = String(hex || "").replace("#", "");
  if (!/^[0-9a-fA-F]{6}$/.test(clean)) return hex;
  const num = parseInt(clean, 16);
  const ziel = mitWeiss ? 255 : 0;
  const chan = (shift) => {
    const v = (num >> shift) & 255;
    return Math.max(0, Math.min(255, Math.round(v * anteil + ziel * (1 - anteil))));
  };
  return `#${[chan(16), chan(8), chan(0)].map((v) => v.toString(16).padStart(2, "0")).join("")}`;
}

/* Dieselbe Farbe mit Deckkraft - fuer die Hintergrundwaesche. */
function hexMitDeckkraft(hex, deckkraft) {
  const clean = String(hex || "").replace("#", "");
  if (!/^[0-9a-fA-F]{6}$/.test(clean)) return hex;
  const num = parseInt(clean, 16);
  return `rgba(${(num >> 16) & 255}, ${(num >> 8) & 255}, ${num & 255}, ${deckkraft})`;
}

function darkenHex(hex, amount = 0.32) {
  const clean = String(hex || "").replace("#", "");
  if (!/^[0-9a-fA-F]{6}$/.test(clean)) return hex;
  const num = parseInt(clean, 16);
  const chan = (shift) => Math.max(0, Math.round(((num >> shift) & 255) * (1 - amount)));
  return `#${[chan(16), chan(8), chan(0)].map((v) => v.toString(16).padStart(2, "0")).join("")}`;
}
function hexIsLight(hex) {
  const clean = String(hex || "").replace("#", "");
  if (!/^[0-9a-fA-F]{6}$/.test(clean)) return false;
  const num = parseInt(clean, 16);
  const r = (num >> 16) & 255, g = (num >> 8) & 255, b = num & 255;
  return (0.299 * r + 0.587 * g + 0.114 * b) > 175;
}

const FONTS = `
@import url('https://fonts.googleapis.com/css2?family=Oswald:wght@500;600;700&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500;700&display=swap');
* { -webkit-tap-highlight-color: transparent; }
html { scroll-behavior: smooth; }
button { transition: transform .16s cubic-bezier(.34,1.56,.64,1), opacity .12s ease, background-color .15s ease, box-shadow .18s ease; }
button:active { transform: scale(0.96); }
.tabFade { animation: tabFadeIn .22s ease; }
@keyframes tabFadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }
.erg-app ::-webkit-scrollbar { width: 0px; height: 0px; }

/* --- Glas-Optik (Apple-Stil) ---------------------------------------------
   Die Unschärfe hinter den durchscheinenden Flächen wird hier zentral gesetzt,
   statt an jeder der ~350 Flächen einzeln. Auf undurchsichtigen Flächen (Buttons
   in Vereinsfarbe, Avatare) hat backdrop-filter keinen sichtbaren Effekt, daher
   ist die pauschale Regel unkritisch. */
/* Die Wäsche nimmt oben die Vereins-Primärfarbe auf; die beiden anderen Punkte sind
   bewusst feste Töne — die Sekundärfarbe ist oft Schwarz oder Weiß und ergäbe hier
   nur einen grauen Fleck statt eines Farbverlaufs. */
.erg-canvas {
  background:
    radial-gradient(70% 50% at 85% -5%, var(--club-primary-wash), transparent 62%),
    radial-gradient(65% 45% at -10% 12%, var(--club-primary-wash), transparent 62%),
    radial-gradient(70% 45% at 50% 104%, var(--club-secondary-wash), transparent 62%),
    linear-gradient(180deg, #F7F4F5 0%, #EDEAF0 100%);
}
.erg-app .rounded-lg, .erg-app .rounded-xl, .erg-app .rounded-2xl, .erg-app .rounded-3xl {
  backdrop-filter: blur(22px) saturate(180%);
  -webkit-backdrop-filter: blur(22px) saturate(180%);
}

/* Darstellungsrahmen: Am Rechner zeigen wir die App in einer Handy-Attrappe, damit
   man das Format erkennt. Auf einem echten Telefon — und damit auch in der nativen
   App-Hülle — muss sie dagegen bildschirmfüllend laufen, sonst steckt ein Handy im
   Handy und der Inhalt wird rechts abgeschnitten. */
.erg-shell { min-height: 100vh; min-height: 100dvh; padding: 16px; background: #D9D9DF; }
.erg-frame { max-width: 400px; height: 820px; border-radius: 44px; box-shadow: 0 30px 70px rgba(60,30,45,0.28); }

/* Milchige Unterseite (Profil-Unterpunkte). Ohne eigene Deckung würde man durch die
   Seite hindurch auf die Liste darunter lesen — die Ebene dahinter soll schemenhaft
   bleiben, aber nicht mitlesbar. */
.erg-underlay {
  background: rgba(247,244,246,0.80);
  backdrop-filter: blur(34px) saturate(180%);
  -webkit-backdrop-filter: blur(34px) saturate(180%);
}
.erg-underlay-bar {
  background: rgba(255,255,255,0.55);
  backdrop-filter: blur(24px) saturate(180%);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
}

/* Auf echten Geräten läuft die App randlos. Die Farbwäsche darf bis unter Statusleiste
   und Home-Indikator reichen, die *Inhalte* müssen aber innerhalb der sicheren Fläche
   bleiben — sonst verschwinden Knöpfe hinter Dynamic Island, Notch oder gerundeten
   Ecken. Die Zusatzwerte oben auf die env()-Werte sorgen für Luft zum Rand, auch auf
   Geräten ohne Aussparung (älteres iPhone SE, viele Android-Modelle). */
/* Zwei Bedingungen, nicht nur die Breite.
   Vorher hing die Handy-Darstellung allein an max-width: 520px. Im Querformat
   wird ein iPhone aber 667 bis 932 Punkte breit - die Regel griff dann nicht
   mehr, und die App fiel auf die Schreibtisch-Attrappe zurueck: ein schmaler
   Rahmen mit runden Ecken auf grauem Grund, mitten auf dem Telefon.
   (hover: none) and (pointer: coarse) trifft jedes Geraet, das mit dem Finger
   bedient wird - unabhaengig von Breite und Ausrichtung. */
@media (max-width: 520px), (hover: none) and (pointer: coarse) {
  /* Fest am Fenster verankert statt an 100dvh.
     Vorher mass sich der Rahmen an der dynamischen Fensterhoehe. Die aendert
     sich, sobald iOS die Tastatur ein- oder ausblendet, und WKWebView
     uebernimmt den korrigierten Wert nicht zuverlaessig zurueck. Folge: Die
     Darstellung sass hoeher als die Trefferflaechen - ein Fingertipp landete
     eine Zeile tiefer als das, was man sah.
     position: fixed mit inset: 0 fuellt genau die Flaeche der App-Huelle. Die
     bleibt konstant, egal was das System einblendet. */
  /* Startwert, bis die Leiste einmal gemessen wurde. */
  :root { --erg-nav-h: 96px; }
  html, body { height: 100%; overflow: hidden; overscroll-behavior: none; background: #F7F4F5; }
  .erg-shell { position: fixed; inset: 0; padding: 0; background: transparent; min-height: 0; }
  .erg-frame { max-width: none; height: 100%; border-radius: 0; box-shadow: none; }

  .erg-topbar {
    padding-top: calc(env(safe-area-inset-top, 0px) + 12px);
    padding-left: calc(env(safe-area-inset-left, 0px) + 18px);
    padding-right: calc(env(safe-area-inset-right, 0px) + 18px);
  }
  .erg-underlay-bar {
    padding-top: calc(env(safe-area-inset-top, 0px) + 12px);
    padding-left: calc(env(safe-area-inset-left, 0px) + 18px);
    padding-right: calc(env(safe-area-inset-right, 0px) + 18px);
  }
  .erg-navwrap {
    padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 12px);
    padding-left: calc(env(safe-area-inset-left, 0px) + 14px);
    padding-right: calc(env(safe-area-inset-right, 0px) + 14px);
  }
  /* Scrollbereiche: seitlich etwas mehr Luft als die 16px der Tailwind-Klassen, damit
     Karten und Knöpfe auf gerundeten Displays nicht am Rand kleben. */
  .erg-frame .px-4 { padding-left: calc(env(safe-area-inset-left, 0px) + 18px); padding-right: calc(env(safe-area-inset-right, 0px) + 18px); }
  /* Untere Navigation überdeckt sonst die letzten Einträge einer Liste. */
  .erg-frame .pb-24 { padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 124px); }

  /* Datums- und Zeitfelder.
     Safari auf iOS zeichnet <input type="datetime-local"> selbst: eigene
     Hoehe, blasser Text, im leeren Zustand gar keine Beschriftung. Neben den
     uebrigen Feldern sah es aus wie ein vergessener grauer Kasten.
     appearance: none nimmt die Systemdarstellung zurueck, die feste Hoehe
     bringt es auf dieselbe Zeile wie die Textfelder. */
  .erg-datetime {
    -webkit-appearance: none;
    appearance: none;
    min-height: 38px;
    line-height: 1.2;
  }
  .erg-datetime::-webkit-date-and-time-value { text-align: left; margin: 0; }
  .erg-datetime::-webkit-calendar-picker-indicator { opacity: 0.45; }

  /* Seiten OHNE obere Leiste - Vereinsauswahl, Anmeldung, Registrierung.
     Die Hauptansicht schuetzt ihren Inhalt ueber .erg-topbar. Diese Seiten
     haben keine solche Leiste; ihr Inhalt begann direkt an der Oberkante und
     lief auf Geraeten mit Dynamic Island oder Aussparung darunter.

     Der Zuschlag deckt jede Bauform ab, weil er nicht auf ein Geraet gemuenzt
     ist, sondern auf den Wert, den iOS selbst meldet: 0 beim iPhone SE, rund
     47px bei der Notch, rund 59px bei der Dynamic Island. Kommt morgen eine
     neue Bauform, stimmt die Rechnung weiterhin. */
  .erg-frame .pt-8  { padding-top: calc(env(safe-area-inset-top, 0px) + 32px); }
  .erg-frame .pt-10 { padding-top: calc(env(safe-area-inset-top, 0px) + 40px); }

  /* Dieselben Seiten seitlich: bisher war nur px-4 abgedeckt, die Anmeldung
     benutzt aber px-6. Auf gerundeten Displays klebten Felder am Rand. */
  .erg-frame .px-6 { padding-left: calc(env(safe-area-inset-left, 0px) + 24px); padding-right: calc(env(safe-area-inset-right, 0px) + 24px); }

  /* Der untere Rand dieser Seiten: Home-Indikator freihalten. */
  .erg-frame .pb-6 { padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 24px); }
}

/* Sehr schmale Geräte (iPhone SE, kompakte Android-Modelle): Abstände zurücknehmen,
   damit der Inhalt nicht eingequetscht wird. */
@media (max-width: 360px) {
  .erg-topbar, .erg-underlay-bar { padding-left: calc(env(safe-area-inset-left, 0px) + 14px); padding-right: calc(env(safe-area-inset-right, 0px) + 14px); }
  .erg-frame .px-4 { padding-left: calc(env(safe-area-inset-left, 0px) + 14px); padding-right: calc(env(safe-area-inset-right, 0px) + 14px); }
}
/* Weichere, durchgehend größere Rundungen als Tailwinds Standard. */
.erg-app .rounded-lg { border-radius: 14px; }
.erg-app .rounded-xl { border-radius: 18px; }
.erg-app .rounded-2xl { border-radius: 24px; }
.erg-app .rounded-3xl { border-radius: 30px; }
.splashRing { stroke-dasharray: 1; stroke-dashoffset: 1; transform-origin: 420px 300px; animation: splashDraw 0.65s cubic-bezier(.4,0,.2,1) 0.35s forwards, splashRingBounce 0.55s linear 1s forwards; }
@keyframes splashDraw { to { stroke-dashoffset: 0; } }
@keyframes splashRingBounce { 0% { transform: scale(1); } 30% { transform: scale(1.18); } 55% { transform: scale(0.9); } 75% { transform: scale(1.08); } 90% { transform: scale(0.97); } 100% { transform: scale(1); } }
.splashDot { transform: scale(0); transform-origin: 420px 300px; animation: splashPop 0.7s linear 1s forwards; }
@keyframes splashPop { 0% { transform: scale(0); } 38% { transform: scale(1.75); } 58% { transform: scale(0.7); } 76% { transform: scale(1.25); } 88% { transform: scale(0.9); } 100% { transform: scale(1); } }
/* Glaskachel der Öffnungs-Animation: federt herein, atmet kurz und weitet sich beim
   Ausblenden leicht, sodass der Übergang in die App wie ein Aufziehen wirkt. */
.splashTile { animation: splashTileIn 0.72s cubic-bezier(.34,1.56,.64,1) forwards, splashTileBreathe 1.4s ease-in-out 1.7s; }
@keyframes splashTileIn { 0% { opacity: 0; transform: scale(0.62); } 100% { opacity: 1; transform: scale(1); } }
@keyframes splashTileBreathe { 0%,100% { transform: scale(1); } 50% { transform: scale(1.035); } }
.splashHalo { animation: splashHaloIn 1.1s ease-out forwards; }
@keyframes splashHaloIn { 0% { opacity: 0; transform: scale(0.5); } 100% { opacity: 1; transform: scale(1); } }
.splashWord { opacity: 0; animation: splashWordIn 0.6s cubic-bezier(.4,0,.2,1) 1.45s forwards; }
@keyframes splashWordIn { 0% { opacity: 0; transform: translateY(10px); } 100% { opacity: 1; transform: translateY(0); } }
`;

/* Markenzeichen der App (Ring + Punkt) — identisch mit dem App-Icon auf dem Homescreen.
   Bewusst in der Markenfarbe und NICHT in der Vereinsfarbe: Es steht für die App selbst,
   nicht für einen einzelnen Verein. `animated` schaltet die Zeichen-Animation zu, die die
   Öffnungs-Animation nutzt. */
/* Das Zeichen der App.
 *
 * Es nimmt die Vereinsfarben. Vor der Anmeldung gibt es keinen Verein, dann
 * greifen die Vorgabewerte aus globals.css - also Rot und Schwarz, die Marke
 * selbst. Innerhalb eines Vereins traegt es dessen Farben, wie alles andere
 * auch. Nur das Symbol auf dem Homescreen kann das nicht: Es liegt als Bild im
 * Installationspaket und ist fuer alle Vereine dasselbe. */
function AppBrandMark({ size = 96, animated = false }) {
  return (
    <svg width={size} height={size} viewBox="0 0 600 600" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Club Member Organisation">
      <path className={animated ? "splashRing" : undefined} d="M420 140 A210 210 0 1 0 420 460" stroke="var(--club-primary)" strokeWidth="72" strokeLinecap="round" fill="none" pathLength="1" />
      <circle className={animated ? "splashDot" : undefined} cx="420" cy="300" r="46" fill="var(--club-secondary)" />
    </svg>
  );
}

/* Öffnungs-Animation der App (Marke, unabhängig von der Vereinsfarbe): zeichnet den Ring,
   lässt Ring + Punkt einmal einschwingen, hält kurz und blendet dann zur eigentlichen App über.
   Läuft bei jedem App-Start erneut (kein Persistenz-Flag). */
function AppSplashIntro({ onDone }) {
  const [fading, setFading] = useState(false);
  /* onDone kommt als frische Funktion bei jedem Rendern der App herein. Stünde sie in
     der Abhängigkeitsliste, würde der Effekt bei jedem Rendern neu aufgesetzt — und die
     Countdown-Uhren im Dashboard rendern im Sekundentakt. Die 3-Sekunden-Timer würden
     dadurch ständig zurückgesetzt und liefen nie ab: Die Animation bliebe für immer
     stehen. Deshalb über eine Referenz, damit der Effekt genau einmal läuft. */
  const doneRef = useRef(onDone);
  /* Die Zuweisung gehoert in einen Effekt, nicht in den Rendervorgang:
     Waehrend des Renderns darf nichts ausserhalb der Komponente veraendert
     werden. Der Effekt ohne Abhaengigkeitsliste laeuft nach JEDEM Rendern
     und steht damit vor dem Effekt darunter - die Referenz ist also aktuell,
     wenn sie gebraucht wird. */
  useEffect(() => { doneRef.current = onDone; });
  useEffect(() => {
    /* Erst wenn diese Animation wirklich auf dem Bildschirm steht, darf der
       native Startbildschirm weichen. Vorher lag dazwischen eine weiße Fläche,
       solange die Seite noch über das Netz lud — bei langsamer Verbindung
       mehrere Sekunden. Zwei Bilder derselben Marke lösen sich jetzt ab, statt
       durch Weiß getrennt zu sein.
       Der Import läuft erst zur Laufzeit und nur nativ, damit die Web-Fassung
       das Plugin nicht mitlädt. */
    let cancelled = false;
    (async () => {
      try {
        if (!Capacitor.isNativePlatform()) return;
        const { SplashScreen } = await import("@capacitor/splash-screen");
        if (!cancelled) await SplashScreen.hide();
      } catch {
        /* Ohne Plugin oder im Browser: Die Animation läuft trotzdem, nur ohne
           vorgelagerten nativen Startbildschirm. Kein Grund abzubrechen. */
      }
    })();
    const fadeTimer = setTimeout(() => setFading(true), 2600);
    const doneTimer = setTimeout(() => doneRef.current(), 3000);
    return () => { cancelled = true; clearTimeout(fadeTimer); clearTimeout(doneTimer); };
  }, []);
  return (
    <div
      className="erg-canvas absolute inset-0 flex flex-col items-center justify-center"
      style={{ zIndex: 999, opacity: fading ? 0 : 1, transform: fading ? "scale(1.06)" : "scale(1)", transition: "opacity 0.4s ease, transform 0.4s ease" }}
    >
      <div className="relative flex items-center justify-center">
        <div className="splashHalo absolute rounded-full" style={{ width: 300, height: 300, background: "radial-gradient(circle, var(--club-primary-wash), transparent 70%)" }} />
        <div className="splashTile relative flex items-center justify-center" style={{ width: 168, height: 168, borderRadius: 50, background: "rgba(255,255,255,0.72)", border: "1px solid rgba(255,255,255,0.85)", backdropFilter: "blur(24px) saturate(180%)", WebkitBackdropFilter: "blur(24px) saturate(180%)", boxShadow: "0 26px 56px rgba(60,30,45,0.16), inset 0 1px 0 rgba(255,255,255,0.9)" }}>
          <AppBrandMark size={104} animated />
        </div>
      </div>
      <div className="splashWord text-center" style={{ marginTop: 34 }}>
        <div className="text-sm" style={{ fontFamily: "Oswald", fontWeight: 600, color: "#2A2028", letterSpacing: "0.22em", textTransform: "uppercase" }}>Club Member</div>
        <div className="text-[10px] mt-1" style={{ fontFamily: "Inter", fontWeight: 600, color: "#8A7F85", letterSpacing: "0.3em", textTransform: "uppercase" }}>Organisation</div>
      </div>
    </div>
  );
}

const TEAMS = ["Herren 1", "Herren 2", "Damen 1", "U15", "U11", "Eltern / Angehörige"];
const DEMO_CLUB_ID = "00000000-0000-4000-8000-000000000001";

/* Sportartspezifisches Wording: dieselben zwei Bausteine (Helferdienst, Vereinsfahrzeuge) wie bei
   Rollhockey, nur pro Sportart anders benannt und mit passenden Stationen-Vorschlägen. */
const SPORT_CONFIG = {
  rollhockey: {
    label: "Rollhockey", homeEventLabel: "Heimspiel",
    dutyTabLabel: "Helferdienst", dutyStationExamples: "z. B. Theke, Kasse, Grill, Zeitnahme",
    vehicleTabLabel: "Vereinsfahrzeuge", vehicleIntro: "Alle Vereinsfahrzeuge und ihre Buchungen für Auswärtsfahrten.",
  },
  fussball: {
    label: "Fußball", homeEventLabel: "Heimspiel",
    dutyTabLabel: "Kioskdienst", dutyStationExamples: "z. B. Kiosk, Kasse, Grill, Ordnungsdienst, Parkplatzeinweisung",
    vehicleTabLabel: "Mannschaftsbus", vehicleIntro: "Der Mannschaftsbus und seine Buchungen für Auswärtsspiele.",
  },
  tennis: {
    label: "Tennis", homeEventLabel: "Heim-Medenspiel",
    dutyTabLabel: "Vereinsheimdienst", dutyStationExamples: "z. B. Kuchenbuffet, Getränke, Platzherrichtung, Aufbau",
    vehicleTabLabel: "Vereinsbus", vehicleIntro: "Der Vereinsbus und seine Buchungen für Auswärts-Medenspiele.",
  },
  schwimmen: {
    label: "Schwimmen", homeEventLabel: "Heimwettkampf",
    dutyTabLabel: "Wettkampfhelfer", dutyStationExamples: "z. B. Zeitnahme, Kampfrichter, Startblock-Aufsicht, Kiosk",
    vehicleTabLabel: "Vereinsbus", vehicleIntro: "Der Vereinsbus und seine Buchungen für Auswärtswettkämpfe.",
  },
  ringen: {
    label: "Ringen", homeEventLabel: "Heimkampf",
    dutyTabLabel: "Kampfrichter & Helfer", dutyStationExamples: "z. B. Kampftisch, Zeitnahme, Verpflegung, Auf-/Abbau der Matten",
    vehicleTabLabel: "Vereinsbus", vehicleIntro: "Der Vereinsbus und seine Buchungen für Auswärtskämpfe.",
  },
  handball: {
    label: "Handball", homeEventLabel: "Heimspiel",
    dutyTabLabel: "Kioskdienst", dutyStationExamples: "z. B. Kiosk, Kasse, Wurftisch/Zeitnahme, Ordnungsdienst",
    vehicleTabLabel: "Mannschaftsbus", vehicleIntro: "Der Mannschaftsbus und seine Buchungen für Auswärtsspiele.",
  },
  volleyball: {
    label: "Volleyball", homeEventLabel: "Heimspiel",
    dutyTabLabel: "Hallendienst", dutyStationExamples: "z. B. Netz-/Feldaufbau, Anschreiber, Kasse, Kuchenbuffet",
    vehicleTabLabel: "Vereinsbus", vehicleIntro: "Der Vereinsbus und seine Buchungen für Auswärtsspiele.",
  },
  basketball: {
    label: "Basketball", homeEventLabel: "Heimspiel",
    dutyTabLabel: "Kampfgerichtsdienst", dutyStationExamples: "z. B. Kampfgericht/Anschreiber, Kiosk, Kasse, Ordnungsdienst",
    vehicleTabLabel: "Mannschaftsbus", vehicleIntro: "Der Mannschaftsbus und seine Buchungen für Auswärtsspiele.",
  },
  tischtennis: {
    label: "Tischtennis", homeEventLabel: "Heim-Punktspiel",
    dutyTabLabel: "Vereinsheimdienst", dutyStationExamples: "z. B. Kuchenbuffet, Getränke, Tischaufbau, Zählertisch",
    vehicleTabLabel: "Vereinsbus", vehicleIntro: "Der Vereinsbus und seine Buchungen für Auswärts-Punktspiele.",
  },
  badminton: {
    label: "Badminton", homeEventLabel: "Heim-Punktspiel",
    dutyTabLabel: "Vereinsheimdienst", dutyStationExamples: "z. B. Kuchenbuffet, Getränke, Feldaufbau, Zählertisch",
    vehicleTabLabel: "Vereinsbus", vehicleIntro: "Der Vereinsbus und seine Buchungen für Auswärts-Punktspiele.",
  },
  leichtathletik: {
    label: "Leichtathletik", homeEventLabel: "Heimwettkampf",
    dutyTabLabel: "Kampfrichter & Helfer", dutyStationExamples: "z. B. Zeitnahme, Kampfrichter, Startnummernausgabe, Kiosk",
    vehicleTabLabel: "Vereinsbus", vehicleIntro: "Der Vereinsbus und seine Buchungen für Auswärtswettkämpfe.",
  },
  judo_karate: {
    label: "Judo/Karate", homeEventLabel: "Heimkampf",
    dutyTabLabel: "Kampfrichter & Helfer", dutyStationExamples: "z. B. Kampftisch, Zeitnahme, Verpflegung, Matten-Auf-/Abbau",
    vehicleTabLabel: "Vereinsbus", vehicleIntro: "Der Vereinsbus und seine Buchungen für Auswärtskämpfe und -turniere.",
  },
};
const SPORTS = Object.keys(SPORT_CONFIG);
const sportConfig = (sport) => SPORT_CONFIG[sport] || SPORT_CONFIG.rollhockey;

/* Club-Feature-Toggles: nach der Vereinsregistrierung per Ja/Nein abgefragt, später im
   Vereinsadmin-Reiter "Funktionen" änderbar. Default (kein Eintrag in club_feature_toggles) = an. */
const CLUB_FEATURES = [
  { key: "duty_roster", label: (sport) => sportConfig(sport).dutyTabLabel,
    question: (sport) => `Möchtet ihr „${sportConfig(sport).dutyTabLabel}" nutzen, um Helfer:innen für ${sportConfig(sport).homeEventLabel}e einzuteilen (${sportConfig(sport).dutyStationExamples})?`,
    settingsDesc: (sport) => `Helferdienst-Sätze anlegen und Stationen für ${sportConfig(sport).homeEventLabel}e zuweisen.` },
  { key: "vehicle_booking", label: (sport) => sportConfig(sport).vehicleTabLabel,
    question: (sport) => `Hat euer Verein ein Fahrzeug (${sportConfig(sport).vehicleTabLabel}), das über die App gebucht werden soll?`,
    settingsDesc: () => "Kalender & Buchung für Vereinsfahrzeuge." },
  { key: "tippspiel", label: () => "Tippspiel",
    question: () => "Soll es ein Tippspiel geben, bei dem Mitglieder Spielergebnisse vorhersagen und Punkte sammeln?",
    settingsDesc: () => "Mitglieder können Ergebnisse tippen und Punkte sammeln." },
  { key: "season_award", label: () => "Athlet/in der Saison",
    question: () => "Soll es eine Abstimmung „Athlet/in der Saison“ geben?",
    settingsDesc: () => "Mitglieder stimmen ab, wer Athlet/in der Saison wird." },
];
const DEFAULT_CLUB_FEATURES = Object.fromEntries(CLUB_FEATURES.map((f) => [f.key, true]));

/* Reihenfolge der "Aktionen & Abstimmungen"-Kacheln auf dem Dashboard — von
   Vereinsadmin/Vorstand/Sysadmin einstellbar (siehe ClubFeatureSettingsPanel). */
const DASHBOARD_TILE_LABELS = {
  season_award: "Athlet/in der Saison",
  tippspiel: "Tippspiel",
  duty_roster: "Helferplanung",
  tasks: "Aufgaben",
  vehicle_booking: (sport) => sportConfig(sport).vehicleTabLabel,
};
const DEFAULT_DASHBOARD_TILE_ORDER = ["season_award", "tippspiel", "duty_roster", "tasks", "vehicle_booking"];
const dashboardTileLabel = (key, sport) => { const l = DASHBOARD_TILE_LABELS[key]; return typeof l === "function" ? l(sport) : (l || key); };
const resolveDashboardTileOrder = (order) => {
  const clean = Array.isArray(order) ? order.filter((key) => DEFAULT_DASHBOARD_TILE_ORDER.includes(key)) : [];
  const missing = DEFAULT_DASHBOARD_TILE_ORDER.filter((key) => !clean.includes(key));
  return [...clean, ...missing];
};
const STATION_CAP = 2;
const COUNTRY_CODES = "AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS XK YE YT ZA ZM ZW".split(" ");
const NOTIFICATION_OPTIONS = [
  ["training_created", "Neues Training"], ["training_cancelled", "Trainingsabsage"],
  ["game_created", "Neues Spiel"], ["game_changed", "Spieländerung"],
  ["news", "Vereins-News"], ["chat", "Neue Chatnachrichten"],
  ["membership", "Mitgliedschaft und Freigaben"], ["payments", "Zahlungen und Beiträge"],
  ["penalties", "Strafen"], ["tasks", "Aufgaben"], ["carpool", "Fahrgemeinschaften"],
  ["duty", "Helferdienst"], ["join_requests", "Beitrittsanfragen"],
  ["polls", "Umfragen und Abstimmungen"], ["protocols", "Vorstandsprotokolle"],
  ["family", "Familienverknüpfungen"], ["security", "Sicherheitshinweise"],
  ["tipp", "Tippspiel"], ["birthdays", "Geburtstage"],
];

/* ------------------------------------------------------------------ */
/* Badge library                                                       */
/* ------------------------------------------------------------------ */
/* Nur Auszeichnungen, die man auch bekommen kann.
 *
 * Vorher standen hier vier: Trainings-Streak, Fair-Play-Award und Werber
 * konnte niemand erreichen - es gibt weder eine Anwesenheitserfassung noch
 * eine Fair-Play-Wertung noch eine Zaehlung geworbener Freunde. Vergeben
 * wurden sie ausschliesslich an die erfundenen Demo-Konten. Eine Auszeichnung,
 * die unerreichbar ist, ist keine Auszeichnung, sondern eine Enttaeuschung mit
 * Symbol.
 *
 * Geblieben sind zwei, die sich aus vorhandenen Daten ergeben. */
const BADGE_LIBRARY = {
  loyalty: { icon: Trophy, label: "Vereinstreue", descFor: (m) => `Mitglied seit ${m.since}` },
  helfer: { icon: Award, label: "Verlässliche Hilfe", desc: "Mindestens dreimal im Helferplan" },
};

/* Aus dem, was in der Datenbank steht - nicht aus einem Feld, das jemand von
   Hand setzen muesste. */
function verdienteBadges(mitglied, dutyPlan) {
  const badges = [];
  const jahre = new Date().getFullYear() - (mitglied.since || new Date().getFullYear());
  if (jahre >= 3) badges.push("loyalty");
  const dienste = Object.values(dutyPlan || {})
    .flatMap((stationen) => Object.values(stationen || {}))
    .filter((liste) => Array.isArray(liste) && liste.includes(mitglied.id)).length;
  if (dienste >= 3) badges.push("helfer");
  return badges;
}

function initialsOf(name) {
  return name.split(" ").map((p) => p[0]).slice(0, 2).join("").toUpperCase();
}

/* Das Zeichen eines Vereins - oder, wenn keiner gewaehlt ist, das der App.
 *
 * Vorher stand vor der Anmeldung ein grosses "V" auf farbigem Grund. Das war
 * ein Platzhalter fuer "Verein" und sah aus wie ein vergessener Rest: Wer die
 * App zum ersten Mal oeffnet, sieht nicht die Marke, sondern einen Buchstaben,
 * der nichts bedeutet. */
function ClubLogo({ club, size = 36, rounded = 10 }) {
  if (!club) return <AppBrandMark size={size} />;
  const base = club?.primaryColor || C.red;
  return <div className="flex items-center justify-center flex-shrink-0 overflow-hidden" style={{ width: size, height: size, borderRadius: Math.round(rounded * 1.6), background: `linear-gradient(155deg, color-mix(in srgb, ${base} 78%, #fff), ${base})`, boxShadow: `0 8px 20px color-mix(in srgb, ${base} 42%, transparent), inset 0 1px 0 rgba(255,255,255,0.4)` }}>
    {club?.logoUrl
      ? <img src={club.logoUrl} alt={`Vereinslogo ${club.name}`} className="w-full h-full object-cover" />
      : <span style={{ color: "#fff", fontFamily: "Oswald", fontWeight: 700, fontSize: Math.max(13, size * .38) }}>{club?.shortName?.[0] || "V"}</span>}
  </div>;
}

/* Rollen: jedes Profil kann mehrere Rollen gleichzeitig haben */
/* Die Farben der Namenskuerzel.
 *
 * Sie sollen Menschen auseinanderhalten, nicht huebsch sein. Vorher war das
 * eine Palette aus Violett, Messing, Petrol und Magenta - in einem Verein mit
 * zwei Farben also genau das, was nicht sein soll. Jetzt Abstufungen der
 * beiden Vereinsfarben plus zwei neutrale; das reicht, um sechs Personen
 * nebeneinander zu unterscheiden. */
const AVATAR_FARBEN = [
  "var(--club-primary)",
  "var(--club-secondary)",
  "var(--club-primary-light)",
  "var(--club-secondary-light)",
  "#3B2F38",
  "#8A7F85",
];

/* Rollenfarben.
 *
 * Hier standen neun feste Fremdfarben - Petrol, Magenta, Indigo, Ocker, Braun.
 * Ein Verein mit Schwarz und Gelb sah damit einen Regenbogen aus Rollen-Chips.
 * Jetzt kommen sie aus den beiden Vereinsfarben und neutralen Stufen. Die
 * Rollen bleiben unterscheidbar - sie tragen ohnehin ihren Namen daneben, die
 * Farbe war nie das, woran man sie erkannt hat. */
const ROLE_META = {
  vereinsadmin: { label: "Vereins-Administrator", color: C.red, admin: true, formalMember: true, selfService: false },
  sysadmin: { label: "Sys-Admin", color: C.ink, admin: true, formalMember: true, selfService: false },
  vorstand: { label: "Vorstand", color: C.red, admin: true, formalMember: true, selfService: false },
  geschaeftsfuehrung: { label: "Geschäftsführung", color: C.ink, admin: true, formalMember: true, selfService: false },
  finanzmanager: { label: "Finanzmanager", color: C.secondary, admin: false, formalMember: true, selfService: false },
  redakteur: { label: "Redakteur", color: C.secondary, admin: false, formalMember: true, selfService: false },
  sponsorenmanager: { label: "Sponsorenmanager", color: C.secondary, admin: false, formalMember: true, selfService: false },
  trainer: { label: "Trainer/in", color: C.red, admin: false, formalMember: true, selfService: false },
  kapitaen: { label: "Kapitän/in", color: C.red, admin: false, formalMember: true, selfService: false },
  teammanager: { label: "Teammanager/in", color: C.secondary, admin: false, formalMember: true, selfService: false },
  spieler: { label: "Athlet/in", color: C.secondary, admin: false, formalMember: true, selfService: true },
  eltern: { label: "Eltern", color: C.secondary, admin: false, formalMember: true, selfService: true },
  mitglied: { label: "Mitglied", color: C.textDim, admin: false, formalMember: true, selfService: true, alwaysOn: true },
  organisator: { label: "Organisator/in", color: C.secondary, admin: false, formalMember: true, selfService: false },
};
const ROLE_OVERVIEW_KEYS = ["vereinsadmin", "vorstand", "geschaeftsfuehrung", "finanzmanager", "organisator", "trainer", "teammanager", "kapitaen", "spieler", "eltern"];
/* Sys-Admin ist eine plattformweite Rolle für den Produkt-Owner, keine Vereinsrolle — daher in der
   Rollenvergabe der Vereine nicht wähl-/sichtbar. Technisch höchste vergebbare Rolle ist Vereins-Administrator. */
const ASSIGNABLE_ROLES = Object.keys(ROLE_META).filter((r) => r !== "sysadmin");
/* Aus einem Anmeldefehler eine Meldung machen, die stimmt.
 *
 * Vorher wurde JEDER Fehlschlag zu "E-Mail oder Passwort ist falsch" - auch
 * ein fehlendes Netz, eine Bremse wegen zu vieler Versuche und eine nicht
 * eingerichtete Datenbank. Wer daraufhin sein Passwort sucht, sucht an der
 * falschen Stelle; genau das ist am 01.09. passiert.
 *
 * Bewusst NICHT unterschieden wird, ob die Adresse unbekannt oder das Passwort
 * falsch ist. Supabase liefert fuer beides denselben Fehler, und das ist
 * richtig so: Wer die beiden Faelle auseinanderhalten kann, kann durchprobieren,
 * zu welchen Adressen es ein Konto gibt. Diese eine Ungenauigkeit bleibt also
 * mit Absicht stehen.
 *
 * Geprueft wird Code UND Text: Der Fehlercode ist erst in neueren Fassungen der
 * Bibliothek gesetzt, der englische Text ist der Rueckfall. */
function anmeldeFehlerText(error) {
  if (!error) return "Die Anmeldung hat nicht geklappt. Bitte versuche es noch einmal.";
  const code = String(error.code || "");
  const status = Number(error.status || 0);
  const text = String(error.message || "").toLowerCase();

  /* Gesperrte Konten bekommen ABSICHTLICH denselben Satz wie falsche
     Zugangsdaten - das ist keine Schlamperei, sondern der Grund aus dem
     Kommentar oben.
     GoTrue entscheidet die Sperre, BEVOR es das Passwort prueft. Eine eigene
     Meldung waere damit ein Auskunftsdienst: Wer irgendein Passwort eintippt,
     erfuehre an der abweichenden Antwort, dass es zu dieser Adresse ein Konto
     gibt. Sie nur zu streichen reicht nicht - dann fiele der Fall auf den
     Auffangsatz durch und das Orakel bliebe, nur mit anderem Wortlaut. */
  if (code === "invalid_credentials" || text.includes("invalid login credentials")
      || code === "user_banned" || text.includes("user is banned")) {
    return "E-Mail oder Passwort ist falsch.";
  }
  /* Anders als die Sperre ist das hier kein Orakel: Die Bestaetigung prueft
     GoTrue erst NACH dem Passwort. Diesen Satz sieht also nur, wer das
     richtige Passwort kennt. */
  if (code === "email_not_confirmed" || text.includes("email not confirmed")) {
    return "Diese E-Mail-Adresse ist noch nicht bestätigt. Sieh in deinem Postfach nach.";
  }
  if (status === 429 || code === "over_request_rate_limit" || text.includes("rate limit")) {
    return "Zu viele Versuche. Warte einen Moment und versuche es dann noch einmal.";
  }
  /* Ohne Netz kommt die Anfrage gar nicht erst beim Server an - dann gibt es
     keinen Status, nur einen abgebrochenen fetch. */
  if (status === 0 || text.includes("failed to fetch") || text.includes("network") || text.includes("load failed")) {
    return "Keine Verbindung. Prüfe dein Internet und versuche es noch einmal.";
  }
  if (status >= 500) {
    return "Die Anmeldung ist gerade nicht möglich. Bitte versuche es in ein paar Minuten noch einmal.";
  }
  return "Die Anmeldung hat nicht geklappt. Bitte versuche es noch einmal.";
}

const isDbId = (id) => /^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(String(id));
const CLUB_ADMIN_ROLES = ["vereinsadmin", "sysadmin", "vorstand", "geschaeftsfuehrung"];
const notifyClubAdmins = async (clubId, notifType, title, body, excludeMembershipId) => {
  if (!supabase || !isDbId(clubId)) return;
  const { data } = await supabase.from("club_memberships")
    .select("id,membership_roles(role)")
    .eq("club_id", clubId).eq("status", "active");
  const recipients = (data || [])
    .filter((m) => m.id !== excludeMembershipId && (m.membership_roles || []).some((r) => CLUB_ADMIN_ROLES.includes(r.role)))
    .map((m) => m.id);
  if (recipients.length) await supabase.rpc("notify_many", { target_memberships: recipients, p_notif_type: notifType, p_title: title, p_body: body });
};
const isAdmin = (m) => !!m && m.roles.some((r) => ROLE_META[r]?.admin);
/* Wer die Beitraege verwaltet.
 *
 * Vorher nur Geschaeftsfuehrung und Finanzmanager. Ein kleiner Verein, der
 * genau einen Vereinsadmin anlegt - der Normalfall bei der Gruendung -, fand
 * die Beitragsverwaltung deshalb nie. Sie war da, nur unsichtbar, und niemand
 * konnte erraten, dass es dafuer eine eigene Rolle braucht. */
/* Beitragsverwaltung vorerst abgeschaltet.
   Ein Schalter statt geloeschtem Code: Die Ansichten, Tabellen und
   Sicherheitsregeln bleiben unangetastet, nur erreichbar ist nichts davon.
   Zum Wiedereinschalten diese eine Zeile auf true setzen - und dabei den
   Abschnitt "Beitraege" in docs/website-texte.md wieder aufnehmen, der
   zusammen mit dieser Abschaltung herausgenommen wurde.
   Haengt daran: der Reiter "Beitraege", die Beitragsansicht selbst, das Laden
   der fee_records, die Kennzahl "Beitragsquote" in der Uebersicht, die Zeile
   "X Beitraege noch offen" im Kopf der Verwaltung sowie die beiden
   Beitrags-Automatiken (Zahlungserinnerungen, Beitragsperioden). */
const BEITRAGSVERWALTUNG_SICHTBAR = false;
const canManageFees = (m) => BEITRAGSVERWALTUNG_SICHTBAR && !!m && m.roles.some((r) => ["geschaeftsfuehrung", "finanzmanager", "vereinsadmin", "sysadmin", "vorstand"].includes(r));
const isFormalMember = (m) => !!m && m.roles.some((r) => ROLE_META[r]?.formalMember);
const isSysAdmin = (m) => !!m && m.roles.includes("sysadmin");

/* Mannschaftszugehoerigkeit: siehe lib/mannschaften.mjs */const canWriteNews = (m) => isAdmin(m) || (!!m && m.roles.includes("redakteur"));
/* Die eigene Sponsorenverwaltung des Vereins.
 *
 * Sie war lange ausgeblendet, weil es dafuer kein Angebot gab. Seit dem
 * 31.08.2026 gibt es eines: fuenf Euro im Monat ueber dem Tarif, freigeschaltet
 * ueber clubs.sponsoring_freigeschaltet. Der Kommentar hier sagte noch das
 * Gegenteil ("Der Reiter bleibt deshalb ausgeblendet") - wer ihn las, hielt die
 * Funktion fuer abgeschaltet. */
const SPONSOREN_VERWALTUNG_SICHTBAR = true;

const canManageSponsors = (m) => SPONSOREN_VERWALTUNG_SICHTBAR && (isAdmin(m) || (!!m && m.roles.includes("sponsorenmanager")));
const canManageDuty = (m) => isAdmin(m) || (!!m && m.roles.includes("organisator"));
/* Abo und Vertragsdaten des Vereins gehen nur die Rollen etwas an, die den Verein
   wirtschaftlich vertreten. Athlet/innen, Eltern, Trainer/innen, Kapitän/innen und
   einfache Mitglieder sehen davon nichts — weder die Karte im Profil noch die
   Aufforderung, ein Abo abzuschließen. */
/* Wer den Vollzugang anfragen darf.
 *
 * Es gab hier zwei Listen fuer dieselbe Frage: diese und eine zweite direkt im
 * Anfrageformular. Aufgerufen wurde ausschliesslich die zweite - diese hier war
 * tot, nannte aber zusaetzlich Finanzmanager und Organisator. Wer den Code las,
 * bekam die falsche Antwort.
 *
 * Massgeblich ist, was die Sicherheitsregel in der Datenbank zulaesst
 * (20260901070000_vorstand_darf_anfragen.sql): Vereinsleitung, nicht
 * Finanzmanager. Beide Stellen benutzen jetzt diese eine Liste. */
const SUBSCRIPTION_ROLES = ["sysadmin", "vereinsadmin", "geschaeftsfuehrung", "vorstand"];
const canManageSubscription = (m) => !!m && m.roles.some((r) => SUBSCRIPTION_ROLES.includes(r));

// "App kennenlernen": Kurzvideos, gefiltert nach den Aktionen, die die Rolle
// des jeweiligen Nutzers tatsächlich ausführen kann (gleiche Berechtigungslogik
// wie die Aktion selbst, z. B. canCreateSportEvent für Trainings).
const HOWTO_VIDEO_BUCKET = "howto-videos";
const HOWTO_VIDEOS = [
  {
    id: "mitglied-dashboard",
    title: "Dashboard & Profil kennenlernen",
    description: "Termine, Aufgaben und dein persönliches Profil im Überblick.",
    file: "howto-mitglied-dashboard.mp4",
    can: () => true,
  },
  {
    id: "vorstand-event",
    title: "Einen Vereinstermin anlegen",
    description: "Ein Vereins-Event eintragen, das für alle Mitglieder sichtbar ist.",
    file: "howto-vorstand-event.mp4",
    can: (user) => isAdmin(user),
  },
  {
    id: "trainer-training",
    title: "Ein Training oder Spiel ansetzen",
    description: "Für deine Mannschaft ein neues Training mit Ort und Uhrzeit anlegen.",
    file: "howto-trainer-training.mp4",
    can: (user) => isSysAdmin(user) || user.roles.some((role) => ["trainer", "kapitaen", "teammanager"].includes(role)),
  },
  {
    id: "redakteur-news",
    title: "Eine Vereins-News veröffentlichen",
    description: "Eine News schreiben und sofort für alle Mitglieder freigeben.",
    file: "howto-redakteur-news.mp4",
    can: (user) => canWriteNews(user),
  },
];
const howToVideosFor = (user) => HOWTO_VIDEOS.filter((video) => video.can(user));
const howToVideoUrl = (file) => supabase?.storage.from(HOWTO_VIDEO_BUCKET).getPublicUrl(file).data.publicUrl || "";

/* Welche der vier Dateien wirklich im Speicher liegen.
 *
 * Die Liste oben ist fest verdrahtet, getPublicUrl rechnet die Adresse nur aus
 * und fragt nichts nach. Solange keine Datei hochgeladen ist - und im
 * Produktionsprojekt gibt es den Eimer "howto-videos" ueberhaupt nicht -,
 * endet jeder aufgeklappte Eintrag in "Dieses Video ist gerade nicht
 * abrufbar.". Vier Eintraege, vier Fehlermeldungen: eine Funktion, die im
 * Pruefbetrieb nichts tut, und genau darauf zielt Richtlinie 2.1.
 *
 * Deshalb wird einmal nachgesehen. Faellt die Abfrage aus - fehlender Eimer,
 * fehlende Leserechte, kein Netz -, bleibt die Liste leer und die Kachel
 * verschwindet. Fehlschlag heisst hier also "nicht anbieten", nicht "trotzdem
 * anbieten": Eine Kachel, die nicht da ist, faellt niemandem auf; eine, die
 * nur Fehlermeldungen zeigt, schon.
 *
 * Sobald die Dateien liegen, erscheint die Kachel von selbst wieder. */
function useVorhandeneHowToVideos() {
  const [dateien, setDateien] = useState([]);
  useEffect(() => {
    let abgemeldet = false;
    (async () => {
      if (!supabase) return;
      const { data, error } = await supabase.storage.from(HOWTO_VIDEO_BUCKET).list();
      if (abgemeldet || error || !data) return;
      setDateien(data.map((eintrag) => eintrag.name));
    })();
    return () => { abgemeldet = true; };
  }, []);
  return dateien;
}
function linkFamilyRecords(list, firstId, secondId, firstRelation, linkId = null) {
  const first = list.find((m) => m.id === firstId);
  const second = list.find((m) => m.id === secondId);
  if (!first || !second || first.id === second.id) return list;
  const familyId = first.familyId || second.familyId || `fam-${Date.now()}`;
  const oldFamilyIds = [first.familyId, second.familyId].filter(Boolean);
  const opposite = firstRelation === "eltern" ? "kind" : "eltern";
  return list.map((m) => {
    const belongs = m.id === firstId || m.id === secondId || oldFamilyIds.includes(m.familyId);
    if (!belongs) return m;
    const links = [...(m.familyLinks || [])];
    if (m.id === firstId && !links.some((l) => l.memberId === secondId)) links.push({ memberId: secondId, relation: opposite, linkId });
    if (m.id === secondId && !links.some((l) => l.memberId === firstId)) links.push({ memberId: firstId, relation: firstRelation, linkId });
    return { ...m, familyId, familyRole: m.id === firstId ? firstRelation : m.id === secondId ? opposite : m.familyRole, familyLinks: links };
  });
}

function hydrateFamilyLinks(roster, links) {
  return (links || []).reduce((current, link) => linkFamilyRecords(
    current,
    link.first_membership_id,
    link.second_membership_id,
    link.first_to_second,
    link.id,
  ), roster);
}
function unlinkFamilyRecords(list, firstId, secondId) {
  const first = list.find((member) => member.id === firstId);
  const second = list.find((member) => member.id === secondId);
  if (!first || !second || first.id === second.id) return list;
  const sharedFamilyId = first.familyId && first.familyId === second.familyId ? first.familyId : null;
  const remainingFamily = sharedFamilyId ? list.filter((member) => member.familyId === sharedFamilyId && member.id !== secondId) : [];
  return list.map((member) => {
    const familyLinks = (member.familyLinks || []).filter((link) => link.memberId !== secondId && !(member.id === secondId && link.memberId === firstId));
    if (member.id === secondId) return { ...member, familyId: null, familyRole: null, familyLinks };
    if (sharedFamilyId && member.familyId === sharedFamilyId && remainingFamily.length <= 1) return { ...member, familyId: null, familyRole: null, familyLinks };
    return familyLinks.length !== (member.familyLinks || []).length ? { ...member, familyLinks } : member;
  });
}
function age(birthdate) {
  if (!birthdate) return 0;
  const b = new Date(birthdate);
  const t = new Date();
  let a = t.getFullYear() - b.getFullYear();
  const m = t.getMonth() - b.getMonth();
  if (m < 0 || (m === 0 && t.getDate() < b.getDate())) a--;
  return a;
}

/* ------------------------------------------------------------------ */
/* Vereine (mandantenfähig)                                            */
/* ------------------------------------------------------------------ */
const INITIAL_CLUBS = [
  { id: DEMO_CLUB_ID, name: "ERG Iserlohn", shortName: "ERGI", city: "Iserlohn", foundedYear: 1965, logoUrl: null },
  { id: "tsv-musterstadt", name: "TSV Musterstadt", shortName: "TSVM", city: "Musterstadt", foundedYear: 1902 },
  { id: "sv-beispiel", name: "SV Beispiel 04", shortName: "SVB", city: "Beispielhausen", foundedYear: 1904 },
];

/* ------------------------------------------------------------------ */
/* Mock accounts                                                       */
/* ------------------------------------------------------------------ */
const INITIAL_MEMBERS = [
  { id: "m1", clubId: DEMO_CLUB_ID, name: "Marco Aleixo", email: "marco@cmo.app", password: "demo", team: "Herren 1", number: 14, since: 2019, roles: ["sysadmin", "vorstand", "spieler", "mitglied"], color: C.red, points: 740, tippPoints: 14, badges: ["streak", "loyalty", "fairplay", "referrer"], birthdate: "1994-05-12" },
  { id: "m2", clubId: DEMO_CLUB_ID, name: "Marco Aleixo", email: "marco.kapitaen@cmo.app", password: "demo", team: "Damen 1", number: 7, since: 2021, roles: ["kapitaen", "spieler", "mitglied"], color: C.secondary, points: 410, tippPoints: 9, badges: ["loyalty"], birthdate: "1998-03-02" },
  { id: "m3", clubId: DEMO_CLUB_ID, name: "Sergio Pereira", email: "sergio@cmo.app", password: "demo", team: "Herren 1", playerTeams: ["Herren 1"], managedTeam: "U11", number: null, since: 2023, roles: ["spieler", "teammanager", "mitglied"], color: C.secondary, points: 120, tippPoints: 5, badges: [] },
  { id: "v1", clubId: DEMO_CLUB_ID, name: "Dirk Iwanowski", email: "dirk@cmo.app", password: "demo", team: "Vorstand", number: null, since: 2015, roles: ["vorstand", "mitglied"], color: C.ink, points: 60, tippPoints: 2, badges: ["loyalty"], birthdate: "1975-01-20" },
  { id: "m4", clubId: DEMO_CLUB_ID, name: "Rodrigo Neves", email: "rodrigo@cmo.app", password: "demo", team: "U11", number: 5, since: 2024, roles: ["spieler", "mitglied"], color: AVATAR_FARBEN[2], points: 30, tippPoints: 0, badges: [], birthdate: "2015-06-01", familyId: "fam-thomas", familyRole: "kind" },
  { id: "m5", clubId: DEMO_CLUB_ID, name: "Maria Aleixo", email: "maria@cmo.app", password: "demo", team: "Eltern / Angehörige", number: null, since: 2023, roles: ["mitglied"], color: AVATAR_FARBEN[2], points: 20, tippPoints: 0, badges: [], birthdate: "1952-02-11", familyId: "fam-thomas", familyRole: "grosseltern" },
  { id: "m6", clubId: DEMO_CLUB_ID, name: "Simone Iwanowski", email: "simone@cmo.app", password: "demo", team: "Geschäftsstelle", number: null, since: 2020, roles: ["geschaeftsfuehrung", "mitglied"], color: AVATAR_FARBEN[2], points: 60, tippPoints: 4, badges: [], birthdate: "1980-11-03" },
  { id: "m7", clubId: DEMO_CLUB_ID, name: "Guido Rath", email: "guido@cmo.app", password: "demo", team: "Geschäftsstelle", number: null, since: 2022, roles: ["redakteur", "sponsorenmanager", "mitglied"], color: AVATAR_FARBEN[2], points: 40, tippPoints: 0, badges: [], birthdate: "1990-07-08" },
  { id: "m8", clubId: DEMO_CLUB_ID, name: "Simone Iwanowski", email: "simone.finanzen@cmo.app", password: "demo", team: "Geschäftsstelle", number: null, since: 2024, roles: ["finanzmanager", "mitglied"], color: AVATAR_FARBEN[2], points: 20, tippPoints: 0, badges: [], birthdate: "1988-04-19" },
  { id: "m9", clubId: DEMO_CLUB_ID, name: "Jose Aleixo", email: "jose@cmo.app", password: "demo", team: "Herren 1", teams: ["Herren 1", "U15"], trainerTeams: ["Herren 1", "U15"], number: null, since: 2021, roles: ["trainer", "mitglied"], color: C.red, points: 35, tippPoints: 0, badges: [], birthdate: "1983-02-08" },
  { id: "m10", clubId: DEMO_CLUB_ID, name: "Adrian Börkei", email: "adrian@cmo.app", password: "demo", team: "Damen 1", playerTeams: ["Damen 1"], number: null, since: 2023, roles: ["spieler", "mitglied"], color: AVATAR_FARBEN[2], points: 10, tippPoints: 0, badges: [] },
  { id: "m11", clubId: DEMO_CLUB_ID, name: "Sandro Caramano", email: "sandro@cmo.app", password: "demo", team: "Herren 1", playerTeams: ["Herren 1"], number: null, since: 2022, roles: ["spieler", "mitglied"], color: AVATAR_FARBEN[2], points: 10, tippPoints: 0, badges: [] },
  { id: "m12", clubId: DEMO_CLUB_ID, name: "Cristiano Neves", email: "cristiano@cmo.app", password: "demo", team: "Herren 2", playerTeams: ["Herren 2"], number: null, since: 2024, roles: ["spieler", "mitglied"], color: AVATAR_FARBEN[2], points: 10, tippPoints: 0, badges: [] },
  { id: "m13", clubId: DEMO_CLUB_ID, name: "Tobias Demke", email: "tobias@cmo.app", password: "demo", team: "U11", playerTeams: ["U11"], number: null, since: 2025, roles: ["spieler", "mitglied"], color: AVATAR_FARBEN[2], points: 10, tippPoints: 0, badges: [] },
  { id: "m14", clubId: DEMO_CLUB_ID, name: "Finn Iwanowski", email: "finn@cmo.app", password: "demo", team: "U15", playerTeams: ["U15"], number: null, since: 2023, roles: ["spieler", "mitglied"], color: AVATAR_FARBEN[2], points: 10, tippPoints: 0, badges: [] },
  { id: "m15", clubId: DEMO_CLUB_ID, name: "Christopher Hegener", email: "christopher@cmo.app", password: "demo", team: "Damen 1", playerTeams: ["Damen 1"], number: null, since: 2024, roles: ["spieler", "mitglied"], color: C.secondary, points: 10, tippPoints: 0, badges: [] },
  { id: "m16", clubId: DEMO_CLUB_ID, name: "Yannik Hinz", email: "yannik@cmo.app", password: "demo", team: "Herren 2", playerTeams: ["Herren 2"], number: null, since: 2022, roles: ["spieler", "mitglied"], color: C.red, points: 10, tippPoints: 0, badges: [] },
  { id: "m17", clubId: DEMO_CLUB_ID, name: "Alexander Demke", email: "alexander@cmo.app", password: "demo", team: "U11", playerTeams: ["U11"], number: null, since: 2025, roles: ["spieler", "mitglied"], color: C.secondary, points: 10, tippPoints: 0, badges: [] },
  { id: "m18", clubId: DEMO_CLUB_ID, name: "Phillip Blum", email: "phillip@cmo.app", password: "demo", team: "U15", playerTeams: ["U15"], number: null, since: 2023, roles: ["spieler", "mitglied"], color: C.ink, points: 10, tippPoints: 0, badges: [] },
];

const INITIAL_FEE_PAID = { m1: false, m2: true, m3: false, v1: true, m4: true, m5: true, m6: true, m7: true, m8: true, m9: true };
const INITIAL_FEE_RECORDS = [
  { id: "fee-1", memberId: "m1", year: "2026", type: "Mitgliedsbeitrag", amount: "120,00", paid: false, invoiceNumber: "RG-2026-001" },
  { id: "fee-2", memberId: "m2", year: "2026", type: "Mitgliedsbeitrag", amount: "120,00", paid: true, invoiceNumber: "RG-2026-002" },
  { id: "fee-3", memberId: "m3", year: "2026", type: "Familienbeitrag", amount: "85,00", paid: false, invoiceNumber: "RG-2026-003", linkedMemberIds: ["m4", "m5"], manualNames: ["Thomas Thomas"], personCount: 4 },
  { id: "fee-4", memberId: "v1", year: "2026", type: "Mitgliedsbeitrag", amount: "60,00", paid: true, invoiceNumber: "RG-2026-004" },
  { id: "fee-5", memberId: "m4", year: "2026", type: "Mitgliedsbeitrag", amount: "75,00", paid: true, invoiceNumber: "RG-2026-005" },
];
const OVERDUE_DAYS = { m1: 5, m3: 14 };
function reminderStage(days) {
  if (days >= 20) return { n: 3, label: "Vorstand informiert", color: C.red };
  if (days >= 10) return { n: 2, label: "Mahnung", color: C.secondary };
  if (days >= 3) return { n: 1, label: "Freundliche Erinnerung", color: C.secondary };
  return { n: 0, label: "Noch nicht fällig", color: C.textDim };
}

const INITIAL_DUTY_PLAN = {
  2: { Theke: ["m2"], Zeitnahme: [], Grill: ["v1"], Kasse: [] },
  4: { Aufbau: [], Kuchenbuffet: ["m3"], Abbau: [] },
  6: { Theke: [], Zeitnahme: [], Grill: [], Kasse: [] },
};

/* ------------------------------------------------------------------ */
/* Mock content data                                                   */
/* ------------------------------------------------------------------ */
/* Die Demo-Termine liegen relativ zu HEUTE, nicht auf festen Kalendertagen.
   Vorher standen dort Daten im August 2026; ab September war jeder davon
   vergangen, und der Demo-Betrieb zeigte auf der Startseite fuer jede
   Mannschaft "kein Spiel geplant". Das sah nach einem Fehler aus, war aber
   nur abgelaufenes Beiwerk - und musste jedes Jahr von Hand nachgezogen
   werden. tageAb() rechnet den Abstand einmal beim Laden aus; die Demo bleibt
   damit von selbst aktuell.
   Betrifft ausschliesslich den Betrieb OHNE Datenbank. Sobald Supabase
   eingerichtet ist, kommen die Termine aus der Tabelle events. */
const tageAb = (tage, stunde, minute = 0) => {
  const d = new Date();
  d.setDate(d.getDate() + tage);
  d.setHours(stunde, minute, 0, 0);
  const zwei = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${zwei(d.getMonth() + 1)}-${zwei(d.getDate())}T${zwei(d.getHours())}:${zwei(d.getMinutes())}:00`;
};
const EVENTS = [
  { id: 1, type: "training", team: "Herren 1", title: "Training Herren 1", date: tageAb(2, 18, 30), location: "Hemberghalle, Iserlohn", desc: "Reguläres Mannschaftstraining. Schienbeinschoner nicht vergessen!", carpool: false, youthClassIds: ["herren1"] },
  { id: 2, type: "spiel", team: "Herren 1", title: "Heimspiel vs. Herringen", date: tageAb(7, 19, 0), location: "Hemberghalle, Iserlohn", desc: "Bundesliga, Spieltag 3. Support von den Rängen ist gewünscht!", carpool: false, home: true, helperSlots: ["Theke", "Zeitnahme", "Grill", "Kasse"] },
  { id: 3, type: "spiel", team: "Herren 1", title: "Auswärtsspiel bei ERC Wimbern", date: tageAb(14, 20, 0), location: "Wimbern · 85 km", desc: "Gemeinsame Abfahrt ab Hemberghalle. Fahrgemeinschaft bitte eintragen.", carpool: true, home: false },
  { id: 4, type: "event", title: "Sommerfest & Saisonabschluss", date: tageAb(21, 15, 0), location: "Vereinsheim am Hemberg", desc: "Grillen, Siegerehrung U11–U15, abends DJ. Familien sind herzlich willkommen.", carpool: false, helperSlots: ["Aufbau", "Kuchenbuffet", "Abbau"] },
  { id: 5, type: "training", team: "Herren 1", title: "Torwarttraining Spezial", date: tageAb(9, 19, 0), location: "Hemberghalle", desc: "Extra-Einheit mit Torwarttrainer Miguel Costa.", carpool: false, youthClassIds: ["herren1", "damen1"] },
  { id: 6, type: "spiel", team: "Herren 1", title: "Heimspiel vs. Cronenberg", date: tageAb(28, 19, 0), location: "Hemberghalle, Iserlohn", desc: "Bundesliga, Spieltag 5.", carpool: false, home: true, helperSlots: ["Theke", "Zeitnahme", "Grill", "Kasse"] },
  { id: 7, type: "spiel", team: "U11", title: "U11 Heimspiel vs. Hüls", date: tageAb(13, 11, 0), location: "Hemberghalle, Iserlohn", desc: "Jugendspieltag der U11.", carpool: false, home: true },
  { id: 8, type: "spiel", team: "U15", title: "U15 bei RSC Cronenberg", date: tageAb(20, 13, 30), location: "Wuppertal", desc: "Auswärtsspiel der U15.", carpool: true, home: false },
  { id: 9, type: "spiel", team: "Herren 2", title: "Herren 2 vs. SC Bison Calenberg", date: tageAb(21, 18, 0), location: "Hemberghalle, Iserlohn", desc: "Heimspiel der zweiten Mannschaft.", carpool: false, home: true },
  { id: 10, type: "spiel", team: "Damen 1", title: "Damen 1 vs. RSC Gera", date: tageAb(27, 16, 0), location: "Hemberghalle, Iserlohn", desc: "Heimspiel der Damenmannschaft.", carpool: false, home: true },
];

const YOUTH_CLASSES = [
  { id: "herren1", name: "Herren 1" },
  { id: "herren2", name: "Herren 2" },
  { id: "damen1", name: "Damen 1" },
  { id: "u15", name: "U15" },
  { id: "u11", name: "U11" },
];
const TEAM_TO_YOUTHCLASS = { "Herren 1": "herren1", "Herren 2": "herren2", "Damen 1": "damen1", U15: "u15", U11: "u11" };
const TRAINERS = [
  { id: "tr1", name: "Uwe Fischer", youthClassIds: ["herren1"] },
  { id: "tr2", name: "Miguel Costa", youthClassIds: ["herren1", "damen1"] },
  { id: "tr3", name: "Sandra Klein", youthClassIds: ["u11"] },
];
/* getNextMatch() stand hier und filterte die Demo-Konstante EVENTS. Es war der
   Rueckfall der Startseite und zeigte echten Vereinen ein Spiel aus dem
   Demo-Verein. Die Startseite nimmt jetzt nur noch echte Termine. */

/* Sponsor-Slots: reservierte, buchbare Werbeflächen zwischen den Layout-Bereichen */
const SPONSOR_SLOT_DEFS = [
  { key: "dashboard_top", label: "Start – oben" },
  { key: "dashboard_bottom", label: "Start – unter den News" },
  { key: "events_header", label: "Termine – Kopfbereich" },
  { key: "profile_bottom", label: "Profil unten" },
];
/* Alle drei Listen waren mit Demo-Inhalten vorbelegt und dienen zugleich als
   Anfangszustand fuer JEDEN Verein. Ein frisch angelegter Verein bekam dadurch
   fremde Firmen als seine Sponsoren angezeigt - Sparkasse Iserlohn, Stadtwerke
   Iserlohn, Autohaus Meyer, samt Links auf deren Webseiten -, dazu zwei
   erfundene Geburtstage und eine Abstimmung ueber eine Weihnachtsfeier mit 63
   Stimmen, die nie jemand abgegeben hat.

   Werbung schaltet ohnehin nur der Betreiber ueber die Sponsor-Slots, die
   Geburtstage kommen jetzt aus den echten Mitgliedern, und Abstimmungen legt
   der Verein selbst an. */
const INITIAL_POLLS = [];

/* Eine Zeile aus messages in die Form bringen, die ChatView erwartet.
   Der Name kommt ueber die Verknuepfung zu profiles; fehlt sie - etwa bei
   einer Realtime-Meldung, die nur die reine Zeile liefert -, steht dort
   vorerst "Mitglied", bis der naechste vollstaendige Ladevorgang laeuft. */
function zeileZuNachricht(zeile) {
  const profil = Array.isArray(zeile.profiles) ? zeile.profiles[0] : zeile.profiles;
  const name = profil?.full_name || "Mitglied";
  const zeit = new Date(zeile.created_at);
  return {
    id: zeile.id,
    who: name,
    init: initialsOf(name),
    color: C.red,
    text: zeile.body,
    time: zeit.toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" }),
    authorId: zeile.author_id,
  };
}

const INITIAL_CHANNELS = [
  {
    id: "team", name: "Herren 1", emoji: "🏒", team: "Herren 1", adminOnly: false, visibleRoles: ["spieler", "trainer", "kapitaen"], writeRoles: ["spieler", "trainer", "kapitaen"],
    messages: [
      { who: "Marco S.", init: "MS", color: C.red, text: "Denkt an die Schienbeinschoner morgen, Trainer checkt das 😅", time: "09:14" },
      { who: "Jasmin R.", init: "JR", color: C.secondary, text: "Bin heute 10 Min später da, hab Meeting.", time: "09:20" },
    ],
  },
  {
    id: "damen1", name: "Damen 1", emoji: "🏒", team: "Damen 1", adminOnly: false, visibleRoles: ["spieler", "trainer", "kapitaen"], writeRoles: ["spieler", "trainer", "kapitaen"],
    messages: [{ who: "Jasmin R.", init: "JR", color: C.secondary, text: "Trainingsstart heute um 19 Uhr — bis später!", time: "08:45" }],
  },
  {
    id: "news", name: "Vereins-News", emoji: "📣", adminOnly: true, visibleRoles: null,
    messages: [
      { who: "Vorstand", init: "V", color: C.ink, text: "Neue Trikots sind da — Abholung diese Woche im Vereinsheim.", time: "Mo" },
      { who: "Vorstand", init: "V", color: C.ink, text: "Erinnerung: Mitgliederversammlung am 12.09., 19 Uhr, Hemberghalle.", time: "Di" },
      { who: "Vorstand", init: "V", color: C.ink, text: "Helferplan für Heimspiele & Sommerfest ist online — bitte eintragen!", time: "Heute" },
    ],
  },
  {
    id: "eltern", name: "Eltern U11", emoji: "👨‍👩‍👧", adminOnly: false, visibleRoles: ["eltern"],
    messages: [
      { who: "Sabine T.", init: "ST", color: C.secondary, text: "Wer kann Samstag zum Turnier nach Hagen mitfahren?", time: "18:02" },
    ],
  },
];


/* ------------------------------------------------------------------ */
/* Athlet/in der Saison                                                  */
/* ------------------------------------------------------------------ */
/* Die Saison und ihr Wahlende rollen mit dem Kalender weiter.
 *
 * Vorher stand hier ein festes Datum - der 31.08.2026. Ab dem Tag danach haette
 * JEDER Verein eine dauerhaft geschlossene Wahl gesehen, fuer immer, ohne dass
 * jemand etwas falsch gemacht haette. Ein fest verdrahtetes Datum in einer App,
 * die Jahre laufen soll, ist eine Zeitbombe mit Ansage.
 *
 * Die Sportsaison laeuft von Juli bis Juni. Gewaehlt wird ueber die LAUFENDE
 * Saison, und zwar bis zum 31.08. nach ihrem Ende - nach dem letzten Spieltag
 * bleiben so noch zwei Monate Zeit. Am 1. September rueckt die naechste Saison
 * nach, und es gibt keinen Zeitraum, in dem gar nichts zur Wahl steht. */
function laufendeSaison(heute = new Date()) {
  const jahr = heute.getFullYear();
  const beginn = heute.getMonth() >= 8 ? jahr : jahr - 1;   // ab September naechste Saison
  return { kennung: `${beginn}/${String(beginn + 1).slice(-2)}`, ende: new Date(`${beginn + 1}-08-31T23:59:59`) };
}
const SEASON_VOTE_DEADLINE = laufendeSaison().ende.toISOString();
/* Die Saison, um die es geht. Die Wahl liegt je Saison in der Datenbank -
   ohne diese Kennung wuerde die Wahl des naechsten Jahres die des letzten
   ueberschreiben, und es gaebe nie ein Archiv. */
const SAISON_KENNUNG = laufendeSaison().kennung;
/* Zur Wahl stehen die Athletinnen und Athleten des Vereins. Frueher war das eine
   feste Liste mit fuenf erfundenen Namen und zusammen 144 erfundenen Stimmen,
   die jedem Verein als seine eigene Wahl angezeigt wurde.

   Jetzt kommen die Kandidaten aus den Mitgliedern: wer die Rolle "spieler"
   traegt und freigegeben ist, steht zur Wahl. Damit pflegt sich die Liste von
   selbst - ein neuer Spieler ist automatisch waehlbar, ein ausgetretener
   verschwindet. */
const saisonKandidaten = (members) => (members || [])
  .filter((m) => !m.accountPending && m.roles?.includes("spieler"))
  .map((m) => ({ id: m.id, name: m.name, team: m.team, number: m.number }))
  .sort((a, b) => a.name.localeCompare(b.name, "de"));

/* Gezaehlt werden ausschliesslich echte Stimmen - der frueher aufaddierte
   Grundstock ist ersatzlos entfallen. */
function seasonResults(seasonVotes, kandidaten = []) {
  const counts = kandidaten.reduce((acc, c) => {
    acc[c.id] = Object.values(seasonVotes).filter((v) => v === c.id).length;
    return acc;
  }, {});
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  const sorted = [...kandidaten].sort((a, b) => counts[b.id] - counts[a.id]);
  return { counts, total, sorted };
}

/* ------------------------------------------------------------------ */
/* Tippspiel                                                            */
/* ------------------------------------------------------------------ */
/* Getippt wird auf die echten Spiele des Vereins. Frueher standen hier vier frei
   erfundene Begegnungen, die jedem Verein als seine naechsten Spiele angezeigt
   wurden.

   Bewusst wird nur der Titel des Termins uebernommen und nicht versucht, aus
   ihm einen Gegner zu lesen: Die Titel sind frei geschrieben ("Heimspiel gegen
   SG Lindental", "Gastspiel bei SV Buchenfelde", "GEGEN Herringen", "Turnier"),
   jede Zerlegung waere geraten. Getippt wird deshalb "wir : sie" - das ist
   eindeutig, unabhaengig davon, ob heim oder auswaerts gespielt wird. */
const tippBegegnungen = (events) => (events || [])
  .filter((e) => e.type === "spiel" && e.date && !e.cancelled)
  .sort((a, b) => new Date(a.date) - new Date(b.date))
  .map((e) => ({ id: e.id, titel: e.title, team: e.team, heim: e.home !== false, date: e.date }));

function predictionPoints(prediction, result) {
  if (!prediction || !result || prediction.home === "" || prediction.away === "") return 0;
  const predictedHome = Number(prediction.home);
  const predictedAway = Number(prediction.away);
  const actualHome = Number(result.home);
  const actualAway = Number(result.away);
  if (predictedHome === actualHome && predictedAway === actualAway) return 3;
  const tendency = (home, away) => home === away ? 0 : home > away ? 1 : -1;
  return tendency(predictedHome, predictedAway) === tendency(actualHome, actualAway) ? 1 : 0;
}

function totalTippPoints(userId, predictions, results, begegnungen = []) {
  return begegnungen.reduce((sum, match) => sum + predictionPoints(predictions[userId]?.[match.id], results[match.id]), 0);
}

/* ------------------------------------------------------------------ */
/* Vorstandsprotokolle                                                  */
/* ------------------------------------------------------------------ */
/* Hier stand ein ausformuliertes Vorstandsprotokoll vom 14.07.2026 samt
   Teilnehmern und zwei Aufgaben - als Anfangszustand fuer jeden Verein. Wer die
   App neu einrichtete, fand unter Verwaltung > Protokolle eine Sitzung, die es
   bei ihm nie gegeben hat. Protokolle legt der Vorstand selbst an. */
const INITIAL_PROTOCOLS = [];

/* ------------------------------------------------------------------ */
/* Helpers                                                              */
/* ------------------------------------------------------------------ */
function useCountdown(target) {
  const [now, setNow] = useState(new Date());
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(t);
  }, []);
  const diff = Math.max(0, new Date(target).getTime() - now.getTime());
  return {
    d: Math.floor(diff / 86400000),
    h: Math.floor((diff % 86400000) / 3600000),
    m: Math.floor((diff % 3600000) / 60000),
    s: Math.floor((diff % 60000) / 1000),
  };
}
function formatDate(iso) {
  return new Date(iso).toLocaleDateString("de-DE", { weekday: "short", day: "2-digit", month: "2-digit" });
}
function formatTime(iso) {
  return new Date(iso).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });
}
const typeMeta = {
  training: { label: "Training", color: C.ink },
  spiel: { label: "Spiel", color: C.red },
  event: { label: "Vereinsevent", color: C.secondary },
};

/* ------------------------------------------------------------------ */
/* Small building blocks                                               */
/* ------------------------------------------------------------------ */
function Pill({ children, bg, fg = C.white, style }) {
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold tracking-wide"
      style={{ background: bg, color: fg, fontFamily: "Inter", ...style }}>
      {children}
    </span>
  );
}
function SectionTitle({ eyebrow, title, right }) {
  return (
    <div className="flex items-end justify-between mb-3.5">
      <div>
        {eyebrow && <div className="text-[10px] font-bold tracking-[0.18em] uppercase mb-1" style={{ color: C.red, fontFamily: "Inter" }}>{eyebrow}</div>}
        <div className="text-xl" style={{ fontFamily: "Oswald", fontWeight: 600, color: C.ink, letterSpacing: "-0.01em" }}>{title}</div>
      </div>
      {right}
    </div>
  );
}

/* Im Glas-Design tragen die Abschnitte selbst keine Fläche mehr: Überschrift steht
   direkt auf der Hintergrund-Wäsche, die Inhalte darunter sind die Glaskarten. Die
   früheren Pastellflächen mit Akzentbalken entfallen (accent/background bleiben als
   Props erhalten, damit die ~8 Aufrufstellen unverändert bleiben können). */
function DashboardSection({ children, className = "" }) {
  return (
    <section className={`relative mb-7 ${className}`}>
      {children}
    </section>
  );
}
function Field({ icon: Icon, ...props }) {
  return (
    <div className="flex items-center gap-2 rounded-xl px-3.5 py-3 mb-3" style={{ background: C.paperDim }}>
      <Icon size={16} style={{ color: C.textDim, flexShrink: 0 }} />
      <input {...props} className="flex-1 bg-transparent outline-none text-sm" style={{ fontFamily: "Inter", color: C.ink }} />
    </div>
  );
}
/* locked = Funktion ist im aktuellen Tarif nicht freigeschaltet. Rechts steht
   dann ein graues Schloss statt des Pfeils, damit man das schon in der Liste
   sieht und nicht erst nach dem Antippen. Die Zeile bleibt anklickbar — sie
   führt zur Sperrseite mit dem Hinweis aufs Abo. */
function FeatureRow({ icon: Icon, title, subtitle, onClick, accent, locked }) {
  const tint = accent || C.red;
  return (
    <button onClick={onClick} className="w-full flex items-center justify-between px-4 py-3.5 rounded-2xl mb-2.5" style={{ background: C.glass, border: `1px solid ${C.edge}`, boxShadow: "0 10px 26px rgba(60,30,45,0.07)" }}>
      <span className="flex items-center gap-3.5">
        <span className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: `linear-gradient(155deg, color-mix(in srgb, ${tint} 72%, #fff), ${tint})`, boxShadow: `0 6px 14px color-mix(in srgb, ${tint} 34%, transparent), inset 0 1px 0 rgba(255,255,255,0.45)` }}>
          <Icon size={17} style={{ color: "#fff" }} />
        </span>
        <span className="text-left">
          <span className="block text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{title}</span>
          <span className="block text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{subtitle}</span>
        </span>
      </span>
      {locked
        ? <Lock size={15} aria-label="Nicht freigeschaltet" style={{ color: C.textDim, flexShrink: 0 }} />
        : <ChevronRight size={15} style={{ color: C.textDim, flexShrink: 0 }} />}
    </button>
  );
}
function StatCard({ icon: Icon, label, value, sub, accent, onClick }) {
  const Tag = onClick ? "button" : "div";
  return (
    <Tag onClick={onClick} className="rounded-2xl p-4 text-left w-full" style={{ background: C.glass, border: `1px solid ${C.edge}`, boxShadow: "0 10px 26px rgba(60,30,45,0.07)" }}>
      <div className="w-10 h-10 rounded-xl flex items-center justify-center mb-3" style={{ background: `linear-gradient(155deg, color-mix(in srgb, ${accent || C.red} 72%, #fff), ${accent || C.red})`, boxShadow: `0 6px 14px color-mix(in srgb, ${accent || C.red} 34%, transparent), inset 0 1px 0 rgba(255,255,255,0.45)` }}>
        <Icon size={17} style={{ color: "#fff" }} />
      </div>
      <div className="text-lg leading-tight" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{value}</div>
      <div className="text-[11px]" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{label}</div>
      {sub && <div className="text-[10px] mt-0.5" style={{ color: C.textDim, fontFamily: "Inter" }}>{sub}</div>}
    </Tag>
  );
}
/* ------------------------------------------------------------------ */
/* Abo-Sperre: alles außer Training/Spiele braucht ein Vereinsabo        */
/* (Basic oder Premium), es sei denn der persönliche 2-Wochen-Trial des  */
/* Nutzers läuft noch. Siehe member_entitlement_tier() in Supabase.      */
/* ------------------------------------------------------------------ */
function useClubEntitlement(user) {
  /* Der Testzeitraum ist entfallen. member_trial_info wird deshalb nicht mehr
     abgefragt - die Funktion gewaehrte ohnehin nichts, sie verglich nur das
     Anlagedatum der Mitgliedschaft mit trial_period(). Damit spart der Aufruf
     eine Abfrage bei jedem Laden und es gibt keinen Zustand mehr, aus dem sich
     eine falsche Ablauf-Ankuendigung bauen laesst. */
  const [state, setState] = useState({ loading: true, tier: "pro" });
  useEffect(() => {
    if (!supabase || !isDbId(user?.id)) { setState({ loading: false, tier: "pro" }); return; }
    let cancelled = false;
    (async () => {
      const { data: tier } = await supabase.rpc("member_entitlement_tier", { target_membership: user.id });
      if (cancelled) return;
      setState({ loading: false, tier: tier || "none" });
      // Kein aktives Vereinsabo (mehr) -> Rollen jenseits "mitglied" zurücksetzen.
      // Bei erneutem Abo werden sie NICHT automatisch wiederhergestellt (siehe SQL-Funktion).
      if ((tier || "none") === "none" && isDbId(user?.clubId)) {
        supabase.rpc("sync_club_role_entitlement", { target_club: user.clubId });
      }
    })();
    return () => { cancelled = true; };
  }, [user?.id, user?.clubId]);
  return state;
}

/* Gesperrte Funktion. Der echte Inhalt wird bewusst NICHT gerendert:
   Früher lag er unscharf im Hintergrund — dadurch wurde der Container so hoch wie
   die vollständige Ansicht, die Seite ließ sich scrollen und die Meldung saß in der
   Mitte dieser Höhe statt im Sichtbereich. Zusätzlich lud die App dabei Daten, die
   das Mitglied gar nicht sehen darf.
   Jetzt: feste Höhe innerhalb des Sichtfensters, kein Scrollen, im Hintergrund nur
   ein paar dekorative Platzhalter ohne echten Inhalt. */
function LockedFeature({ entitlement, feature = "Diese Funktion", goSubscribe, children }) {
  if (entitlement.loading) return <div className="rounded-2xl p-8" style={{ background: C.paperDim }} />;
  /* Seit dem Groessenstaffel-Modell unterscheiden sich die Tarife nur noch in
     der Zahl der Zugaenge, nicht im Funktionsumfang. Freigeschaltet ist also
     alles, sobald ueberhaupt ein Tarif laeuft. */
  const unlocked = entitlement.tier !== "none";
  if (unlocked) return children;
  return (
    <div
      className="relative rounded-2xl overflow-hidden flex items-center justify-center"
      style={{ height: "100%", minHeight: 320 }}
    >
      <div aria-hidden="true" className="absolute inset-0 p-4 pointer-events-none select-none" style={{ filter: "blur(5px)", opacity: 0.3 }}>
        {[72, 72, 72, 72, 72].map((h, i) => (
          <div key={i} className="rounded-2xl mb-3" style={{ height: h, background: C.glass, border: `1px solid ${C.edge}` }} />
        ))}
      </div>
      <div className="relative flex flex-col items-center justify-center text-center px-7">
        <div className="w-14 h-14 rounded-full flex items-center justify-center mb-4" style={{ background: C.glass, border: `1px solid ${C.edge}`, boxShadow: "0 10px 26px rgba(60,30,45,0.10)" }}><Lock size={22} style={{ color: C.red }} /></div>
        <div className="text-base font-bold mb-1.5" style={{ fontFamily: "Oswald", color: C.ink }}>{feature} braucht den Vollzugang</div>
        {/* Hier stand eine Fallunterscheidung auf "requires" - eine Variable, die
            es nirgends gibt und die diesen Bildschirm mit einem ReferenceError
            abgeraeumt hat, sobald ein Verein ohne Abo eine gesperrte Funktion
            oeffnete. Sie stammte aus dem alten Modell mit unterschiedlichem
            Funktionsumfang je Tarif. Seit der Groessenstaffel schaltet jeder
            Tarif alles frei, also gibt es nichts mehr zu unterscheiden. */}
        <div className="text-xs mb-5 leading-snug" style={{ color: C.textDim }}>Diesen Bereich schaltet der Verein frei.</div>
        <button onClick={goSubscribe} className="px-5 py-2.5 rounded-2xl text-xs font-bold" style={{ background: C.red, color: C.white, boxShadow: `0 8px 20px color-mix(in srgb, ${C.red} 34%, transparent)` }}>Mehr erfahren</button>
      </div>
    </div>
  );
}

/* Hier stand TrialCountdownBanner: eine Kachel "Noch N Tage voller Zugriff"
   samt Blatt "Dein Test-Zeitraum". Sie ist ersatzlos entfallen, denn sie hat
   etwas angekuendigt, das es nicht gibt.

   member_trial_info gewaehrt naemlich gar nichts - die Funktion vergleicht nur
   das Anlagedatum der Mitgliedschaft mit trial_period(). Der Zugang eines
   Mitglieds entspricht immer dem Tarif seines Vereins
   (member_entitlement_tier). Die Kachel zaehlte also 14 Tage herunter, nach
   deren Ablauf sich nichts aenderte. Sie las sich fuer jedes neu angelegte
   Mitglied wie ein Countdown bis zur Sperre. */


function ToggleCard({ title, desc, value, onChange }) {
  return (
    <div>
      <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{title}</div>
      <button onClick={() => onChange((v) => !v)} className="w-full flex items-center justify-between gap-3 px-4 py-3 rounded-2xl" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
        <span className="text-xs text-left" style={{ fontFamily: "Inter", color: C.textDim }}>{desc}</span>
        <span className="w-10 h-6 rounded-full relative flex-shrink-0" style={{ background: value ? C.secondary : C.paperDim }}>
          <span className="absolute top-0.5 w-5 h-5 rounded-full" style={{ background: "#fff", left: value ? 18 : 2, transition: "left .2s" }} />
        </span>
      </button>
    </div>
  );
}
/* Ein Werbeplatz.
 *
 * Was hier steht, entscheidet die Datenbank (anzeige_fuer_platz): Hat der
 * Verein einen eigenen, laufenden Sponsor und ist Sponsoring freigeschaltet,
 * gewinnt der; sonst die Werbung des Betreibers; sonst bleibt der Platz frei.
 *
 * Sichtbar unterschieden wird beides trotzdem. "Anzeige" ist Werbung, die mit
 * dem Verein nichts zu tun hat; "Sponsor" ist jemand, den der Verein selbst
 * eingetragen hat. Wer beides gleich aussehen laesst, macht den Verein zum
 * Werbetraeger fuer Fremde.
 *
 * Die Aktion erscheint nur, solange sie laeuft. Danach bleibt der Sponsor
 * stehen, der Aktionsknopf verschwindet - genau das war die Anforderung. */
function SponsorSlot({ slotKey, bookings, onImpression, onClick, visible = true }) {
  const anzeige = bookings?.[slotKey];
  const [showDetails, setShowDetails] = useState(false);
  useEffect(() => { if (anzeige && visible) onImpression?.(slotKey); }, [anzeige, slotKey, visible]);
  if (!anzeige || !visible) return null;

  const vomVerein = anzeige.herkunft === "verein";
  /* Ob die Aktion laeuft, hat die Datenbank schon entschieden: Ausserhalb
     ihres Zeitraums kommen die Aktionsfelder leer zurueck. Hier steht deshalb
     keine zweite, moeglicherweise abweichende Rechnung. */
  const laeuft = !!anzeige.aktion_titel;
  const open = () => { onClick?.(slotKey); setShowDetails(true); };

  return (
    <>
      <button onClick={open} className="w-full rounded-2xl px-4 py-3 mb-5 flex items-center gap-3 text-left overflow-hidden" style={{ background: C.paperDim, border: `1px dashed ${C.line}` }}>
        <div className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          {anzeige.bild_url ? <img src={anzeige.bild_url} alt="" className="w-full h-full object-cover rounded-lg"/> : <Sparkles size={14} style={{ color: C.secondary }} />}
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-[9px] uppercase tracking-widest font-semibold" style={{ color: C.textDim, fontFamily: "Inter" }}>{vomVerein ? "Sponsor" : "Anzeige"}</div>
          <div className="text-xs truncate" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{anzeige.titel}</div>
          {laeuft
            ? <div className="text-[10px] truncate mt-0.5" style={{ color: C.red, fontWeight: 700 }}>{anzeige.aktion_titel}</div>
            : anzeige.text && <div className="text-[10px] truncate mt-0.5" style={{ color: C.textDim }}>{anzeige.text}</div>}
        </div>
        <ChevronRight size={14} style={{ color: C.textDim, flexShrink: 0 }} />
      </button>

      {showDetails && <div className="absolute inset-0 z-50 flex items-end p-3" style={{ background: "rgba(20,21,26,.72)" }} onClick={() => setShowDetails(false)}>
        <div role="dialog" aria-modal="true" aria-label={anzeige.titel} onClick={(e) => e.stopPropagation()} className="w-full rounded-3xl overflow-hidden" style={{ background: C.glass, maxHeight: "80%", overflowY: "auto" }}>
          <div className="p-4">
            <div className="text-[9px] uppercase tracking-widest font-bold mb-1" style={{ color: vomVerein ? C.secondary : C.textDim }}>{vomVerein ? "Sponsor unseres Vereins" : "Anzeige"}</div>
            <h2 className="text-lg font-bold" style={{ fontFamily: "Oswald", color: C.ink }}>{anzeige.titel}</h2>
            {anzeige.text && <p className="text-sm leading-relaxed mt-2" style={{ color: C.textDim }}>{anzeige.text}</p>}

            {/* Die Aktion steht abgesetzt, damit sie nicht mit der
                Sponsorenbeschreibung verschwimmt - und mit ihrem Ende, damit
                niemand hinterher enttaeuscht ist. */}
            {laeuft && (
              <div className="rounded-2xl p-3.5 mt-3" style={{ background: C.fehlerFlaeche, border: `1px solid ${C.edge}` }}>
                <div className="text-sm font-bold mb-1" style={{ color: C.red }}>{anzeige.aktion_titel}</div>
                {anzeige.aktion_text && <div className="text-[11px] leading-relaxed" style={{ color: C.ink }}>{anzeige.aktion_text}</div>}
                {anzeige.aktion_bis && <div className="text-[10px] mt-2" style={{ color: C.textDim }}>Läuft noch bis {new Date(anzeige.aktion_bis).toLocaleDateString("de-DE")}</div>}
                {anzeige.aktion_url && <a href={anzeige.aktion_url} target="_blank" rel="noopener noreferrer" className="flex items-center justify-between rounded-xl px-3 py-2.5 text-xs font-bold mt-2.5" style={{ background: C.red, color: C.white }}>Zur Aktion <ExternalLink size={14}/></a>}
              </div>
            )}

            {anzeige.ziel_url && <a href={anzeige.ziel_url} target="_blank" rel="noopener noreferrer" className="flex items-center justify-between rounded-xl px-3 py-2.5 text-xs font-bold mt-3" style={{ background: C.paperDim, color: C.ink }}>Website ansehen <ExternalLink size={14}/></a>}
          </div>
          {anzeige.bild_url && <img src={anzeige.bild_url} alt={anzeige.titel} className="w-full block" style={{ maxHeight: 280, objectFit: "cover" }}/>}
        </div>
      </div>}
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Auth: Login & Register                                              */
/* ------------------------------------------------------------------ */
function AuthShell({ children, footer, club }) {
  return (
    <div className="flex flex-col h-full px-6 pt-8 pb-6 overflow-y-auto" style={{ background: C.paper }}>
      <div className="flex flex-col items-center mb-8">
        <div className="mb-3"><ClubLogo club={club} size={56} rounded={16} /></div>
        <div className="text-sm tracking-widest" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{club ? club.shortName : "VEREINS-APP"}</div>
        <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>{club ? `Mitglieder-App · seit ${club.foundedYear}` : "Mitglieder-App für Vereine"}</div>
      </div>
      {children}
      <div className="mt-auto pt-6">{footer}</div>
    </div>
  );
}

/* Nach der Anmeldung: die Vereine dieses Kontos.
 *
 * Die Reihenfolge war frueher umgekehrt - erst Verein waehlen, dann anmelden.
 * Das passte nicht: Ein Konto gehoert zu einem Menschen, nicht zu einem Verein,
 * und wer in zwei Vereinen ist, musste sich zweimal ueberlegen, wo er hin will,
 * bevor er ueberhaupt wusste, ob seine Anmeldung stimmt.
 *
 * Jetzt meldet man sich an und sieht danach, wo man dazugehoert. Ist es nur
 * einer, wird er ohne Umweg geoeffnet - dieser Bildschirm erscheint dann gar
 * nicht. */
function MeineVereineScreen({ mitgliedschaften, onOeffnen, onWeitererVerein, onAbmelden, onKontoLoeschen, laedt }) {
  /* Der Bildschirm listet ausdruecklich auch Mitgliedschaften auf, deren
     Aufnahme noch nicht bestaetigt ist. Tippte man auf so einen Eintrag,
     passierte sichtbar gar nichts: keine Meldung, kein Wechsel. Der
     Rueckgabewert wurde verworfen. */
  const [fehler, setFehler] = useState("");
  const oeffnen = async (m) => {
    setFehler("");
    const ergebnis = await onOeffnen(m);
    if (ergebnis?.code === "membership_pending") setFehler(`Deine Aufnahme bei ${m.clubName} ist noch nicht bestätigt. Sobald die Vereinsleitung sie freigibt, kommst du hinein.`);
    else if (ergebnis?.error) setFehler(ergebnis.error);
  };
  return (
    <div className="flex flex-col h-full px-6 pt-10 pb-6 overflow-y-auto" style={{ background: C.paper }}>
      <div className="flex flex-col items-center mb-8">
        <div className="flex items-center justify-center mb-4" style={{ width: 76, height: 76, borderRadius: 24, background: "rgba(255,255,255,0.72)", border: "1px solid rgba(255,255,255,0.9)" }}>
          <AppBrandMark size={46} />
        </div>
        <div className="text-xl text-center" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>Deine Vereine</div>
        <div className="text-xs text-center mt-1" style={{ color: C.textDim, fontFamily: "Inter" }}>
          {mitgliedschaften.length === 0 ? "Du gehörst noch keinem Verein an." : "Wähle den Verein, in den du möchtest."}
        </div>
      </div>

      {fehler && <div role="status" className="rounded-2xl px-3.5 py-3 mb-4 text-xs leading-relaxed" style={{ background: C.fehlerFlaeche, color: C.fehler, fontFamily: "Inter" }}>{fehler}</div>}

      <div className="space-y-2 mb-6">
        {mitgliedschaften.map((m) => (
          <button key={m.id} onClick={() => oeffnen(m)} disabled={laedt}
            className="w-full flex items-center gap-3 rounded-2xl px-3.5 py-3.5 text-left"
            style={{ background: C.glass, border: `1px solid ${C.edge}`, opacity: laedt ? .6 : 1 }}>
            <div className="w-10 h-10 rounded-xl flex items-center justify-center text-sm font-bold flex-shrink-0" style={{ background: C.red, color: "#fff", fontFamily: "Inter" }}>
              {(m.clubShortName || m.clubName || "?").slice(0, 2).toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-sm font-bold truncate" style={{ color: C.ink, fontFamily: "Inter" }}>{m.clubName}</div>
              <div className="text-[11px] truncate" style={{ color: C.textDim, fontFamily: "Inter" }}>
                {m.status === "pending" ? "Aufnahme noch nicht bestätigt" : m.display_name}
              </div>
            </div>
            <ChevronRight size={16} style={{ color: C.textDim, flexShrink: 0 }} />
          </button>
        ))}
      </div>

      <button onClick={onWeitererVerein} className="w-full py-3 rounded-xl text-sm font-bold mb-3" style={{ background: C.ink, color: C.white, fontFamily: "Inter" }}>
        {mitgliedschaften.length === 0 ? "Verein suchen oder anlegen" : "Weiterem Verein beitreten"}
      </button>

      <button onClick={onAbmelden} className="w-full py-2.5 text-xs font-bold mb-2" style={{ color: C.textDim, fontFamily: "Inter" }}>Abmelden</button>

      {onKontoLoeschen && <KontoLoeschenBlock onDelete={onKontoLoeschen} />}
    </div>
  );
}

/* Einem weiteren Verein beitreten - mit dem Konto, das schon angemeldet ist.
 *
 * Vorher gab es diesen Weg nicht. "Weiterem Verein beitreten" fuehrte in die
 * Vereinssuche, die Auswahl in das Anmeldeformular, und dort kostete die
 * erneute Anmeldung die laufende Sitzung, ohne je zu einer Mitgliedschaft zu
 * fuehren: Ueber die Registrierung ging es nicht, weil die E-Mail schon
 * vergeben ist, und ueber die Anmeldung nicht, weil die Mitgliedschaft fehlt.
 * Einem Konto liess sich also kein zweiter Verein hinzufuegen.
 *
 * Gefragt wird nur, was register_for_club braucht. Die E-Mail steht fest, das
 * Passwort ist gesetzt, das Geburtsdatum steht im Profil - danach noch einmal
 * zu fragen, waere Beschaeftigung. */
function BeitrittsScreen({ club, vorschlagName, onBeitreten, goBack }) {
  const [name, setName] = useState(vorschlagName || "");
  const [art, setArt] = useState("mitglied");
  const [team, setTeam] = useState("");
  const [busy, setBusy] = useState(false);
  const [fehler, setFehler] = useState("");

  const senden = async (e) => {
    e.preventDefault();
    if (!name.trim()) { setFehler("Bitte gib deinen Namen an."); return; }
    setBusy(true); setFehler("");
    const ergebnis = await onBeitreten({ name: name.trim(), art, team: team.trim() });
    setBusy(false);
    if (ergebnis?.error) setFehler(ergebnis.error);
  };

  return (
    <AuthShell club={club} footer={<div className="text-center text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}><button onClick={goBack} className="font-bold" style={{ color: C.red }}>Zurück</button></div>}>
      <div className="text-xl mb-1" style={{ fontFamily: "Oswald", fontWeight: 600, color: C.ink }}>Beitritt anfragen</div>
      <div className="text-xs mb-5" style={{ color: C.textDim, fontFamily: "Inter" }}>
        Du bist bereits angemeldet. Für {club?.name || "diesen Verein"} braucht es nur noch deinen Namen — die Vereinsleitung gibt den Beitritt dann frei.
      </div>

      <form onSubmit={senden}>
        <Field icon={User} placeholder="Vor- und Nachname" value={name} onChange={(e) => setName(e.target.value)} />

        <div className="text-xs font-semibold mb-2" style={{ color: C.ink, fontFamily: "Inter" }}>Ich trete bei als</div>
        <div className="grid grid-cols-3 gap-2 mb-4">
          {[{ id: "mitglied", label: "Mitglied", icon: User }, { id: "spieler", label: "Athlet/in", icon: Trophy }, { id: "eltern", label: "Elternteil", icon: Users }].map((typ) => {
            const Icon = typ.icon; const aktiv = art === typ.id;
            return <button type="button" key={typ.id} onClick={() => setArt(typ.id)} className="rounded-xl py-3 px-1 flex flex-col items-center gap-1.5"
              style={{ background: aktiv ? C.fehlerFlaeche : C.paperDim, border: aktiv ? `1px solid ${C.red}` : "1px solid transparent", color: aktiv ? C.red : C.textDim }}><Icon size={17}/><span className="text-[11px] font-bold">{typ.label}</span></button>;
          })}
        </div>

        {/* Die Mannschaften lassen sich hier nicht laden - wer noch kein
            Mitglied ist, darf sie nicht sehen. Also ein Wunsch als Text, den
            die Vereinsleitung beim Freigeben zuordnet. */}
        <Field icon={Users} placeholder="Gewünschte Mannschaft (optional)" value={team} onChange={(e) => setTeam(e.target.value)} />

        {fehler && <div role="status" className="text-[11px] rounded-xl px-3 py-2 mb-3" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{fehler}</div>}

        <button type="submit" disabled={busy} className="w-full py-3 rounded-xl text-sm font-bold" style={{ background: C.ink, color: C.white, fontFamily: "Inter", opacity: busy ? .6 : 1 }}>
          {busy ? "Wird gesendet …" : "Beitritt anfragen"}
        </button>
      </form>
    </AuthShell>
  );
}

function ClubSelectScreen({ clubs, onSelect, goNewClub, goBack, onAbmelden, onKontoLoeschen }) {
  const [query, setQuery] = useState("");
  const filtered = query.trim()
    ? clubs.filter((c) => c.name.toLowerCase().includes(query.trim().toLowerCase()) || c.shortName.toLowerCase().includes(query.trim().toLowerCase()))
    : clubs;

  return (
    <div className="flex flex-col h-full px-6 pt-10 pb-6 overflow-y-auto" style={{ background: C.paper }}>
      <div className="flex flex-col items-center mb-8">
        {/* Marke der App (nicht des Vereins) — dieselbe Glaskachel wie in der
            Öffnungs-Animation, damit Start und Willkommen zusammenpassen. */}
        <div className="flex items-center justify-center mb-4" style={{ width: 76, height: 76, borderRadius: 24, background: "rgba(255,255,255,0.72)", border: "1px solid rgba(255,255,255,0.85)", boxShadow: "0 14px 30px rgba(60,30,45,0.14), inset 0 1px 0 rgba(255,255,255,0.9)" }}>
          <AppBrandMark size={46} />
        </div>
        <div className="text-xl text-center" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>Verein finden</div>
        <div className="text-xs text-center mt-1" style={{ color: C.textDim, fontFamily: "Inter" }}>Suche den Verein, dem du beitreten möchtest.</div>
      </div>

      <div className="flex items-center gap-2 rounded-xl px-3.5 py-3 mb-4" style={{ background: C.paperDim }}>
        <Users size={16} style={{ color: C.textDim, flexShrink: 0 }} />
        {/* Kein autoFocus: Auf dem iPhone wird diese Seite bereits hinter der
            Startanimation aufgebaut. Das Feld zog den Fokus, und iOS klappte
            die Tastatur ueber die noch laufende Animation. Die Tastatur soll
            erst erscheinen, wenn jemand wirklich tippen will. */}
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Verein auswählen …"
          className="flex-1 bg-transparent outline-none text-sm" style={{ fontFamily: "Inter", color: C.ink }} />
      </div>

      <div className="space-y-2 mb-6">
        {filtered.length === 0 ? (
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Kein Verein gefunden.</div>
        ) : filtered.map((c) => (
          <button key={c.id} onClick={() => onSelect(c.id)} className="w-full flex items-center gap-3 rounded-xl px-3 py-2.5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <ClubLogo club={c} size={36} rounded={9} />
            <div className="text-left flex-1">
              <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{c.name}</div>
              <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{c.city} · seit {c.foundedYear}</div>
            </div>
            <ChevronRight size={16} style={{ color: C.textDim, flexShrink: 0 }} />
          </button>
        ))}
      </div>

      <button onClick={goNewClub} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm mb-6" style={{ background: C.ink, color: "#fff", fontFamily: "Inter", fontWeight: 700 }}>
        <UserPlus size={15} /> Neuen Verein registrieren
      </button>

      {/* Nur fuer eine offene Sitzung: Wer hier ohne Anmeldung einen Verein
          sucht, hat kein Konto, das sich abmelden oder loeschen liesse. */}
      {onKontoLoeschen && (
        <div className="mb-4">
          {onAbmelden && <button onClick={onAbmelden} className="w-full py-2.5 text-xs font-bold mb-2" style={{ color: C.textDim, fontFamily: "Inter" }}>Abmelden</button>}
          <KontoLoeschenBlock onDelete={onKontoLoeschen} />
        </div>
      )}

      <div className="mt-auto pt-2 text-center">
        {goBack && <button onClick={goBack} className="text-xs font-bold" style={{ color: C.textDim, fontFamily: "Inter" }}>Zurück</button>}
      </div>
    </div>
  );
}

function ClubColorPicker({ primary, secondary, onChange }) {
  const isCustom = !CLUB_COLOR_PRESETS.some((p) => p.primary === primary && p.secondary === secondary);
  return (
    <div className="mb-3">
      <div className="text-[10px] font-bold mb-1.5 px-0.5" style={{ color: C.textDim }}>VEREINSFARBEN</div>
      <div className="grid grid-cols-2 gap-2 mb-2">
        {CLUB_COLOR_PRESETS.map((preset) => {
          const active = !isCustom && preset.primary === primary && preset.secondary === secondary;
          return (
            <button key={preset.label} type="button" onClick={() => onChange(preset.primary, preset.secondary)}
              className="flex items-center gap-2 px-3 py-2.5 rounded-xl text-xs font-bold text-left"
              style={{ background: active ? C.fehlerFlaeche : C.paperDim, border: active ? `1px solid ${preset.primary}` : "1px solid transparent", color: C.ink }}>
              <span className="flex -space-x-1 flex-shrink-0">
                <span className="w-4 h-4 rounded-full" style={{ background: preset.primary, border: "2px solid #fff" }} />
                <span className="w-4 h-4 rounded-full" style={{ background: preset.secondary, border: "2px solid #fff" }} />
              </span>
              {preset.label}
            </button>
          );
        })}
      </div>
      <div className="flex items-center gap-2 rounded-xl px-3 py-2.5" style={{ background: isCustom ? C.fehlerFlaeche : C.paperDim, border: isCustom ? `1px solid ${primary}` : "1px solid transparent" }}>
        <span className="text-xs font-bold flex-1" style={{ color: C.ink }}>Eigene Farben</span>
        <input aria-label="Primärfarbe" type="color" value={primary} onChange={(e) => onChange(e.target.value, secondary)} className="w-8 h-8 rounded-lg cursor-pointer" style={{ border: "none", padding: 0, background: "none" }} />
        <input aria-label="Sekundärfarbe" type="color" value={secondary} onChange={(e) => onChange(primary, e.target.value)} className="w-8 h-8 rounded-lg cursor-pointer" style={{ border: "none", padding: 0, background: "none" }} />
      </div>
      {hexIsLight(primary) && <div className="text-[10px] mt-1.5 px-0.5" style={{ color: C.ink }}>Hinweis: Bei einer hellen Primärfarbe kann weißer Buttontext schwer lesbar sein.</div>}
    </div>
  );
}

function NewClubScreen({ onCreate, goBack }) {
  const [form, setForm] = useState({ name: "", shortName: "", city: "", registerNumber: "", currency: "EUR", referralCode: "", logoDataUrl: "", sport: "rollhockey", primaryColor: DEFAULT_CLUB_COLORS.primary, secondaryColor: DEFAULT_CLUB_COLORS.secondary });
  const [error, setError] = useState("");
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));

  /* Angemeldet wird der Verein sofort angelegt - und das kann fehlschlagen.
     Vorher war onCreate reine Zustandsaenderung und konnte gar nicht scheitern;
     ohne diese Auswertung bliebe ein Fehler unsichtbar. */
  const [busy, setBusy] = useState(false);
  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim() || !form.shortName.trim() || !form.registerNumber.trim()) { setError("Bitte Vereinsname, Kurzname und Vereinsregisternummer angeben."); return; }
    setBusy(true); setError("");
    const ergebnis = await onCreate({
      id: form.name.trim().toLowerCase().replace(/[^a-z0-9äöüß]+/g, "-").replace(/^-+|-+$/g, "") + "-" + Date.now(),
      name: form.name.trim(),
      shortName: form.shortName.trim().toUpperCase(),
      city: form.city.trim() || "—",
      foundedYear: new Date().getFullYear(),
      registerNumber: form.registerNumber.trim(), currency: form.currency, referralCode: form.referralCode.trim(),
      logoDataUrl: form.logoDataUrl, pendingRegistration: true, sport: form.sport,
      primaryColor: form.primaryColor, secondaryColor: form.secondaryColor,
    });
    setBusy(false);
    if (ergebnis?.error) setError(ergebnis.error);
  };

  return (
    <AuthShell footer={<div className="text-center text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}><button onClick={goBack} className="font-bold" style={{ color: C.red }}>Zurück zur Vereinsauswahl</button></div>}>
      <div className="text-xl mb-1" style={{ fontFamily: "Oswald", fontWeight: 600, color: C.ink }}>Neuen Verein registrieren</div>
      <div className="text-xs mb-5" style={{ color: C.textDim, fontFamily: "Inter" }}>Danach legst du das erste Konto an — es wird automatisch Vereins-Administrator.</div>
      <form onSubmit={submit}>
        <Field icon={Users} placeholder="Vereinsname, z. B. TuS Beispieldorf" value={form.name} onChange={set("name")} />
        <Field icon={ShieldCheck} placeholder="Kurzname, z. B. TUSB" value={form.shortName} onChange={set("shortName")} maxLength={6} />
        <div className="mb-3">
          <div className="text-[10px] font-bold mb-1.5 px-0.5" style={{ color: C.textDim }}>SPORTART</div>
          <select value={form.sport} onChange={set("sport")} className="w-full px-3.5 py-3 rounded-xl text-sm outline-none" style={{ background: C.paperDim, color: C.ink }}>
            {SPORTS.map((s) => <option key={s} value={s}>{sportConfig(s).label}</option>)}
          </select>
        </div>
        <Field icon={MapPin} placeholder="Stadt" value={form.city} onChange={set("city")} />
        <Field icon={Building2} placeholder="Vereinsregisternummer" value={form.registerNumber} onChange={set("registerNumber")} />
        <select value={form.currency} onChange={set("currency")} className="w-full px-3.5 py-3 rounded-xl text-sm mb-3 outline-none" style={{background:C.paperDim,color:C.ink}}><option value="EUR">Euro (€)</option><option value="CHF">Schweizer Franken (CHF)</option><option value="GBP">Britisches Pfund (£)</option><option value="USD">US-Dollar ($)</option><option value="DKK">Dänische Krone</option><option value="NOK">Norwegische Krone</option><option value="SEK">Schwedische Krone</option><option value="PLN">Polnischer Złoty</option><option value="CZK">Tschechische Krone</option></select>
        <Field icon={Gift} placeholder="Empfehlungscode (optional)" value={form.referralCode} onChange={set("referralCode")} />
        <ClubColorPicker primary={form.primaryColor} secondary={form.secondaryColor} onChange={(primaryColor, secondaryColor) => setForm((f) => ({ ...f, primaryColor, secondaryColor }))} />
        <label className="w-full flex items-center justify-between px-3.5 py-3 rounded-xl text-xs mb-3 cursor-pointer" style={{background:C.paperDim,color:C.textDim}}><span>{form.logoDataUrl?"Vereinslogo ausgewählt":"Vereinslogo optional auswählen"}</span><ImageIcon size={16}/><input type="file" accept="image/*" className="hidden" onChange={(e)=>{const file=e.target.files?.[0];if(!file)return;const reader=new FileReader();reader.onload=()=>setForm((old)=>({...old,logoDataUrl:String(reader.result||"")}));reader.readAsDataURL(file);}}/></label>
        {error && <div className="flex items-center gap-1.5 text-xs mb-3" style={{ color: C.red, fontFamily: "Inter" }}><AlertCircle size={13} /> {error}</div>}
        <button type="submit" disabled={busy} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: busy ? .65 : 1 }}>
          {busy ? "Wird angelegt …" : <>Verein anlegen <ArrowRight size={15} /></>}
        </button>
      </form>
    </AuthShell>
  );
}

/* Angemeldet, aber ohne freigegebene Mitgliedschaft. Diese Ansicht existiert
   vor allem wegen Apple-Richtlinie 5.1.1(v): Bisher blieb ein solches Konto auf
   dem Anmeldebildschirm hängen — es war angelegt, aber aus der App heraus nie
   wieder löschbar. Deshalb steht hier neben dem Abmelden auch die Löschung. */
/* Kontoloeschung, ueberall gleich.
 *
 * Bis heute gab es sie nur im PendingAccountScreen. Ein angemeldetes Konto ohne
 * aktive Mitgliedschaft landet aber gar nicht dort, sondern auf der
 * Vereinssuche oder in "Meine Vereine" - und beide hatten keinen Loeschweg:
 *
 *   - "Jetzt registrieren" ohne Verein legt nur das Konto an und fuehrt auf die
 *     Vereinssuche.
 *   - Schon die erste offene Beitrittsanfrage fuehrt auf "Meine Vereine".
 *   - Wird die einzige Mitgliedschaft von einem Vereinsadmin auf inaktiv
 *     gesetzt, faellt das Konto ebenfalls in diesen Zustand.
 *
 * Richtlinie 5.1.1(v) verlangt fuer ein in der App angelegtes Konto einen in
 * der App auffindbaren Loeschweg - und genau der Pruefer, der die Loeschung
 * testet, legt sich vorher ein eigenes Konto an. Er lief also zuverlaessig in
 * die Sackgasse, waehrend die Pruefhinweise ihm das Gegenteil versprachen.
 *
 * Deshalb einmal als Baustein und an allen drei Stellen eingehaengt, statt
 * dreimal abgeschrieben. */
function KontoLoeschenBlock({ onDelete }) {
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const remove = async () => {
    setBusy(true); setError("");
    const result = await onDelete();
    if (result?.error) { setError(result.error); setBusy(false); }
  };

  return (
    <>
      {!confirming ? (
        <button onClick={() => setConfirming(true)} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: C.paperDim, color: C.red }}>Konto und persönliche Daten löschen</button>
      ) : (
        <div className="rounded-2xl p-4" style={{ background: C.fehlerFlaeche, border: `1px solid ${C.fehlerRand}` }}>
          <div className="text-xs font-bold mb-1.5" style={{ color: C.ink }}>Konto endgültig löschen?</div>
          <div className="text-[11px] leading-snug mb-3" style={{ color: C.textDim }}>
            Dein Konto und alle personenbezogenen Daten werden unwiderruflich entfernt. Kosten entstehen dir dadurch keine: Ein persönliches Abonnement gibt es nicht.
          </div>
          <div className="flex gap-2">
            <button onClick={() => setConfirming(false)} disabled={busy} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.paperDim, color: C.ink }}>Abbrechen</button>
            <button onClick={remove} disabled={busy} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.red, color: C.white, opacity: busy ? .6 : 1 }}>{busy ? "Wird gelöscht …" : "Endgültig löschen"}</button>
          </div>
        </div>
      )}
      {error && <div role="status" className="text-[11px] mt-3 rounded-xl px-3 py-2" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{error}</div>}
    </>
  );
}

function PendingAccountScreen({ account, onLeave, onDelete }) {
  const waiting = account.reason === "membership_pending";

  return (
    <div className="flex-1 overflow-y-auto px-6 pt-10 pb-12 flex flex-col justify-center">
      <div className="mx-auto w-full" style={{ maxWidth: 380 }}>
        <div className="flex justify-center mb-6"><AppBrandMark size={64} /></div>
        <div className="rounded-3xl p-5 mb-4" style={{ background: C.glass, border: `1px solid ${C.edge}`, boxShadow: "0 18px 40px rgba(60,30,45,0.08)" }}>
          <div className="text-lg font-bold mb-2" style={{ fontFamily: "Oswald", color: C.ink }}>
            {waiting ? "Warten auf Freigabe" : "Noch keine Mitgliedschaft"}
          </div>
          <div className="text-xs leading-relaxed mb-1" style={{ color: C.textDim }}>
            {waiting
              ? "Dein Konto ist angelegt. Sobald der Verein deine Aufnahme bestätigt, kannst du dich anmelden und alle Funktionen nutzen."
              : "Für dieses Konto besteht in diesem Verein noch keine Mitgliedschaft. Wende dich an die Vereinsverwaltung oder wähle einen anderen Verein."}
          </div>
          <div className="text-[11px]" style={{ color: C.textDim }}>Angemeldet als {account.email}</div>
        </div>

        <button onClick={onLeave} className="w-full py-3 rounded-xl text-sm font-bold mb-2.5" style={{ background: C.ink, color: C.white }}>Abmelden</button>

        <KontoLoeschenBlock onDelete={onDelete} />
      </div>
    </div>
  );
}

function LoginScreen({ onLogin, members, club, goRegister, goChangeClub, offeneSitzung, onSitzungNutzen, verdraengt, onVerdraengtGelesen }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [resetNote, setResetNote] = useState("");
  const [uebernahmeLaeuft, setUebernahmeLaeuft] = useState(false);

  /* Die Mitgliedschaft dieser Sitzung im gerade gewaehlten Verein - falls es
     eine gibt. Nur dann lohnt der Knopf. */
  const eigeneMitgliedschaft = (offeneSitzung?.mitgliedschaften || []).find((m) => m.club_id === club?.id) || null;

  /* Der Knopf "Passwort vergessen?" hatte bisher keine Funktion — wer sein
     Passwort nicht mehr wusste, kam nie wieder in sein Konto.
     Die Rückmeldung ist bewusst gleichlautend, ob die Adresse existiert oder
     nicht: Sonst ließe sich über diesen Weg herausfinden, wer bei euch
     Mitglied ist. */
  const requestReset = async () => {
    setError(""); setResetNote("");
    const address = email.trim();
    /* Beides sind Fehler und gehoerten trotzdem in die gruene Box - die App
       meldete also Erfolg, wo keiner war. */
    if (!address) { setError("Bitte zuerst deine E-Mail-Adresse eintragen."); return; }
    if (!supabase) { setError("Zurücksetzen ist nur mit einem echten Konto möglich."); return; }
    setBusy(true);
    const { error: resetFehler } = await supabase.auth.resetPasswordForEmail(address, {
      redirectTo: `${window.location.origin}/passwort-neu`,
    });
    setBusy(false);
    if (resetFehler) {
      /* Der Rueckgabewert wurde vorher weggeworfen: Kein Netz, eine Bremse
         wegen zu vieler Versuche und ein Serverfehler liefern kein
         geworfenes Ausnahmeobjekt, sondern { error } - die App meldete also
         "Mail ist unterwegs", obwohl nie eine losging. Genau daran hat sich
         am 01.09. jemand eine Stunde lang aufgehalten.

         Verraten wird damit nichts: Ein Transportfehler sagt nichts darueber,
         ob es zu dieser Adresse ein Konto gibt. Deshalb rein technischer
         Wortlaut, und der unscharfe Erfolgssatz bleibt unveraendert. */
      const st = Number(resetFehler.status || 0);
      const tx = String(resetFehler.message || "").toLowerCase();
      setError(
        st === 429 || resetFehler.code === "over_request_rate_limit" || tx.includes("rate limit")
          ? "Zu viele Versuche. Warte einen Moment und versuche es dann noch einmal."
          : st === 0 || tx.includes("failed to fetch") || tx.includes("network") || tx.includes("load failed")
            ? "Keine Verbindung. Prüfe dein Internet und versuche es noch einmal."
            : "Das Zurücksetzen ist gerade nicht möglich. Bitte versuche es in ein paar Minuten noch einmal."
      );
      return;
    }
    setResetNote("Falls ein Konto mit dieser Adresse besteht, ist eine E-Mail mit einem Link unterwegs. Prüfe auch den Spam-Ordner.");
  };

  const submit = async (e) => {
    onVerdraengtGelesen?.();
    e && e.preventDefault();
    setBusy(true);
    const result = await onLogin(email.trim(), password);
    setBusy(false);
    setError(result?.error || "");
  };
  const quick = (m) => { setEmail(m.email); setPassword(m.password); onLogin(m.email, m.password); };

  return (
    <AuthShell
      club={club}
      footer={
        <div className="text-center text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>
          {club ? `Neu bei ${club.shortName}?` : "Noch kein Konto?"}{" "}
          <button onClick={goRegister} className="font-bold" style={{ color: C.red }}>Jetzt registrieren</button>
        </div>
      }
    >
      <div className="flex items-center justify-between mb-5">
        <div className="text-xl" style={{ fontFamily: "Oswald", fontWeight: 600, color: C.ink }}>Willkommen zurück</div>
        {/* "Verein wechseln" gibt es nur, wenn ueberhaupt einer gewaehlt ist.
            Seit die Anmeldung vorn steht, ist das der Ausnahmefall - man kommt
            nur noch ueber die Vereinssuche hierher. */}
        {club && <button onClick={goChangeClub} className="text-[11px] font-bold px-2.5 py-1 rounded-full" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>Verein wechseln</button>}
      </div>
      {/* Besteht schon eine Sitzung und gehoert dieses Konto zu dem Verein, den
          man gerade gewaehlt hat, braucht es keine erneute Anmeldung: ein Tipp,
          und man ist in der Vereinsuebersicht.

          Angezeigt wird ausschliesslich das eigene Konto dieser Sitzung - nicht
          die Mitglieder des Vereins. */}
      {/* Wurde dieses Geraet verdraengt, gehoert der Grund hierher. Sonst steht
          man vor dem Formular und weiss nicht, wieso man wieder hier ist. */}
      {verdraengt && (
        <div className="rounded-xl px-3.5 py-3 mb-5 text-[11px]" style={{ background: C.sekundaerWeich, border: `1px solid ${C.edge}`, color: C.ink, fontFamily: "Inter" }}>
          Dieses Gerät wurde abgemeldet, weil dein Konto inzwischen auf zwei anderen Geräten angemeldet ist. Pro Konto sind zwei Geräte möglich. Melde dich hier wieder an — dann fällt stattdessen das älteste heraus.
        </div>
      )}

      {eigeneMitgliedschaft && (
        <div className="mb-5">
          <div className="text-[10px] uppercase tracking-widest font-semibold mb-2" style={{ color: C.textDim, fontFamily: "Inter" }}>Angemeldet bleiben</div>
          <button
            onClick={async () => {
              setUebernahmeLaeuft(true); setError("");
              const ergebnis = await onSitzungNutzen?.(eigeneMitgliedschaft);
              if (ergebnis?.error) { setError(ergebnis.error); setUebernahmeLaeuft(false); }
            }}
            disabled={uebernahmeLaeuft}
            className="w-full flex items-center gap-3 rounded-xl px-3 py-3"
            style={{ background: C.glass, border: `1px solid ${C.edge}`, opacity: uebernahmeLaeuft ? .6 : 1 }}
          >
            <div className="w-9 h-9 rounded-full flex items-center justify-center text-[11px] font-bold flex-shrink-0" style={{ background: C.red, color: "#fff", fontFamily: "Inter" }}>{initialsOf(eigeneMitgliedschaft.display_name || offeneSitzung?.email || "?")}</div>
            <div className="text-left flex-1 min-w-0">
              <div className="text-xs font-bold truncate" style={{ color: C.ink, fontFamily: "Inter" }}>{eigeneMitgliedschaft.display_name || offeneSitzung?.email}</div>
              <div className="text-[11px] truncate" style={{ color: C.textDim, fontFamily: "Inter" }}>
                {uebernahmeLaeuft ? "Wird geöffnet …" : eigeneMitgliedschaft.status === "pending" ? "Aufnahme noch nicht bestätigt" : "Als dieses Konto fortfahren"}
              </div>
            </div>
            <ArrowRight size={15} style={{ color: C.textDim, flexShrink: 0 }} />
          </button>
          <div className="text-[10px] text-center mt-3 mb-1" style={{ color: C.textDim, fontFamily: "Inter" }}>oder mit einem anderen Konto anmelden</div>
        </div>
      )}

      <form onSubmit={submit}>
        <Field icon={Mail} type="email" placeholder="E-Mail-Adresse" value={email} onChange={(e) => setEmail(e.target.value)} />
        <div className="flex items-center gap-2 rounded-xl px-3.5 py-3 mb-2" style={{ background: C.paperDim }}>
          <Lock size={16} style={{ color: C.textDim, flexShrink: 0 }} />
          <input type={showPw ? "text" : "password"} placeholder="Passwort" value={password} onChange={(e) => setPassword(e.target.value)}
            className="flex-1 bg-transparent outline-none text-sm" style={{ fontFamily: "Inter", color: C.ink }} />
          <button type="button" onClick={() => setShowPw((s) => !s)}>{showPw ? <EyeOff size={15} style={{ color: C.textDim }} /> : <Eye size={15} style={{ color: C.textDim }} />}</button>
        </div>
        {error && <div className="flex items-center gap-1.5 text-xs mb-3" style={{ color: C.red, fontFamily: "Inter" }}><AlertCircle size={13} /> {error}</div>}
        <button type="button" onClick={requestReset} disabled={busy} className="text-xs mb-2 underline" style={{ color: C.textDim, fontFamily: "Inter" }}>Passwort vergessen?</button>
        {resetNote && <div role="status" className="text-[11px] mb-3 rounded-xl px-3 py-2" style={{ background: C.erfolgFlaeche, color: C.erfolg, fontFamily: "Inter" }}>{resetNote}</div>}
        <button type="submit" disabled={busy} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm" style={{ background: C.ink, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: busy ? 0.65 : 1 }}>
          {busy ? "Anmeldung läuft …" : "Anmelden"} {!busy && <ArrowRight size={15} />}
        </button>
      </form>

      {/* Mit angebundener Datenbank gibt es keine Demo-Zugaenge.
          Genau das sollte die Bedingung leisten, tat es aber nicht: Sie fragte
          nur, ob ueberhaupt Mitglieder vorliegen. Im echten Betrieb erschienen
          deshalb die Mitglieder des Vereins als Schnellzugaenge - mit Namen und
          Rollen, noch vor jeder Anmeldung. Angemeldet hat sich damit niemand,
          denn quick() reicht m.password weiter, und das ist bei Mitgliedern aus
          der Datenbank leer. Es blieben also Knoepfe, die reihenweise
          fehlschlagen, und nebenbei eine Mitgliederliste fuer jeden, der die App
          oeffnet. Der fehlende Teil ist die Pruefung auf !supabase. */}
      {!supabase && members.filter((m) => !m.accountPending).length > 0 && <div className="mt-8">
        <div className="text-xs uppercase tracking-widest font-semibold mb-2.5" style={{ color: C.textDim, fontFamily: "Inter" }}>Demo-Zugänge zum Ausprobieren</div>
        <div className="space-y-2">
          {members.filter((m) => !m.accountPending).map((m) => (
            <button key={m.id} onClick={() => quick(m)} className="w-full flex items-center gap-3 rounded-xl px-3 py-2.5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
              <div className="w-8 h-8 rounded-full flex items-center justify-center text-[11px] font-bold flex-shrink-0" style={{ background: m.color, color: "#fff", fontFamily: "Inter" }}>{initialsOf(m.name)}</div>
              <div className="text-left flex-1">
                <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{m.name}</div>
                <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.roles.map((r) => ROLE_META[r].label).join(" · ")}</div>
              </div>
              {isAdmin(m) && <ShieldCheck size={14} style={{ color: C.red }} />}
            </button>
          ))}
        </div>
      </div>}
    </AuthShell>
  );
}


function RegisterScreen({ onRegister, members, club, goLogin }) {
  const [form, setForm] = useState({ name: "", email: "", team: supabase ? "" : TEAMS[0], birthdate: "", password: "", password2: "", accountType: "mitglied", relativeId: "", childName: "", childBirthdate: "", childTeam: "U11" });
  const [legalAccepted, setLegalAccepted] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));
  const [relativeSearch, setRelativeSearch] = useState("");
  const possibleRelatives = members.filter((m) => !m.accountPending && m.id && (
    form.accountType === "eltern" ? m.roles.includes("spieler") : form.accountType === "spieler" ? m.roles.includes("eltern") : false
  )).filter((m) => m.name.toLowerCase().includes(relativeSearch.toLowerCase()));
  /* Ohne vorgewaehlten Verein wird nur das KONTO angelegt. Der Verein kommt
     danach - genau in der Reihenfolge, in der die App seit dem Umbau
     funktioniert: erst anmelden, dann Verein waehlen.
     Vorher fuehrte "Jetzt registrieren" ohne Verein in die Vereinssuche. Das
     war zwar kein Absturz mehr, aber auch nicht das, was der Knopf verspricht:
     Wer ein Konto anlegen will, will ein Formular sehen, keine Vereinsliste. */
  const ohneVerein = !club?.id;
  const isFirstAccount = !ohneVerein && members.length === 0;
  /* Ohne Verein hat dieser Bildschirm keinen Sinn - und ohne diese Absicherung
     auch keinen Bestand: club.name im Untertitel warf einen TypeError, und weil
     es im Projekt keine ErrorBoundary gibt, blieb der ganze Bildschirm weiss. */
  const vereinsName = club?.name || "deinem Verein";

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim() || !form.email.trim() || !form.password || !form.birthdate) { setError("Bitte fülle alle Pflichtfelder aus."); return; }
    if (form.password !== form.password2) { setError("Die Passwörter stimmen nicht überein."); return; }
    if (!ohneVerein && members.some((m) => m.email.toLowerCase() === form.email.trim().toLowerCase())) { setError("Für diese E-Mail existiert bei diesem Verein bereits ein Konto."); return; }
    if (!legalAccepted) { setError("Bitte akzeptiere die Nutzungsbedingungen und die Datenschutzerklärung."); return; }
    setError("");
    const typeRoles = form.accountType === "spieler" ? ["mitglied", "spieler"] : form.accountType === "eltern" ? ["mitglied", "eltern"] : ["mitglied"];
    setBusy(true);
    const result = await onRegister({
      id: "m" + Date.now(),
      clubId: club?.id,
      name: form.name.trim(),
      email: form.email.trim(),
      password: form.password,
      team: form.team,
      number: null,
      since: new Date().getFullYear(),
      roles: isFirstAccount ? ["vereinsadmin", ...typeRoles] : typeRoles,
      color: AVATAR_FARBEN[Math.floor(Math.random() * 6)],
      points: 0,
      tippPoints: 0,
      badges: [],
      birthdate: form.birthdate,
    }, { relativeId: form.relativeId || null, accountType: form.accountType, child: form.accountType === "eltern" && !form.relativeId && form.childName.trim() ? { name: form.childName.trim(), birthdate: form.childBirthdate, team: form.childTeam } : null });
    setBusy(false);
    if (result?.error) setError(result.error);
    if (result?.message) setNotice(result.message);
  };

  return (
    <AuthShell
      club={club}
      footer={<div className="text-center text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Schon Mitglied?{" "}<button onClick={goLogin} className="font-bold" style={{ color: C.red }}>Zum Login</button></div>}
    >
      <div className="text-xl mb-1" style={{ fontFamily: "Oswald", fontWeight: 600, color: C.ink }}>Konto erstellen</div>
      <div className="text-xs mb-5" style={{ color: C.textDim, fontFamily: "Inter" }}>
        {ohneVerein
          ? "Zuerst dein Konto. Deinen Verein suchst du gleich danach aus — oder legst einen neuen an."
          : isFirstAccount ? `Du bist das erste Konto bei ${vereinsName} — automatisch Vereins-Administrator.` : `Für aktive Mitglieder von ${vereinsName}`}
      </div>

      <form onSubmit={submit}>
        <Field icon={User} placeholder="Vor- und Nachname" value={form.name} onChange={set("name")} />
        <Field icon={Mail} type="email" placeholder="E-Mail-Adresse" value={form.email} onChange={set("email")} />
        <Field icon={Cake} type="date" value={form.birthdate} onChange={set("birthdate")} />

        {/* Rolle, Mannschaft und Familienverknuepfung ergeben ohne Verein
            keinen Sinn - danach wird beim Beitritt gefragt. */}
        {!ohneVerein && <>
        <div className="text-xs font-semibold mb-2" style={{ color: C.ink, fontFamily: "Inter" }}>Ich registriere mich als</div>
        <div className="grid grid-cols-3 gap-2 mb-4">
          {[{ id: "mitglied", label: "Mitglied", icon: User }, { id: "spieler", label: "Athlet/in", icon: Trophy }, { id: "eltern", label: "Elternteil", icon: Users }].map((type) => {
            const Icon = type.icon; const active = form.accountType === type.id;
            return <button type="button" key={type.id} onClick={() => setForm((f) => ({ ...f, accountType: type.id, relativeId: "" }))} className="rounded-xl py-3 px-1 flex flex-col items-center gap-1.5"
              style={{ background: active ? C.fehlerFlaeche : C.paperDim, border: active ? `1px solid ${C.red}` : "1px solid transparent", color: active ? C.red : C.textDim }}><Icon size={17}/><span className="text-[11px] font-bold">{type.label}</span></button>;
          })}
        </div>

        {/* Die Mannschaften des Vereins lassen sich hier nicht laden: Die Regel
            auf teams lautet "using (public.is_club_member(club_id))", und wer
            sich gerade erst registriert, ist noch kein Mitglied. Vorher stand
            deshalb die feste Liste TEAMS da - also die Mannschaften des
            Demo-Vereins. Ein Neuling bei einem echten Verein bekam "Herren 1",
            "U15" und "Damen 1" angeboten, die es bei ihm gar nicht gibt, und
            trug sich in eine erfundene Mannschaft ein.
            Ohne Datenbank bleibt die Liste richtig, dort IST der Demo-Verein der
            Verein. Mit Datenbank wird gefragt statt geraten; die Angabe landet
            als Wunsch in requested_team, und die Vereinsverwaltung ordnet bei
            der Freigabe zu. */}
        <div className="flex items-center gap-2 rounded-xl px-3.5 py-3 mb-3" style={{ background: C.paperDim }}>
          <Users size={16} style={{ color: C.textDim, flexShrink: 0 }} />
          {supabase ? (
            <input value={form.team} onChange={set("team")} placeholder="Mannschaft (optional)" className="flex-1 bg-transparent outline-none text-sm" style={{ fontFamily: "Inter", color: C.ink }} />
          ) : (
            <select value={form.team} onChange={set("team")} className="flex-1 bg-transparent outline-none text-sm" style={{ fontFamily: "Inter", color: C.ink }}>
              {TEAMS.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          )}
        </div>
        {supabase && <div className="text-[10px] -mt-2 mb-3 px-1" style={{ color: C.textDim, fontFamily: "Inter" }}>Wenn du sie noch nicht kennst, lass das Feld leer — die Vereinsverwaltung ordnet dich bei der Freigabe zu.</div>}

        {form.accountType !== "mitglied" && <div className="rounded-2xl p-3 mb-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          <div className="text-xs font-bold mb-1" style={{ color: C.ink }}>{form.accountType === "eltern" ? "Kind / Athlet/in verknüpfen" : "Elternteil verknüpfen"}</div>
          <div className="text-[11px] mb-2" style={{ color: C.textDim }}>Ist das Profil bereits vorhanden, suche es hier. Die Verbindung wird automatisch auf beiden Profilen angezeigt.</div>
          <div className="flex items-center gap-2 rounded-xl px-3 py-2 mb-2" style={{ background: C.paperDim }}><Users size={14}/><input value={relativeSearch} onChange={(e)=>setRelativeSearch(e.target.value)} placeholder={form.accountType === "eltern" ? "Athlet/in suchen …" : "Elternteil suchen …"} className="flex-1 bg-transparent outline-none text-xs"/></div>
          {relativeSearch && <div className="space-y-1 mb-2">{possibleRelatives.slice(0,4).map((m)=><button type="button" key={m.id} onClick={()=>setForm((f)=>({...f,relativeId:m.id}))} className="w-full flex items-center justify-between p-2 rounded-lg text-xs" style={{ background: form.relativeId===m.id ? C.fehlerFlaeche : C.paperDim, color:C.ink }}><span>{m.name} · {m.team}</span>{form.relativeId===m.id&&<Check size={13}/>}</button>)}</div>}
          {form.accountType === "eltern" && !form.relativeId && <div className="pt-2" style={{ borderTop:`1px solid ${C.line}` }}>
            <div className="text-[11px] font-bold mb-2" style={{color:C.ink}}>Kind noch nicht registriert? Optional vorläufig anlegen</div>
            <input value={form.childName} onChange={set("childName")} placeholder="Name des Kindes" className="w-full px-3 py-2 rounded-lg text-xs mb-2 outline-none" style={{background:C.paperDim}}/>
            {form.childName && <div className="grid grid-cols-2 gap-2"><input type="date" value={form.childBirthdate} onChange={set("childBirthdate")} className="px-2 py-2 rounded-lg text-xs" style={{background:C.paperDim}}/><select value={form.childTeam} onChange={set("childTeam")} className="px-2 py-2 rounded-lg text-xs" style={{background:C.paperDim}}>{TEAMS.filter(t=>t!=="Eltern / Angehörige").map(t=><option key={t}>{t}</option>)}</select></div>}
          </div>}
        </div>}
        </>}

        <Field icon={Lock} type="password" placeholder="Passwort" value={form.password} onChange={set("password")} />
        <Field icon={Lock} type="password" placeholder="Passwort bestätigen" value={form.password2} onChange={set("password2")} />

        <label className="flex items-start gap-2 mb-3"><input type="checkbox" checked={legalAccepted} onChange={(e) => setLegalAccepted(e.target.checked)} className="mt-0.5"/><span className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>Ich akzeptiere die <a href="/nutzungsbedingungen" target="_blank" rel="noreferrer" style={{ color: C.red, fontWeight: 700 }}>Nutzungsbedingungen</a> und die <a href="/datenschutz" target="_blank" rel="noreferrer" style={{ color: C.red, fontWeight: 700 }}>Datenschutzerklärung</a>.</span></label>

        {error && <div className="flex items-center gap-1.5 text-xs mb-3" style={{ color: C.red, fontFamily: "Inter" }}><AlertCircle size={13} /> {error}</div>}
        {notice && <div className="flex items-center gap-1.5 text-xs mb-3" style={{ color: C.erfolg, fontFamily: "Inter" }}><CheckCircle2 size={13} /> {notice}</div>}

        <button type="submit" disabled={busy || !legalAccepted} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: (busy || !legalAccepted) ? 0.65 : 1 }}>
          <UserPlus size={15} /> {busy ? "Konto wird erstellt …" : "Konto erstellen"}
        </button>
      </form>
      <div className="text-[11px] mt-4 text-center" style={{ color: C.textDim, fontFamily: "Inter" }}>{isSupabaseConfigured ? "Sichere Registrierung über Supabase" : "Demo-Prototyp — es werden keine echten Daten übertragen."}</div>
    </AuthShell>
  );
}

/* ------------------------------------------------------------------ */
/* Dashboard                                                            */
/* ------------------------------------------------------------------ */
/* Gemeinsames Auswahlfeld fuer die Startseite.
   Es stand vorher zweimal im Markup der Spielkachel - einmal im Normalfall,
   einmal im Zweig "kein Spiel geplant". Damit steuerte es auch nur diese eine
   Kachel. Jetzt liegt es einmal ueber beiden Kacheln und gilt fuer Spiel und
   Training zugleich. */
function MannschaftsWahl({ mannschaften, gewaehlt, onWechsel }) {
  if (!mannschaften || mannschaften.length <= 1) return null;
  return (
    <label className="inline-flex items-center gap-1.5 rounded-full pl-3 pr-2 py-1.5 mb-3 cursor-pointer"
      style={{ background: C.glass, border: `1px solid ${C.line}` }}>
      <ListFilter size={13} style={{ color: C.red, flexShrink: 0 }} />
      <select aria-label="Mannschaft filtern" value={gewaehlt} onChange={(e) => onWechsel?.(e.target.value)}
        className="text-[11px] font-bold outline-none appearance-none bg-transparent cursor-pointer pr-4"
        style={{ color: C.ink, fontFamily: "Inter" }}>
        {mannschaften.map((m) => <option key={m} value={m} style={{ color: C.ink }}>{m}</option>)}
      </select>
      <ChevronDown size={13} style={{ color: C.textDim, marginLeft: -14, pointerEvents: "none" }} />
    </label>
  );
}
function Scoreboard({ nextEvent, goTo, auswahlVorhanden = false }) {
  const { d, h, m } = useCountdown(nextEvent ? nextEvent.date : "2099-01-01T00:00:00");
  const digit = (n) => String(n).padStart(2, "0");
  /* Ohne Auswahl verschwindet die Kachel, wenn kein Spiel ansteht - ein Hinweis
     "keine Termine geplant" waere falsch, denn Training und anderes stecken in
     eigenen Kacheln.
     Steht eine Auswahl zur Verfuegung, bleibt die Kachel dagegen stehen und
     sagt, dass fuer diese Mannschaft nichts geplant ist. Sonst wirkte ein
     Wechsel auf eine spielfreie Mannschaft wie ein Fehler. */
  if (!nextEvent && !auswahlVorhanden) return null;

  if (!nextEvent) {
    return (
      <div className="rounded-3xl p-5 mb-6 relative overflow-hidden" style={{ background: `linear-gradient(160deg, color-mix(in srgb, ${C.red} 82%, #fff) 0%, ${C.red} 100%)` }}>
        <div className="relative flex items-center justify-between mb-4">
          <span className="text-[10px] font-extrabold uppercase px-3.5 py-1.5 rounded-full" style={{ fontFamily: "Inter", letterSpacing: "0.14em", color: "#fff", background: "rgba(255,255,255,0.18)" }}>Nächstes Spiel</span>
        </div>
        <div className="relative text-white text-sm" style={{ fontFamily: "Inter" }}>Für diese Mannschaft ist derzeit kein Spiel geplant.</div>
      </div>
    );
  }

  return (
    <div className="rounded-3xl p-5 mb-6 relative overflow-hidden cursor-pointer" style={{ background: `linear-gradient(160deg, color-mix(in srgb, ${C.red} 82%, #fff) 0%, ${C.red} 55%, ${C.redDark} 100%)`, boxShadow: `0 22px 46px color-mix(in srgb, ${C.red} 34%, transparent), inset 0 1px 0 rgba(255,255,255,0.35)` }} onClick={goTo}>
      <div className="absolute pointer-events-none" style={{ top: "-40%", left: "-10%", width: "80%", height: "100%", background: "radial-gradient(circle, rgba(255,255,255,0.28), transparent 65%)" }} />
      <div className="relative flex items-center justify-between mb-4">
        <span className="text-[10px] font-extrabold uppercase px-3.5 py-1.5 rounded-full" style={{ fontFamily: "Inter", letterSpacing: "0.14em", color: "#fff", background: "rgba(255,255,255,0.22)", border: "1px solid rgba(255,255,255,0.3)" }}>Nächstes Spiel</span>
        <span className="text-xs" style={{ color: "rgba(255,255,255,0.85)", fontFamily: "Inter" }}>{formatDate(nextEvent.date)} · {formatTime(nextEvent.date)}</span>
      </div>
      <div className="relative text-white text-xl mb-1.5" style={{ fontFamily: "Oswald", fontWeight: 700, letterSpacing: "-0.01em" }}>{nextEvent.title}</div>
      <div className="relative flex items-center gap-1.5 mb-5 text-xs" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "Inter" }}><MapPin size={12} /> {nextEvent.location}</div>
      <div className="relative flex items-center gap-2">
        {[["TAGE", d], ["STD", h], ["MIN", m]].map(([label, val], i) => (
          <React.Fragment key={label}>
            <div className="flex flex-col items-center rounded-2xl px-3.5 py-2.5 flex-1" style={{ background: "rgba(255,255,255,0.16)", border: "1px solid rgba(255,255,255,0.26)", backdropFilter: "blur(6px)", WebkitBackdropFilter: "blur(6px)" }}>
              <div className="text-2xl font-bold" style={{ fontFamily: "JetBrains Mono", color: "#fff", lineHeight: 1 }}>{digit(val)}</div>
              <div className="text-[9px] mt-1.5 tracking-[0.16em]" style={{ color: "rgba(255,255,255,0.75)", fontFamily: "Inter", fontWeight: 600 }}>{label}</div>
            </div>
            {i < 2 && <span className="text-lg pb-3" style={{ color: "rgba(255,255,255,0.55)", fontFamily: "JetBrains Mono" }}>:</span>}
          </React.Fragment>
        ))}
      </div>
    </div>
  );
}
function PollWidget({ poll, userId, setPolls, onVote }) {
  const options = poll.options;
  const voted = poll.voterIds?.includes(userId);
  const total = options.reduce((a, o) => a + o.votes, 0);
  const [fehler, setFehler] = useState("");
  /* Erst schreiben, dann anzeigen - und bei einem Fehler zuruecknehmen.
     Vorher landete die Stimme im Arbeitsspeicher, den nur Administratoren
     speicherten: Das Mitglied sah seinen Haken, die Umfrage bekam ihn nie. */
  const vote = async (i) => {
    if (voted) return;
    const option = options[i];
    setPolls((ps)=>ps.map((p)=>p.id===poll.id?{...p,options:p.options.map((x,idx)=>idx===i?{...x,votes:x.votes+1}:x),voterIds:[...(p.voterIds||[]),userId],meineAntwortId:option?.id||null}:p));
    const ergebnis = await onVote?.(poll.id, option?.id);
    if (ergebnis?.error) {
      setFehler(ergebnis.error);
      setPolls((ps)=>ps.map((p)=>p.id===poll.id?{...p,options:p.options.map((x,idx)=>idx===i?{...x,votes:Math.max(0,x.votes-1)}:x),voterIds:(p.voterIds||[]).filter((v)=>v!==userId),meineAntwortId:null}:p));
    }
  };
  return (
    <div className="rounded-2xl p-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
      <div className="flex items-center gap-2 mb-3">
        <div className="rounded-full p-1.5" style={{ background: C.paperDim }}><Megaphone size={14} style={{ color: C.red }} /></div>
        <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{poll.title}</div>
      </div>
      <div className="space-y-2">
        {options.map((o, i) => {
          const pct = total ? Math.round((o.votes / total) * 100) : 0;
          return (
            <button key={o.label} onClick={() => vote(i)} className="w-full text-left relative overflow-hidden rounded-lg" style={{ border: `1px solid ${C.line}`, cursor: voted ? "default" : "pointer" }}>
              {voted && <div className="absolute inset-y-0 left-0" style={{ width: `${pct}%`, background: C.paperDim, transition: "width .4s" }} />}
              <div className="relative flex items-center justify-between px-3 py-2 text-sm" style={{ fontFamily: "Inter", color: C.ink }}>
                <span className="flex items-center gap-2 font-medium">{o.label}</span>
                {voted && <span className="text-xs" style={{ color: C.textDim }}>{pct}% · {o.votes}</span>}
              </div>
            </button>
          );
        })}
      </div>
      {!voted && <div className="text-xs mt-2" style={{ color: C.textDim, fontFamily: "Inter" }}>Tippe, um abzustimmen</div>}
    </div>
  );
}
/* Naechstes Training der gewaehlten Mannschaft.
   Frueher hing die Kachel an zwei Bedingungen, die sie fast immer verhinderten:
   der Rolle "spieler" und einer hinterlegten Jugendklasse. Fuer Herren 1 gibt
   es keine Jugendklasse - die Kachel blieb dort immer aus. Und gerechnet wurde
   mit dem Demo-Feld, nicht mit den echten Terminen.
   Danach hing sie an user.team, also an einer einzigen Mannschaft, die mit der
   Auswahl oben nichts zu tun hatte. Jetzt folgt sie derselben Auswahl wie das
   Spiel. */
function NextTrainingCard({ training, team, auswahlVorhanden = false }) {
  const { d, h, m } = useCountdown(training ? training.date : "2099-01-01T00:00:00");
  const digit = (n) => String(n).padStart(2, "0");
  /* Wie bei der Spielkachel: ohne Auswahl still verschwinden, mit Auswahl
     sagen, dass fuer diese Mannschaft nichts eingetragen ist. */
  if (!training && !auswahlVorhanden) return null;
  if (!training) {
    return (
      <div className="rounded-3xl p-5 mb-6 relative overflow-hidden" style={{ background: `linear-gradient(160deg, var(--club-secondary-light) 0%, var(--club-secondary) 100%)` }}>
        <div className="relative text-[10px] uppercase font-bold mb-2.5" style={{ color: "rgba(255,255,255,0.82)", fontFamily: "Inter", letterSpacing: "0.14em" }}>Nächstes Training{team ? ` · ${team}` : ""}</div>
        <div className="relative text-white text-sm" style={{ fontFamily: "Inter" }}>Für diese Mannschaft ist derzeit kein Training geplant.</div>
      </div>
    );
  }
  return (
    <div className="rounded-3xl p-5 mb-6 relative overflow-hidden" style={{ background: `linear-gradient(160deg, var(--club-secondary-light) 0%, var(--club-secondary) 55%, var(--club-secondary-dark) 100%)`, boxShadow: "0 22px 46px rgba(20,21,26,0.22), inset 0 1px 0 rgba(255,255,255,0.3)" }}>
      <div className="absolute pointer-events-none" style={{ top: "-40%", left: "-10%", width: "80%", height: "100%", background: "radial-gradient(circle, rgba(255,255,255,0.24), transparent 65%)" }} />
      {/* Hier stand `info.youthClass?.name` - ein Feld, das es auf dem Objekt nie
          gab. Angezeigt wurde deshalb dauerhaft "Nächstes Training · " mit
          haengendem Trennzeichen. Gemeint war die Mannschaft. */}
      <div className="relative text-[10px] uppercase font-bold mb-2.5" style={{ color: "rgba(255,255,255,0.82)", fontFamily: "Inter", letterSpacing: "0.14em" }}>Nächstes Training{team ? ` · ${team}` : ""}</div>
      <div className="relative text-white text-xl mb-1.5" style={{ fontFamily: "Oswald", fontWeight: 700, letterSpacing: "-0.01em" }}>{formatDate(training.date)} · {formatTime(training.date)}</div>
      <div className="relative flex items-center gap-1.5 text-xs mb-5" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "Inter" }}><MapPin size={12} /> {training.location}</div>
      <div className="relative flex items-center gap-2">
        {[["TAGE", d], ["STD", h], ["MIN", m]].map(([label, val], i) => (
          <React.Fragment key={label}>
            <div className="flex flex-col items-center rounded-2xl px-3.5 py-2.5 flex-1" style={{ background: "rgba(255,255,255,0.16)", border: "1px solid rgba(255,255,255,0.26)", backdropFilter: "blur(6px)", WebkitBackdropFilter: "blur(6px)" }}>
              <div className="text-2xl font-bold" style={{ fontFamily: "JetBrains Mono", color: "#fff", lineHeight: 1 }}>{digit(val)}</div>
              <div className="text-[9px] mt-1.5 tracking-[0.16em]" style={{ color: "rgba(255,255,255,0.75)", fontFamily: "Inter", fontWeight: 600 }}>{label}</div>
            </div>
            {i < 2 && <span className="text-lg pb-3" style={{ color: "rgba(255,255,255,0.55)", fontFamily: "JetBrains Mono" }}>:</span>}
          </React.Fragment>
        ))}
      </div>
    </div>
  );
}
function Dashboard({ user, members, events, feePaid, channels, news, dutyPlan, seasonVotes, tippPredictions, tippResults, polls, setPolls, onVote, werbeplaetze, onSponsorImpression, onSponsorClick, goEvents, goSeason, goTipp, goDuty, goNews, goTasks, goVehicles, currentClub, featureEnabled, dashboardTileOrder, entitlement, goSubscribe, mannschaften = [], gewaehlteMannschaft = "", onMannschaftWechsel }) {
  const sport = currentClub?.sport || "rollhockey";
  /* Alle Kacheln in „Aktionen & Abstimmungen" hängen am Premium-Tarif
     (siehe die LockedFeature-Hüllen der jeweiligen Ansichten). Während der
     Tarif noch geladen wird, zeigen wir kein Schloss — sonst blitzt es kurz
     bei Mitgliedern auf, die die Funktionen längst freigeschaltet haben. */
  const featureLocked = !entitlement.loading && entitlement.tier === "none";
  /* Naechste Termine aus den echten Daten, nicht mehr aus dem Demo-Feld.
     Ohne hinterlegte Mannschaft gibt es nichts anzuzeigen - dann bleibt die
     Kachel weg, statt einen fremden Termin zu zeigen. */
  const kommende = (events || []).filter((e) => !e.cancelled && e.team && new Date(e.date) > new Date())
    .sort((a, b) => new Date(a.date) - new Date(b.date));

  /* Die Mannschaftswahl kommt als Prop von oben. Sie steuert beide Kacheln -
     Spiel und Training - und ueberlebt den Reiterwechsel, was sie als
     Zustand dieser Komponente nicht tut (siehe key= am Container). */

  /* Kein Rueckfall mehr auf getNextMatch(): Das las die Demo-Konstante EVENTS und
     zeigte einem echten Verein damit ein Spiel, das es bei ihm nie gab. Findet
     sich kein Spiel, blendet Scoreboard die Kachel selbst aus. */
  const nextEvent = kommende.find((e) => e.type === "spiel" && e.team === gewaehlteMannschaft) || null;

  /* Geburtstage aus den echten Mitgliedern, nicht aus einer Liste im Quelltext.
     Verglichen werden nur Tag und Monat; fehlt das Geburtsdatum, faellt das
     Mitglied heraus. Ohne Treffer erscheint die Zeile gar nicht. */
  const heute = new Date();
  const geburtstageHeute = (members || [])
    /* showBirthday ist die Einstellung "Geburtstag im Verein anzeigen" aus dem
       Profil. Wer sie abwaehlt, taucht hier nicht auf. Fehlt das Feld - etwa bei
       aelteren Datensaetzen -, gilt die Voreinstellung der Oberflaeche, also
       sichtbar. */
    .filter((m) => m.birthdate && !m.accountPending && m.showBirthday !== false)
    .filter((m) => {
      const tag = new Date(m.birthdate);
      return tag.getDate() === heute.getDate() && tag.getMonth() === heute.getMonth();
    })
    .map((m) => (m.team && m.team !== "Mitglied" ? `${m.name} (${m.team})` : m.name));
  /* Training und Spiel folgen derselben Auswahl. Vorher hing das Training an
     user.team - also an einer einzigen, willkuerlich gewaehlten Mannschaft:
     Wer die Auswahl oben auf die U17 stellte, sah weiter das Training der
     Herren 2. Und wer gar keine Zuordnung hat, bei dem ist user.team
     "Mitglied" - dann fand die Zeile nie etwas und die Kachel blieb immer aus. */
  const naechstesTraining = kommende.find((e) => e.type === "training" && e.team === gewaehlteMannschaft);
  const newsMsgs = (news || []).slice(-2).reverse();

  const seasonClosed = new Date() > new Date(SEASON_VOTE_DEADLINE);
  /* Ohne Kandidaten bleibt sorted leer. Das ?. verhindert zwar den Absturz,
     aber undefined landete in der Zeichenkette - auf der Kachel stand woertlich
     "🏆 undefined", sobald die Frist verstrichen war. Die beiden anderen
     Ansichten fangen den leeren Fall ab, diese hier war uebersehen. */
  const seasonSieger = seasonResults(seasonVotes, saisonKandidaten(members)).sorted[0];
  const seasonSubtitle = !seasonClosed
    ? `Bis ${new Date(SEASON_VOTE_DEADLINE).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" })} abstimmen`
    : seasonSieger ? `🏆 ${seasonSieger.name}` : "Keine Kandidat/innen hinterlegt";

  /* Dieselbe Rechnung wie in der Tippansicht.
     Vorher stand hier member.tippPoints - ein Feld, das aus der Datenbank
     geladene Mitglieder immer mit 0 bekommen und das nur in der Sitzung dessen
     neu berechnet wird, der gerade ein Ergebnis eintraegt. Nach jedem Neuladen
     stand deshalb bei allen 0, und die Kachel zeigte "Platz 1 von 24" fuer
     jeden, der zufaellig oben in der Liste stand. */
  const tippBegegnungenJetzt = tippBegegnungen(events);
  const leaderboard = [...members]
    .map((m) => ({ ...m, punkte: totalTippPoints(m.id, tippPredictions, tippResults, tippBegegnungenJetzt) }))
    .sort((a, b) => b.punkte - a.punkte);
  const myRank = leaderboard.findIndex((m) => m.id === user.id) + 1;
  const tippSubtitle = `Platz ${myRank} von ${leaderboard.length}`;
  /* Der Anteil in Prozent, sobald der Hinweis faellig ist - sonst null. Vorher
     stand hier ein blosses true und im Text eine feste 70. Angezeigt wurde damit
     immer "Schon 70%", auch wenn sich laengst neunzig Prozent eingetragen
     hatten. Jetzt steht dort die tatsaechliche Quote. */
  const [taskReminder, setTaskReminder] = useState(null);
  useEffect(() => {
    const databaseMembership = !!supabase && isDbId(user.id);
    if (!databaseMembership || !user.clubId) return;
    const checkReminder = async () => {
      const { data: ratio } = await supabase.rpc("get_task_signup_ratio", { target_club: user.clubId });
      if ((ratio || 0) < 0.7) return;
      const { data: mine } = await supabase.from("club_task_signups").select("id").eq("membership_id", user.id).limit(1);
      if (!mine || mine.length === 0) setTaskReminder(Math.round((ratio || 0) * 100));
    };
    checkReminder();
  }, [user.id, user.clubId]);

  let dutySubtitle = isFormalMember(user) ? "Theke, Grill, Kuchenbuffet …" : "Nur für Vereinsmitglieder";
  if (isFormalMember(user)) {
    let assigned = null;
    Object.entries(dutyPlan).forEach(([eid, stations]) => {
      Object.entries(stations).forEach(([station, list]) => { if (list.includes(user.id)) assigned = { eid, station }; });
    });
    /* Der Termin kommt aus den echten Vereinsterminen. Vorher wurde er in der
       Demo-Konstante EVENTS gesucht - bei einem echten Verein fand sich dort
       nichts, und hinter der Station stand "Invalid Date". Die Kennung kann je
       nach Herkunft Zahl oder Text sein, deshalb der Vergleich ueber String().

       Die Suche MUSS hinter der Pruefung auf assigned stehen. Stand sie davor,
       las der Callback assigned.eid fuer jeden Termin - und assigned ist null,
       solange man in keinen Helferdienst eingeteilt ist, also im Normalfall.
       Das warf beim Rendern der Startseite und liess sie weiss. */
    const zugehoeriger = assigned ? (events || []).find((e) => String(e.id) === String(assigned.eid)) : null;
    dutySubtitle = assigned && zugehoeriger ? `${assigned.station} · ${formatDate(zugehoeriger.date)}` : assigned ? assigned.station : "Jetzt eintragen";
  }

  return (
    <div className="px-4 pt-4 pb-24">
      <div className="flex items-start justify-between mb-4">
        <div>
          <div className="mb-1" style={{ fontFamily: "Inter", color: C.textDim, fontSize: 13 }}>Willkommen zurück,</div>
          <div style={{ fontFamily: "Oswald", fontWeight: 700, fontSize: 24, color: C.ink }}>{user.name.split(" ")[0]} 👋</div>
        </div>
        <ClubLogo club={currentClub} size={44} rounded={12} />
      </div>


      <SponsorSlot slotKey="dashboard_top" bookings={werbeplaetze} onImpression={onSponsorImpression} onClick={onSponsorClick} visible={featureEnabled("sponsor_dashboard_top")} />

      {/* Ein Auswahlfeld fuer beide Kacheln - vorher steckte es in der
          Spielkachel und liess das Training unberuehrt. */}
      <MannschaftsWahl mannschaften={mannschaften} gewaehlt={gewaehlteMannschaft} onWechsel={onMannschaftWechsel} />
      <Scoreboard nextEvent={nextEvent} goTo={goEvents} auswahlVorhanden={mannschaften.length > 1} />
      <NextTrainingCard training={naechstesTraining} team={gewaehlteMannschaft} auswahlVorhanden={mannschaften.length > 1} />

      {taskReminder !== null && (
        <div className="flex items-center gap-2 rounded-xl px-3 py-2.5 mb-5" style={{ background: C.primaerWeich, border: `1px solid ${C.edge}` }}>
          <ClipboardList size={16} style={{ color: C.red }} />
          <div className="text-sm flex-1" style={{ fontFamily: "Inter", color: C.ink }}>Schon <b>{taskReminder}%</b> haben sich für Aufgaben eingetragen. Hilf mit! <button onClick={goTasks} className="underline font-bold">Jetzt eintragen</button></div>
        </div>
      )}
      {geburtstageHeute.length > 0 && (
        <div className="flex items-center gap-2 rounded-xl px-3 py-2.5 mb-5" style={{ background: C.sekundaerWeich, border: `1px solid ${C.edge}` }}>
          <Cake size={16} style={{ color: C.secondary }} />
          <div className="text-sm" style={{ fontFamily: "Inter", color: C.ink }}><b>Heute Geburtstag:</b> {geburtstageHeute.join(" · ")} 🎉</div>
        </div>
      )}

      <DashboardSection accent={C.red} background={C.primaerWeich}>
        <SectionTitle eyebrow="Mitmachen" title="Aktionen & Abstimmungen" />
        <div>
          {resolveDashboardTileOrder(dashboardTileOrder).map((tileKey) => {
            switch (tileKey) {
              case "season_award":
                return featureEnabled("season_award") && <FeatureRow key={tileKey} icon={Trophy} title="Athlet/in der Saison" subtitle={seasonSubtitle} onClick={goSeason} accent={C.secondary} locked={featureLocked} />;
              case "tippspiel":
                return featureEnabled("tippspiel") && <FeatureRow key={tileKey} icon={Target} title="Tippspiel" subtitle={tippSubtitle} onClick={goTipp} accent={C.red} locked={featureLocked} />;
              case "duty_roster":
                return featureEnabled("duty_roster") && <FeatureRow key={tileKey} icon={ClipboardList} title="Helferplanung" subtitle={dutySubtitle} onClick={goDuty} accent={C.secondary} locked={featureLocked} />;
              case "tasks":
                return <FeatureRow key={tileKey} icon={ClipboardList} title="Aufgaben" subtitle="Für den Verein mithelfen" onClick={goTasks} accent={C.red} locked={featureLocked} />;
              case "vehicle_booking":
                return featureEnabled("vehicle_booking") && <FeatureRow key={tileKey} icon={Car} title={sportConfig(sport).vehicleTabLabel} subtitle="Kalender & Buchung" onClick={goVehicles} accent={C.secondary} locked={featureLocked} />;
              default:
                return null;
            }
          })}
        </div>
      </DashboardSection>

      <DashboardSection accent={C.red} background={C.primaerWeich}>
        <SectionTitle eyebrow="Vereins-News" title="Neueste Nachrichten" right={goNews ? <button onClick={goNews} className="text-xs font-bold" style={{ color: C.red, fontFamily: "Inter" }}>Alle ansehen</button> : null} />
        <div className="rounded-2xl px-3" style={{ background: "rgba(255,255,255,0.82)", border: `1px solid ${C.white}` }}>
        {newsMsgs.length === 0 ? (
          <div className="text-xs py-3" style={{ color: C.textDim, fontFamily: "Inter" }}>Noch keine News.</div>
        ) : newsMsgs.map((m, i) => (
          <div key={i} className="py-3" style={{ borderBottom: i < newsMsgs.length - 1 ? `1px solid ${C.line}` : "none" }}>
            <div className="text-[11px] mb-1" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.who} · {m.time}</div>
            {m.imageUrl && <img src={m.imageUrl} alt="" className="w-full rounded-xl mb-2" style={{ maxHeight: 140, objectFit: "cover" }} />}
            {m.title && <div className="text-sm mb-0.5" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{m.title}</div>}
            <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: m.title ? 400 : 600, color: m.title ? C.textDim : C.ink }}>{m.text}</div>
          </div>
        ))}
        </div>
      </DashboardSection>

      <SponsorSlot slotKey="dashboard_bottom" bookings={werbeplaetze} onImpression={onSponsorImpression} onClick={onSponsorClick} visible={featureEnabled("sponsor_dashboard_bottom")} />

      {/* Die Abstimmungen erscheinen nur, wenn es welche gibt. Vorher stand die
          Ueberschrift auch dann da, wenn der Verein keine einzige angelegt hat. */}
      {polls.some((p) => p.active) && (
        <DashboardSection accent={C.secondary} background={C.sekundaerWeich}>
          <SectionTitle eyebrow="Mitmachen" title="Deine Stimme zählt" />
          <div className="space-y-3">{polls.filter((p)=>p.active).map((poll)=><PollWidget key={poll.id} poll={poll} userId={user.id} setPolls={setPolls} onVote={onVote}/>)}</div>
        </DashboardSection>
      )}

      {/* Hier stand ein Block "Unsere Sponsoren" mit fuenf fest verdrahteten
          Firmennamen aus dem Demo-Datensatz - Sparkasse Iserlohn, Stadtwerke
          Iserlohn und weitere. Jeder echte Verein bekam fremde Unternehmen als
          seine eigenen Partner angezeigt. Werbung schaltet ohnehin nur der
          Betreiber ueber die Sponsor-Slots, deshalb ist der Block ersatzlos
          entfallen. */}

    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Helferplanung (wiederverwendbar: Event-Karte, Helferplanung-Tab, Admin) */
/* ------------------------------------------------------------------ */
/* Ein- und Austragen in einen Helferdienst.
 *
 * Der Eintrag geht in die Tabelle duty_assignments. Vorher lag der ganze
 * Helferplan im gemeinsamen Zustandsblock, den nur Administratoren schreiben -
 * wer sich als Mitglied eintrug, sah seinen Namen und war beim naechsten
 * Oeffnen wieder draussen. */
function toggleHelperSelf(setDutyPlan, eventId, station, userId, onSetzen) {
  setDutyPlan((dp) => {
    const plan = dp[eventId] || {};
    const list = plan[station] || [];
    const already = list.includes(userId);
    let nextList;
    if (already) nextList = list.filter((id) => id !== userId);
    else { if (list.length >= STATION_CAP) return dp; nextList = [...list, userId]; }
    /* Schlaegt das Schreiben fehl, wird die Anzeige zurueckgenommen. Sonst
       stuende dort ein Name, den die Datenbank nie angenommen hat. */
    Promise.resolve(onSetzen?.(eventId, station, userId, !already)).then((r) => {
      if (r?.error) setDutyPlan((jetzt) => ({ ...jetzt, [eventId]: { ...(jetzt[eventId] || {}), [station]: list } }));
    });
    return { ...dp, [eventId]: { ...plan, [station]: nextList } };
  });
}
function HelperSlots({ ev, members, currentUser, dutyPlan, setDutyPlan, eligible, onSetzen }) {
  const plan = dutyPlan[ev.id] || {};
  return (
    <div className="space-y-2">
      {ev.helperSlots.map((station) => {
        const list = plan[station] || [];
        const names = list.map((id) => members.find((m) => m.id === id)?.name).filter(Boolean);
        const imIn = list.includes(currentUser.id);
        const full = list.length >= STATION_CAP;
        return (
          <div key={station} className="flex items-center justify-between px-3 py-2 rounded-lg" style={{ background: C.paper }}>
            <div>
              <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{station}</div>
              <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{names.length ? names.join(", ") : "Noch niemand eingetragen"} · {list.length}/{STATION_CAP}</div>
            </div>
            {eligible && (
              <button onClick={() => toggleHelperSelf(setDutyPlan, ev.id, station, currentUser.id, onSetzen)} disabled={!imIn && full}
                className="px-2.5 py-1 rounded-full text-[11px] flex-shrink-0"
                style={{ fontFamily: "Inter", fontWeight: 700, background: imIn ? C.secondary : full ? C.paperDim : C.ink, color: imIn ? "#fff" : full ? C.textDim : "#fff" }}>
                {imIn ? "Eingetragen ✓" : full ? "Voll" : "Übernehmen"}
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Events                                                               */
/* ------------------------------------------------------------------ */
function CarpoolSection({ ev, currentUser }) {
  const [carpools, setCarpools] = useState([]);
  const [abfahrt, setAbfahrt] = useState("");
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [seats, setSeats] = useState("");
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const load = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase.from("carpools")
      .select("id,seats_available,note,departure,driver_membership_id,club_memberships(display_name),carpool_passengers(membership_id,club_memberships(display_name))")
      .eq("event_id", ev.id)
      .order("created_at", { ascending: true });
    if (error) { setLoading(false); return; }
    setCarpools((data || []).map((row) => {
      const driver = Array.isArray(row.club_memberships) ? row.club_memberships[0] : row.club_memberships;
      const passengers = (row.carpool_passengers || []).map((p) => {
        const m = Array.isArray(p.club_memberships) ? p.club_memberships[0] : p.club_memberships;
        return { membershipId: p.membership_id, name: m?.display_name || "—" };
      });
      return { id: row.id, seats: row.seats_available, departure: row.departure, note: row.note, driverId: row.driver_membership_id, driverName: driver?.display_name || "—", passengers };
    }));
    setLoading(false);
  }, [ev.id]);
  useEffect(() => { load(); }, [load]);
  const createCarpool = async () => {
    const seatCount = Number(seats);
    if (!Number.isFinite(seatCount) || seatCount < 1) { setMessage("Bitte eine gültige Anzahl freier Plätze angeben."); return; }
    /* Beide Pflichtfeldpruefungen stehen VOR setSaving(true). Die zweite stand
       vorher darunter und stieg mit return aus, ohne saving zurueckzusetzen:
       Der Knopf blieb deaktiviert und zeigte "…" - ausgerechnet nachdem die
       App per roter Meldung genau die Eingabe verlangt hatte, die sie danach
       nicht mehr annehmen konnte. */
    if (!abfahrt.trim()) { setMessage("Bitte gib an, von wo du losfährst."); return; }
    setSaving(true); setMessage("");
    const { error } = await supabase.from("carpools").insert({ event_id: ev.id, driver_membership_id: currentUser.id, seats_available: seatCount, departure: abfahrt.trim(), note: note.trim() || null });
    if (error) { setMessage("Fahrgemeinschaft konnte nicht angelegt werden."); setSaving(false); return; }
    setSeats(""); setNote(""); setAbfahrt(""); setShowCreate(false); setSaving(false);
    await load();
  };
  const join = async (carpoolId) => {
    setMessage("");
    const { error } = await supabase.from("carpool_passengers").insert({ carpool_id: carpoolId, membership_id: currentUser.id });
    if (error) { setMessage("Eintragen nicht möglich (evtl. schon voll)."); return; }
    await load();
  };
  const leave = async (carpoolId) => {
    setMessage("");
    const { error } = await supabase.from("carpool_passengers").delete().eq("carpool_id", carpoolId).eq("membership_id", currentUser.id);
    if (error) { setMessage("Konnte nicht entfernt werden."); return; }
    await load();
  };
  const removeCarpool = async (carpoolId) => {
    if (!window.confirm("Fahrgemeinschaft wirklich entfernen?")) return;
    setMessage("");
    const { error } = await supabase.from("carpools").delete().eq("id", carpoolId);
    if (error) { setMessage("Konnte nicht entfernt werden."); return; }
    await load();
  };
  return (
    <div className="mt-2 mb-1">
      <div className="text-xs font-semibold mb-2 flex items-center gap-1.5" style={{ fontFamily: "Inter", color: C.ink }}><Car size={14}/> Fahrgemeinschaft</div>
      {loading ? <div className="text-[11px]" style={{ color: C.textDim }}>Wird geladen …</div> : <>
        <div className="space-y-1.5 mb-2">
          {carpools.map((c) => {
            const isDriver = c.driverId === currentUser.id;
            const isPassenger = c.passengers.some((p) => p.membershipId === currentUser.id);
            const free = c.seats - c.passengers.length;
            return (
              <div key={c.id} className="rounded-xl px-3 py-2" style={{ background: C.paperDim }}>
                <div className="flex items-center justify-between mb-1">
                  <div className="text-xs font-bold" style={{ color: C.ink }}>{c.driverName} fährt{isDriver ? " (du)" : ""}</div>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded-full" style={{ background: free > 0 ? C.erfolgFlaeche : C.fehlerFlaeche, color: free > 0 ? C.erfolg : C.fehler }}>{free > 0 ? `${free} frei` : "voll"}</span>
                </div>
                {c.departure && <div className="text-[10px] mb-1 flex items-start gap-1" style={{ color: C.ink }}><MapPin size={11} style={{ color: C.textDim, flexShrink: 0, marginTop: 1 }} /><span>Abfahrt: {c.departure}</span></div>}
                {c.note && <div className="text-[10px] mb-1" style={{ color: C.textDim }}>{c.note}</div>}
                {c.passengers.length > 0 && <div className="text-[10px] mb-1.5" style={{ color: C.textDim }}>Mitfahrer: {c.passengers.map((p) => p.name).join(", ")}</div>}
                <div className="flex gap-2">
                  {!isDriver && !isPassenger && free > 0 && <button onClick={() => join(c.id)} className="flex-1 py-1.5 rounded-lg text-[11px] font-bold" style={{ background: C.ink, color: C.white }}>Mitfahren</button>}
                  {!isDriver && isPassenger && <button onClick={() => leave(c.id)} className="flex-1 py-1.5 rounded-lg text-[11px] font-bold" style={{ background: C.glass, color: C.red }}>Austragen</button>}
                  {isDriver && <button onClick={() => removeCarpool(c.id)} className="flex-1 py-1.5 rounded-lg text-[11px] font-bold" style={{ background: C.glass, color: C.red }}>Fahrgemeinschaft löschen</button>}
                </div>
              </div>
            );
          })}
          {carpools.length === 0 && <div className="text-[11px] rounded-xl p-2.5" style={{ background: C.paperDim, color: C.textDim }}>Noch keine Fahrgemeinschaft für diesen Termin.</div>}
        </div>
        {!showCreate ? (
          <button onClick={() => setShowCreate(true)} className="w-full py-2 rounded-lg text-xs font-bold" style={{ background: C.ink, color: C.white }}>Platz anbieten</button>
        ) : (
          <div className="rounded-xl p-2.5" style={{ background: C.paperDim }}>
            <input value={seats} onChange={(e) => setSeats(e.target.value)} inputMode="numeric" placeholder="Freie Plätze, z. B. 3" className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-1.5" style={{ background: C.glass, color: C.ink }}/>
            <input value={abfahrt} onChange={(e) => setAbfahrt(e.target.value)} placeholder="Abfahrtsadresse *, z. B. Hauptstraße 12, Iserlohn" className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-1.5" style={{ background: C.glass, color: C.ink }}/>
            <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Notiz (optional), z. B. Kofferraum begrenzt" className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-1.5" style={{ background: C.glass, color: C.ink }}/>
            <div className="flex gap-2">
              <button onClick={createCarpool} disabled={saving || !seats.trim()} className="flex-1 py-2 rounded-lg text-xs font-bold" style={{ background: seats.trim() ? C.ink : C.line, color: C.white }}>{saving ? "…" : "Anbieten"}</button>
              <button onClick={() => { setShowCreate(false); setSeats(""); setNote(""); setAbfahrt(""); }} className="px-3 py-2 rounded-lg text-xs font-bold" style={{ background: C.glass, color: C.textDim }}>Abbrechen</button>
            </div>
          </div>
        )}
      </>}
      {message && <div className="text-[11px] mt-1.5" style={{ color: C.red }}>{message}</div>}
    </div>
  );
}

/* initialOpen: Im Kalender-Overlay ist bereits klar, welcher Termin gemeint ist —
   dort wird die Karte aufgeklappt gezeigt, statt noch einmal tippen zu lassen. */
function EventCard({ ev, carpoolOn, onCarpool, currentUser, members, isAdminUser, dutyPlan, setDutyPlan, onDienstSetzen, canCancelTraining, onCancelTraining, onDeleteTraining, currentClub, featureEnabled, initialOpen = false }) {
  const [open, setOpen] = useState(initialOpen);
  const meta = typeMeta[ev.type];

  const helperEligible = ev.helperSlots ? (isFormalMember(currentUser) && (ev.type !== "spiel" || age(currentUser.birthdate) >= 16)) : false;
  const eventIsReal = !!supabase && isDbId(ev.id);

  return (
    <div className="rounded-2xl mb-3 overflow-hidden" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
      <button className="w-full text-left p-4" onClick={() => setOpen((o) => !o)}>
        <div className="flex items-start justify-between">
          <div className="flex gap-3">
            {/* Die Kachel zeigte Wochentag und Tageszahl, aber nie den Monat.
                Bei einer Liste, die ueber Monatsgrenzen laeuft, ist "4" damit
                mehrdeutig - und der Spielplan reicht bis ins naechste Jahr.
                Das Jahr steht nur dann dabei, wenn der Termin nicht im
                laufenden liegt; sonst wuerde es die schmale Kachel unnoetig
                fuellen. */}
            <div className="flex flex-col items-center justify-center rounded-xl px-2.5 py-1.5" style={{ background: C.paper, minWidth: 50 }}>
              <span className="text-[10px] uppercase font-bold" style={{ color: C.red, fontFamily: "Inter" }}>{formatDate(ev.date).split(" ")[0]}</span>
              <span className="text-lg leading-tight" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{new Date(ev.date).getDate()}</span>
              <span className="text-[10px] uppercase font-bold leading-tight" style={{ color: C.textDim, fontFamily: "Inter" }}>
                {new Date(ev.date).toLocaleDateString("de-DE", { month: "short" })}
                {new Date(ev.date).getFullYear() !== new Date().getFullYear() ? ` ${String(new Date(ev.date).getFullYear()).slice(-2)}` : ""}
              </span>
            </div>
            <div>
              <div className="flex flex-wrap gap-1 mb-1"><Pill bg={meta.color}>{meta.label}{ev.team ? ` · ${ev.team}` : ""}{ev.type === "spiel" ? ` · ${ev.home ? "Heim" : "Auswärts"}` : ""}</Pill>{ev.cancelled&&<Pill bg={C.red}>ABGESAGT</Pill>}</div>
              <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{ev.title}</div>
              <div className="flex items-center gap-1 text-xs mt-1" style={{ color: C.textDim, fontFamily: "Inter" }}>
                <Clock size={11} /> {formatTime(ev.date)} <span className="mx-0.5">·</span> <MapPin size={11} /> {ev.location}
              </div>
            </div>
          </div>
          <ChevronDown size={16} style={{ color: C.textDim, transform: open ? "rotate(180deg)" : "none", transition: "transform .2s", flexShrink: 0 }} />
        </div>
      </button>
      {open && (
        <div className="px-4 pb-4">
          {ev.cancelled&&<div className="rounded-xl p-3 mb-3 text-xs font-bold" style={{background:C.fehlerFlaeche,color:C.fehler,border: `1px solid ${C.fehlerRand}`}}>Dieses {meta.label} wurde{ev.team?` für ${ev.team}`:""} abgesagt.</div>}
          <p className="text-sm mb-3" style={{ color: C.textDim, fontFamily: "Inter" }}>{ev.desc}</p>
          {canCancelTraining&&!ev.cancelled&&<button onClick={()=>onCancelTraining(ev.id)} className="w-full py-2.5 rounded-xl text-xs font-bold mb-3" style={{background:C.fehlerFlaeche,color:C.fehler,border: `1px solid ${C.fehlerRand}`}}>{meta.label}{ev.team?` für ${ev.team}`:""} absagen</button>}{canCancelTraining&&<button onClick={()=>onDeleteTraining(ev.id, ev.team, ev.seriesId)} className="w-full py-2.5 rounded-xl text-xs font-bold mb-3" style={{background:C.paperDim,color:C.fehler}}>{meta.label} endgültig löschen</button>}

          {ev.home !== true && (
            eventIsReal ? <CarpoolSection ev={ev} currentUser={currentUser} /> : ev.carpool && (
            <button onClick={() => onCarpool(ev.id)} className="w-full flex items-center justify-center gap-2 py-2 rounded-lg text-xs mb-1"
              style={{ fontFamily: "Inter", fontWeight: 700, background: carpoolOn ? C.erfolgFlaeche : C.ink, color: carpoolOn ? C.secondary : C.white, border: carpoolOn ? `1px solid ${C.secondary}` : "none" }}>
              <Car size={14} /> {carpoolOn ? "Du bietest einen Platz an ✓" : "Fahrgemeinschaft: Platz anbieten"}
            </button>
          ))}

          {ev.helperSlots && featureEnabled("duty_roster") && (
            <div className="mt-3">
              <div className="text-xs font-semibold mb-2" style={{ fontFamily: "Inter", color: C.ink }}>Helfer:innen gesucht</div>
              <HelperSlots ev={ev} members={members} currentUser={currentUser} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} eligible={helperEligible} onSetzen={onDienstSetzen} />
            </div>
          )}
          {eventIsReal && ev.type === "spiel" && ev.home === true && featureEnabled("duty_roster") && <DutyTasksSection ev={ev} currentUser={currentUser} sport={currentClub?.sport} />}
        </div>
      )}
    </div>
  );
}
/* Monatsübersicht der Termine — dasselbe Raster wie bei den Fahrzeugen.
   Sie zeigt genau die Termine, die auch die Liste zeigt (gleiche Filter, gleiche
   Sichtbarkeit); ein Tippen auf einen Eintrag meldet ihn nach oben, wo er im
   Overlay geöffnet wird. */
function EventMonthCalendar({ events, onSelect }) {
  const [monthDate, setMonthDate] = useState(() => { const now = new Date(); return new Date(now.getFullYear(), now.getMonth(), 1); });
  const monthLabel = monthDate.toLocaleDateString("de-DE", { month: "long", year: "numeric" });
  const startOfMonth = new Date(monthDate.getFullYear(), monthDate.getMonth(), 1);
  const daysInMonth = new Date(monthDate.getFullYear(), monthDate.getMonth() + 1, 0).getDate();
  const startWeekday = (startOfMonth.getDay() + 6) % 7;
  const totalCells = Math.ceil((startWeekday + daysInMonth) / 7) * 7;
  const cells = Array.from({ length: totalCells }, (_, i) => {
    const dayNum = i - startWeekday + 1;
    if (dayNum < 1 || dayNum > daysInMonth) return null;
    return new Date(monthDate.getFullYear(), monthDate.getMonth(), dayNum);
  });
  const today = new Date();
  const isToday = (day) => day && day.toDateString() === today.toDateString();
  const eventsForDay = (day) => {
    if (!day) return [];
    return events
      .filter((ev) => new Date(ev.date).toDateString() === day.toDateString())
      .sort((a, b) => new Date(a.date) - new Date(b.date));
  };
  const monthCount = events.filter((ev) => {
    const d = new Date(ev.date);
    return d.getFullYear() === monthDate.getFullYear() && d.getMonth() === monthDate.getMonth();
  }).length;

  return (
    <div className="mb-5">
      <div className="flex items-center justify-between mb-3">
        <button onClick={() => setMonthDate((d) => new Date(d.getFullYear(), d.getMonth() - 1, 1))} aria-label="Vorheriger Monat" className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><ArrowLeft size={14}/></button>
        <div className="text-sm font-bold" style={{ color: C.ink, textTransform: "capitalize" }}>{monthLabel}</div>
        <button onClick={() => setMonthDate((d) => new Date(d.getFullYear(), d.getMonth() + 1, 1))} aria-label="Nächster Monat" className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><ArrowLeft size={14} style={{ transform: "rotate(180deg)" }}/></button>
      </div>
      <div className="rounded-2xl p-2" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
        <div className="grid grid-cols-7 gap-1 mb-1">
          {["Mo","Di","Mi","Do","Fr","Sa","So"].map((d) => <div key={d} className="text-center text-[9px] font-bold py-1" style={{ color: C.textDim }}>{d}</div>)}
        </div>
        <div className="grid grid-cols-7 gap-1">
          {cells.map((day, i) => {
            const dayEvents = eventsForDay(day);
            return (
              <div key={i} className="rounded-lg p-1 min-h-[54px]" style={{ background: day ? C.paperDim : "transparent", outline: isToday(day) ? `1.5px solid ${C.red}` : "none" }}>
                {day && <div className="text-[9px] font-bold mb-0.5" style={{ color: isToday(day) ? C.red : C.textDim }}>{day.getDate()}</div>}
                {dayEvents.slice(0, 2).map((ev) => {
                  const meta = typeMeta[ev.type];
                  return (
                    <button key={ev.id} onClick={() => onSelect(ev)} className="w-full text-left text-[8px] px-1 py-0.5 rounded mb-0.5 truncate" style={{ background: `color-mix(in srgb, ${meta.color} 18%, transparent)`, color: meta.color, textDecoration: ev.cancelled ? "line-through" : "none" }} title={`${meta.label}: ${ev.title}`}>{ev.title}</button>
                  );
                })}
                {dayEvents.length > 2 && <button onClick={() => onSelect(dayEvents[2])} className="text-[8px] w-full text-left" style={{ color: C.textDim }}>+{dayEvents.length - 2} mehr</button>}
              </div>
            );
          })}
        </div>
      </div>
      <div className="flex items-center gap-3 flex-wrap mt-2 px-1">
        {["training","spiel","event"].map((key) => (
          <span key={key} className="flex items-center gap-1.5 text-[10px]" style={{ color: C.textDim }}>
            <span className="w-2.5 h-2.5 rounded-full" style={{ background: typeMeta[key].color }} />{typeMeta[key].label}
          </span>
        ))}
        <span className="text-[10px] ml-auto" style={{ color: C.textDim }}>{monthCount} in diesem Monat</span>
      </div>
    </div>
  );
}

function EventsView({ currentUser, members, events, setEvents, carpools, setCarpools, dutyPlan, setDutyPlan, onDienstSetzen, werbeplaetze, onSponsorImpression, onSponsorClick, focusRequest, onFocusApplied, currentClub, featureEnabled, entitlement, goSubscribe }) {
  const [filter, setFilter] = useState("alle");
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [selectedEvent, setSelectedEvent] = useState(null);
  const [showCreate, setShowCreate] = useState(false);
  const [eventFehler, setEventFehler] = useState("");
  const [eventDraft, setEventDraft] = useState({ type: "training", team: "", title: "", day: "", location: "", desc: "", recurring: false, weekdays: [], startTime: "19:30", endTime: "22:00", rangeStart: "", rangeEnd: "", helferStationen: "" });
  /* Die Standardansicht haengt an der Mitgliedschaft, nicht am Geraet. Wer auf
     dem Telefon "U15" gespeichert hat, will das auf dem Tablet auch - vorher
     lag die Vorliebe im Geraetespeicher und war nach einer Neuinstallation
     weg. */
  const [teamFilter, setTeamFilter] = useState(currentUser.teamFilter || "alle");
  const [savedTeam, setSavedTeam] = useState(currentUser.teamFilter || "alle");
  useEffect(() => {
    if (!focusRequest) return;
    setFilter("spiel");
    setTeamFilter(focusRequest.team || "alle");
    onFocusApplied?.();
  }, [focusRequest]);
  /* Die Auswahlliste kommt aus den vorhandenen Terminen, nicht aus einer festen
     Aufzaehlung. Vorher standen dort nur die Jugendklassen - Herren 1, Herren 2
     und Damen 1 fehlten, obwohl sie Termine haben. */
  const filterTeams = [...new Set(events.map((e) => e.team).filter(Boolean))].sort((a, b) => a.localeCompare(b, "de"));

  /* Der Filter ist immer sichtbar. Frueher erschien er erst, nachdem man auf
     "Spiele" oder "Training" umgeschaltet hatte - in der Voreinstellung "alle",
     also genau dort, wo man ihn sucht, war er unsichtbar. */
  const teamFilterActive = filterTeams.length > 1;

  const filtered = events.filter((e) => {
    if (filter !== "alle" && e.type !== filter) return false;
    if (teamFilter === "alle") return true;
    /* Fuer Spiele und Trainings dieselbe Regel: die Mannschaft am Termin.
       Vorher liefen Trainings ueber die Jugendklasse - fuer Mannschaften ohne
       eine solche lieferte das nie ein Ergebnis.
       Vereinsweite Termine ohne Mannschaft bleiben sichtbar; sie betreffen
       alle, egal welche Mannschaft gerade gewaehlt ist. */
    if (!e.team) return true;
    return e.team === teamFilter;
  });
  const userId = currentUser.id;
  const myCarpools = carpools[userId] || {};
  const isAdminUser = isAdmin(currentUser);
  const canCreateSportEvent = isSysAdmin(currentUser) || currentUser.roles.some((role)=>["trainer","kapitaen","teammanager"].includes(role));
  const canCreateClubEvent = isAdminUser && entitlement?.tier !== "none";
  const [manageableTeams, setManageableTeams] = useState(null);
  useEffect(() => {
    if (!(supabase && isDbId(currentUser.id))) { setManageableTeams(null); return; }
    const loadManageableTeams = async () => {
      const { data } = await supabase.from("team_members")
        .select("function,teams(name)")
        .eq("membership_id", currentUser.id)
        .in("function", ["trainer", "kapitaen", "teammanager"]);
      const names = [...new Set((data || []).map((entry) => {
        const t = Array.isArray(entry.teams) ? entry.teams[0] : entry.teams;
        return t?.name;
      }).filter(Boolean))];
      setManageableTeams(names);
    };
    loadManageableTeams();
  }, [currentUser.id]);

  /* Die Mannschaften des Vereins, unabhaengig davon, ob sie schon Termine haben.
     Genau daran scheiterte das Anlegen bisher: Die Auswahl kam aus filterTeams,
     und das leitet sich ausschliesslich aus VORHANDENEN Terminen ab. In einem
     frisch angelegten Verein gibt es keine - also war die Liste leer, das
     Auswahlfeld im Formular blieb leer, und createSportEvent brach an der
     Pruefung auf allowedEventTeams kommentarlos ab. Der Gruender konnte damit
     keinen einzigen Termin anlegen, auch nicht nach dem Anlegen von
     Mannschaften, weil die teams-Tabelle nie gelesen wurde.
     Fuer den Filter bleibt filterTeams richtig - dort sollen nur Mannschaften
     stehen, zu denen es auch etwas zu sehen gibt. */
  const [clubTeams, setClubTeams] = useState(null);
  useEffect(() => {
    if (!(supabase && isDbId(currentUser.clubId))) { setClubTeams(null); return; }
    supabase.from("teams").select("name").eq("club_id", currentUser.clubId).eq("active", true).order("name")
      .then(({ data }) => setClubTeams([...new Set((data || []).map((t) => t.name).filter(Boolean))]));
  }, [currentUser.clubId]);

  /* Ohne Datenbank (Demo-Betrieb) bleibt es bei den Mannschaften aus den
     Terminen; mit Datenbank zaehlen beide Quellen, damit auch ein Termin einer
     inzwischen deaktivierten Mannschaft weiter bearbeitet werden kann. */
  const waehlbareTeams = clubTeams === null
    ? filterTeams
    : [...new Set([...clubTeams, ...filterTeams])].sort((a, b) => a.localeCompare(b, "de"));

  const allowedEventTeams = isSysAdmin(currentUser)
    ? waehlbareTeams
    : manageableTeams !== null
      ? manageableTeams.filter((team) => waehlbareTeams.includes(team))
      /* Rueckfall ohne Datenbank: alle Mannschaften, in denen die Person eine
         leitende Funktion hat. Vorher endete jeder Zweig bei genau einer -
         beim Trainer notfalls bei seiner Spielmannschaft, sonst schlicht bei
         currentUser.team. Wer in zwei Mannschaften Kapitaen ist, konnte fuer
         die zweite keinen Termin eintragen; createSportEvent brach dann an
         genau dieser Liste ab. */
      : [...new Set([
          ...memberTrainerTeams(currentUser),
          ...memberCaptainTeams(currentUser),
          ...memberManagedTeams(currentUser),
        ])].filter((team) => waehlbareTeams.includes(team));
  const openCreate = () => {
    setEventDraft((draft) => ({ ...draft, type: canCreateSportEvent ? draft.type : "event", team: canCreateSportEvent ? (allowedEventTeams[0] || "") : "" }));
    /* Alte Meldung verwerfen, sonst begruesst sie einen beim naechsten Oeffnen
       des Formulars erneut, obwohl gar nichts mehr im Argen liegt. */
    setEventFehler("");
    setShowCreate(true);
  };
  const resetEventDraft = () => setEventDraft({ type: "training", team: allowedEventTeams[0] || "", title: "", date: "", location: "", desc: "", recurring: false, weekdays: [], startTime: "18:00", endTime: "19:30", rangeStart: "", rangeEnd: "", isHome: true });
  const createSportEvent = async (event) => {
    event.preventDefault();
    const isClubEvent = eventDraft.type === "event";
    /* Diese beiden Pruefungen brachen frueher stumm ab: Der Speichern-Knopf tat
       schlicht nichts, ohne jeden Hinweis. */
    if (!isClubEvent && (!eventDraft.team || !allowedEventTeams.includes(eventDraft.team))) {
      /* Der Hinweis richtet sich nach der Rolle: Mannschaften anlegen darf nur
         die Vereinsverwaltung. Ein Trainer oder Kapitaen an dieselbe Stelle zu
         schicken waere ins Leere geschickt - dort darf er nichts. */
      setEventFehler(allowedEventTeams.length > 0
        ? "Bitte wähle eine Mannschaft aus."
        : isSysAdmin(currentUser) || isAdminUser
          ? "Für Training und Spiel wird eine Mannschaft gebraucht. Lege zuerst unter „Mannschaften“ eine an."
          : "Dir ist noch keine Mannschaft zugewiesen. Die Vereinsverwaltung kann das eintragen.");
      return;
    }
    if (!eventDraft.title.trim() || !eventDraft.location.trim()) {
      setEventFehler("Bitte gib einen Titel und einen Ort an.");
      return;
    }
    if (eventDraft.recurring) {
      if (!eventDraft.weekdays.length || !eventDraft.startTime || !eventDraft.endTime || !eventDraft.rangeStart || !eventDraft.rangeEnd) return;
      if (!supabase || !currentUser.authProfileId) return;
      const { data: team } = await supabase.from("teams").select("id").eq("club_id", currentUser.clubId).eq("name", eventDraft.team).maybeSingle();
      const { error } = await supabase.rpc("create_recurring_events", {
        target_club: currentUser.clubId,
        target_team: team?.id || null,
        event_type: eventDraft.type,
        event_title: eventDraft.title.trim(),
        event_description: eventDraft.desc.trim() || null,
        event_location: eventDraft.location.trim(),
        weekdays: eventDraft.weekdays,
        start_time: eventDraft.startTime,
        end_time: eventDraft.endTime,
        range_start: eventDraft.rangeStart,
        range_end: eventDraft.rangeEnd,
      });
      if (error) return;
      const created = [];
      const start = new Date(eventDraft.rangeStart + "T00:00:00");
      const end = new Date(eventDraft.rangeEnd + "T00:00:00");
      for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
        const isoDay = d.getDay() === 0 ? 7 : d.getDay();
        if (!eventDraft.weekdays.includes(isoDay)) continue;
        const dateStr = d.toISOString().slice(0, 10);
        created.push({ id: `${dateStr}-${created.length}-${eventDraft.team}`, type: eventDraft.type, team: eventDraft.team, title: eventDraft.title.trim(), date: `${dateStr}T${eventDraft.startTime}`, location: eventDraft.location.trim(), desc: eventDraft.desc.trim(), carpool: false, home: true, ...(eventDraft.type === "training" ? { youthClassIds: [TEAM_TO_YOUTHCLASS[eventDraft.team]] } : {}) });
      }
      setEvents((all) => [...all, ...created].sort((a, b) => new Date(a.date) - new Date(b.date)));
      setFilter(eventDraft.type);
      setTeamFilter(eventDraft.team);
      resetEventDraft();
      setShowCreate(false);
      return;
    }
    /* Datum, Beginn und Ende sind getrennte Felder. Zusammengesetzt wird erst
       hier - der Browser liefert "2026-09-01" und "19:30", daraus wird eine
       Ortszeit, die new Date() in der Zeitzone des Geraets liest. */
    if (!eventDraft.day || !eventDraft.startTime || !eventDraft.endTime) return;
    const beginn = new Date(`${eventDraft.day}T${eventDraft.startTime}`);
    const ende = new Date(`${eventDraft.day}T${eventDraft.endTime}`);
    if (!(ende > beginn)) { setEventFehler("Das Ende muss nach dem Beginn liegen."); return; }
    setEventFehler("");
    /* Die Helferstationen. Sie gehoeren an den Termin, nicht in eine feste
       Liste im Code - vorher hatten nur die Demo-Termine welche, und die
       Helferplanung blieb fuer jeden echten Verein leer. */
    const stationen = eventDraft.helferStationen.split(",").map((x) => x.trim()).filter(Boolean).slice(0, 12);
    let eventId = Date.now();
    if (supabase && currentUser.authProfileId) {
      const { data: team } = eventDraft.team ? await supabase.from("teams").select("id").eq("club_id",currentUser.clubId).eq("name",eventDraft.team).maybeSingle() : { data: null };
      const { data: saved, error: anlegeFehler } = await supabase.from("events").insert({club_id:currentUser.clubId,team_id:team?.id||null,type:eventDraft.type,status:"scheduled",title:eventDraft.title.trim(),description:eventDraft.desc.trim()||null,starts_at:beginn.toISOString(),ends_at:ende.toISOString(),location:eventDraft.location.trim(),created_by:currentUser.authProfileId,home_away:eventDraft.type==="spiel"?(eventDraft.isHome?"heim":"auswaerts"):null,helper_slots:stationen}).select("id").maybeSingle();
      /* Das Ergebnis MUSS ausgewertet werden. Vorher stand hier nur
         "if (saved?.id) eventId = saved.id" - schlug das Anlegen fehl, blieb
         eventId die Zahl aus Date.now(), und der Termin landete allein in der
         Liste dieses Geraets. Der Nutzer sah ihn dort stehen und glaubte, das
         Training sei eingetragen; die Mannschaft erfuhr nie davon, und beim
         naechsten Laden war er weg. Obendrein umgingen Absage und Loeschung
         danach die Datenbank, weil beide auf eine Zeichenkette als Kennung
         pruefen - der stille Fehlschlag setzte sich also fort. */
      if (anlegeFehler) {
        setTerminFehler("Der Termin konnte nicht gespeichert werden. Prüfe deine Verbindung und versuche es noch einmal.");
        return;
      }
      if (!saved?.id) {
        setTerminFehler("Der Termin wurde nicht gespeichert — dir fehlt das Recht, für diese Mannschaft einzutragen.");
        return;
      }
      eventId = saved.id;
    }
    const created = { helperSlots: stationen.length ? stationen : undefined, id: eventId, type: eventDraft.type, team: eventDraft.team, title: eventDraft.title.trim(), date: beginn.toISOString(), location: eventDraft.location.trim(), desc: eventDraft.desc.trim(), carpool: false, home: eventDraft.type === "spiel" ? eventDraft.isHome : true, ...(eventDraft.type === "training" ? { youthClassIds: [TEAM_TO_YOUTHCLASS[eventDraft.team]] } : {}) };
    setTerminFehler("");
    setEvents((all) => [...all, created].sort((a, b) => new Date(a.date) - new Date(b.date)));
    setFilter(eventDraft.type);
    setTeamFilter(eventDraft.team);
    resetEventDraft();
    setShowCreate(false);
  };
  /* Die Antwort der Datenbank wird ausgewertet. Vorher lief die Absage immer
     durch: Verweigert die Sicherheitsregel das Update, meldet Supabase keinen
     Fehler, sondern null betroffene Zeilen - die Ansicht setzte den Termin
     trotzdem auf "abgesagt". Die Mannschaft sah ihn unveraendert, und beim
     naechsten Laden war er auch beim Absagenden wieder da. Ein stummer
     Fehlschlag ist schlimmer als eine Fehlermeldung. */
  const [terminFehler, setTerminFehler] = useState("");
  const cancelTraining = async (eventId) => {
    if (supabase && typeof eventId === "string") {
      const { data, error } = await supabase.from("events")
        .update({ status: "cancelled", cancelled_at: new Date().toISOString(), cancelled_by: currentUser.authProfileId || null })
        .eq("id", eventId).select("id");
      /* Zwei verschiedene Ursachen, zwei verschiedene Meldungen. error deckt
         auch Verbindungsabbruch, Zeitueberschreitung und abgelaufene Anmeldung
         ab - in einer App auf dem Telefon ist das der haeufigere Fall. Wer
         dann "dir fehlt das Recht" liest, schliesst daraus, man habe ihm die
         Mannschaft entzogen. */
      if (error) {
        setTerminFehler("Die Absage konnte nicht gespeichert werden. Prüfe deine Verbindung und versuche es noch einmal.");
        return;
      }
      if (!data?.length) {
        setTerminFehler("Die Absage wurde nicht gespeichert. Entweder fehlt dir das Recht für diese Mannschaft, oder der Termin gibt es nicht mehr.");
        return;
      }
    }
    setTerminFehler("");
    setEvents((all) => all.map((item) => item.id === eventId ? { ...item, cancelled: true, cancelledBy: currentUser.id } : item));
  };
  const [deleteRequest, setDeleteRequest] = useState(null);
  const deleteTraining = (eventId, teamName, seriesId) => {
    setDeleteRequest({ id: eventId, team: teamName, seriesId: seriesId || null });
  };
  /* Dieselbe Falle wie beim Absagen, auf zwei Wegen mit zwei verschiedenen
     Antworten:
       Einzeltermin - .delete() meldet keinen Fehler, sondern loescht null
         Zeilen. Erkennbar nur am leeren Ergebnis von .select("id").
       Serie       - delete_event_series ist SECURITY DEFINER und gibt die
         Trefferzahl zurueck. 0 heisst "nichts geloescht", auch hier ohne
         Fehler.
     Der bisherige Code prueft beide Male allein auf error, faellt also durch
     und entfernt den Termin aus der Ansicht. In der Datenbank bleibt er, die
     Mannschaft sieht ihn weiter, und beim naechsten Laden ist er auch beim
     Loeschenden wieder da. Und still war der Abbruch obendrein: Das Fenster
     schloss sich, ohne zu sagen, dass nichts passiert ist. */
  const performSingleDelete = async () => {
    if (!deleteRequest) return;
    const id = deleteRequest.id;
    if (supabase && typeof id === "string") {
      const { data, error } = await supabase.from("events").delete().eq("id", id).select("id");
      if (error) {
        setTerminFehler("Der Termin konnte nicht gelöscht werden. Prüfe deine Verbindung und versuche es noch einmal.");
        setDeleteRequest(null);
        return;
      }
      if (!data?.length) {
        setTerminFehler("Der Termin wurde nicht gelöscht. Entweder fehlt dir das Recht für diese Mannschaft, oder er ist bereits entfernt.");
        setDeleteRequest(null);
        return;
      }
    }
    setTerminFehler("");
    setEvents((all) => all.filter((item) => item.id !== id));
    setDeleteRequest(null);
  };
  const performSeriesDelete = async () => {
    if (!deleteRequest || !deleteRequest.seriesId) return;
    const seriesId = deleteRequest.seriesId;
    if (supabase) {
      /* delete_event_series ist SECURITY DEFINER und prueft die Rechte in
         ihrem eigenen WHERE. Wer keines hat, loescht dort null Zeilen - und
         bekommt KEINEN Fehler, sondern die Zahl 0 zurueck. Der Rueckgabewert
         muss deshalb ausgewertet werden; nur auf error zu pruefen liess genau
         den stillen Fehlschlag stehen, den dieser Block verhindern soll. */
      const { data: geloescht, error } = await supabase.rpc("delete_event_series", { target_series: seriesId });
      if (error) {
        setTerminFehler("Die Terminreihe konnte nicht gelöscht werden. Prüfe deine Verbindung und versuche es noch einmal.");
        setDeleteRequest(null);
        return;
      }
      if (!geloescht) {
        setTerminFehler("Die Terminreihe wurde nicht gelöscht. Entweder fehlt dir das Recht für diese Mannschaft, oder sie ist bereits entfernt.");
        setDeleteRequest(null);
        return;
      }
    }
    setTerminFehler("");
    setEvents((all) => all.filter((item) => item.seriesId !== seriesId));
    setDeleteRequest(null);
  };
  const saveDefaultTeam = async () => {
    setSavedTeam(teamFilter);
    if (!supabase || !isDbId(currentUser.id)) return;
    const { error } = await supabase.from("club_memberships").update({ team_filter: teamFilter }).eq("id", currentUser.id);
    if (error) setSavedTeam(currentUser.teamFilter || "alle");
  };

  const handleCarpool = (id) => setCarpools((c) => ({ ...c, [userId]: { ...(c[userId] || {}), [id]: !myCarpools[id] } }));

  /* Einmal berechnet statt an zwei Stellen abgeschrieben: Liste und Kalender-
     Overlay müssen zwingend dieselben Schreibrechte anwenden. */
  /* Wer darf ein Training oder Spiel absagen oder loeschen?
     Vorher wurde die Kapitaensfrage als "currentUser.team === ev.team"
     gestellt. Ein Kapitaen zweier Mannschaften konnte damit nur in einer von
     beiden absagen - in der anderen fehlte ihm das Recht, obwohl er dort
     ebenso Kapitaen ist. Beim Trainer stand als Rueckfall [currentUser.team]:
     Fehlten die Trainer-Mannschaften, galt ersatzweise die eigene
     Spielmannschaft - ein Recht an der falschen Stelle.
     Jetzt zaehlt je Funktion die passende Liste. */
  const canCancelFor = (ev) => {
    if (ev.type === "event") return isAdminUser;
    if (ev.type !== "training" && ev.type !== "spiel") return false;
    return isSysAdmin(currentUser)
      || memberTrainerTeams(currentUser).includes(ev.team)
      || memberCaptainTeams(currentUser).includes(ev.team)
      || memberManagedTeams(currentUser).includes(ev.team);
  };

  /* Der ausgewählte Termin wird bei jedem Rendern frisch aus events geholt.
     Ein festgehaltenes Objekt würde nach einer Absage im Overlay den alten
     Stand weiterzeigen. */
  const openEvent = selectedEvent ? events.find((ev) => ev.id === selectedEvent) : null;

  return (
    <div className="px-4 pt-4 pb-24">
      <div className="flex items-start justify-between gap-3"><SectionTitle title="Termine" />{(canCreateSportEvent||canCreateClubEvent)&&<button onClick={openCreate} className="px-3 py-1.5 rounded-full text-xs flex-shrink-0" style={{background:C.red,color:C.white,fontWeight:700}}>＋ Eintragen</button>}</div>
      {showCreate&&<form onSubmit={createSportEvent} className="rounded-2xl p-4 mb-4 space-y-2.5" style={{background:C.glass,border:`1px solid ${C.line}`}}><div className="text-sm font-bold">Termin eintragen</div><div className="text-[10px]" style={{color:C.textDim}}>{eventDraft.type==="event"?"Vereins-Events sind für alle Mitglieder sichtbar, unabhängig von Mannschaft.":isSysAdmin(currentUser)?"Als Vereins-Sysadmin kannst du jede Mannschaft auswählen.":currentUser.roles.includes("trainer")?"Du kannst nur deine im Profil hinterlegten Mannschaften auswählen.":"Als Kapitän oder Teammanager kannst du nur für deine hinterlegte Mannschaft eintragen."}</div><div className="text-[10px] font-bold" style={{color:C.red}}>* Pflichtfeld</div><div className="grid grid-cols-2 gap-2"><select value={eventDraft.type} onChange={(e)=>setEventDraft({...eventDraft,type:e.target.value,team:e.target.value==="event"?"":eventDraft.team})} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}>{canCreateSportEvent&&<option value="training">Training</option>}{canCreateSportEvent&&<option value="spiel">Spiel</option>}{canCreateClubEvent&&<option value="event">Vereins-Event</option>}</select>{eventDraft.type!=="event"&&<select value={eventDraft.team} onChange={(e)=>setEventDraft({...eventDraft,team:e.target.value})} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}>{allowedEventTeams.map((team)=><option key={team} value={team}>{team}</option>)}</select>}</div><input value={eventDraft.title} onChange={(e)=>setEventDraft({...eventDraft,title:e.target.value})} placeholder={eventDraft.type==="training"?"Titel des Trainings *":eventDraft.type==="event"?"Titel des Events *":"Titel des Spiels *"} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/>{eventDraft.type === "spiel" && <label className="flex items-center gap-2 px-0.5"><input type="checkbox" checked={eventDraft.isHome} onChange={(e)=>setEventDraft({...eventDraft,isHome:e.target.checked})}/><span className="text-xs font-bold" style={{color:C.ink}}>Heimspiel</span></label>}{eventDraft.type === "training" && <label className="flex items-center gap-2 px-0.5"><input type="checkbox" checked={eventDraft.recurring} onChange={(e)=>setEventDraft({...eventDraft,recurring:e.target.checked})}/><span className="text-xs font-bold" style={{color:C.ink}}>Wiederholend</span></label>}{!eventDraft.recurring ? <div className="space-y-2">
        <label className="block"><span className="block text-[10px] font-bold mb-1" style={{color:C.textDim}}>Datum *</span><input type="date" value={eventDraft.day} onChange={(e)=>setEventDraft({...eventDraft,day:e.target.value})} className="erg-datetime w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim,color:C.ink}}/></label>
        <div className="grid grid-cols-2 gap-2">
          <label className="block"><span className="block text-[10px] font-bold mb-1" style={{color:C.textDim}}>Beginn *</span><input type="time" value={eventDraft.startTime} onChange={(e)=>setEventDraft({...eventDraft,startTime:e.target.value})} className="erg-datetime w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim,color:C.ink}}/></label>
          <label className="block"><span className="block text-[10px] font-bold mb-1" style={{color:C.textDim}}>Ende *</span><input type="time" value={eventDraft.endTime} onChange={(e)=>setEventDraft({...eventDraft,endTime:e.target.value})} className="erg-datetime w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim,color:C.ink}}/></label>
        </div>
      </div> : <div className="space-y-2"><div className="flex gap-1.5 flex-wrap">{[["1","Mo"],["2","Di"],["3","Mi"],["4","Do"],["5","Fr"],["6","Sa"],["7","So"]].map(([num,label])=>{const n=Number(num);const active=eventDraft.weekdays.includes(n);return <button type="button" key={num} onClick={()=>setEventDraft({...eventDraft,weekdays:active?eventDraft.weekdays.filter((w)=>w!==n):[...eventDraft.weekdays,n]})} className="px-2.5 py-1.5 rounded-full text-[11px] font-bold" style={{background:active?C.red:C.paperDim,color:active?C.white:C.textDim}}>{label}</button>;})}</div><div className="grid grid-cols-2 gap-2"><input type="time" value={eventDraft.startTime} onChange={(e)=>setEventDraft({...eventDraft,startTime:e.target.value})} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/><input type="time" value={eventDraft.endTime} onChange={(e)=>setEventDraft({...eventDraft,endTime:e.target.value})} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/></div><div className="grid grid-cols-2 gap-2"><input type="date" value={eventDraft.rangeStart} onChange={(e)=>setEventDraft({...eventDraft,rangeStart:e.target.value})} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/><input type="date" value={eventDraft.rangeEnd} onChange={(e)=>setEventDraft({...eventDraft,rangeEnd:e.target.value})} className="erg-datetime px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim,color:C.ink}}/></div></div>}<input value={eventDraft.location} onChange={(e)=>setEventDraft({...eventDraft,location:e.target.value})} placeholder="Ort *" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/><textarea value={eventDraft.desc} onChange={(e)=>setEventDraft({...eventDraft,desc:e.target.value})} placeholder="Beschreibung (optional)" rows={2} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none resize-none" style={{background:C.paperDim}}/><input value={eventDraft.helferStationen} onChange={(e)=>setEventDraft({...eventDraft,helferStationen:e.target.value})} placeholder={`Helferstationen, mit Komma getrennt (optional) — ${sportConfig(currentClub?.sport).dutyStationExamples}`} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/>{/* Die Meldung stand vorher IM Zweig fuer Einzeltermine. Bei einer Serie erschien sie deshalb nie, und das Speichern blieb wieder stumm - genau der Fehler, den sie beheben sollte. Jetzt steht sie vor der Knopfzeile und gilt fuer beide Zweige. */}{eventFehler && <div className="text-[10px] rounded-xl px-3 py-2" style={{background:C.fehlerFlaeche,color:C.fehler}}>{eventFehler}</div>}<div className="flex gap-2"><button type="submit" className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{background:C.ink,color:C.white}}>Speichern</button><button type="button" onClick={()=>{setShowCreate(false);setEventFehler("");}} className="px-4 py-2.5 rounded-xl text-xs font-bold" style={{background:C.paperDim,color:C.textDim}}>Abbrechen</button></div></form>}
      <SponsorSlot slotKey="events_header" bookings={werbeplaetze} onImpression={onSponsorImpression} onClick={onSponsorClick} visible={featureEnabled("sponsor_events_header")} />
      <div className="flex items-center gap-2 mb-3">
        <div className="flex gap-2 overflow-x-auto pb-1 flex-1 min-w-0" style={{ scrollbarWidth: "none" }}>
          {[["alle", "Alle"], ["training", "Training"], ["spiel", "Spiele"], ["event", "Events"]].map(([k, l]) => (
            <button key={k} onClick={() => setFilter(k)} className="px-3 py-1.5 rounded-full text-xs flex-shrink-0"
              style={{ fontFamily: "Inter", fontWeight: 700, background: filter === k ? C.ink : C.paperDim, color: filter === k ? C.white : C.textDim }}>{l}</button>
          ))}
        </div>
        <button onClick={() => setCalendarOpen((v) => !v)} aria-pressed={calendarOpen} aria-label="Kalenderübersicht ein- oder ausblenden" className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: calendarOpen ? C.ink : C.paperDim, color: calendarOpen ? C.white : C.textDim }}><CalendarDays size={15}/></button>
      </div>
      {teamFilterActive && <div className="flex items-center gap-2 mb-4 px-2.5 py-2 rounded-xl" style={{background:C.glass,border:`1px solid ${C.line}`}}>
        <Users size={13} style={{color:C.textDim,flexShrink:0}}/>
        <select aria-label="Mannschaft filtern" value={teamFilter} onChange={(e)=>setTeamFilter(e.target.value)} className="flex-1 min-w-0 bg-transparent text-[11px] font-bold outline-none" style={{color:C.ink}}>
          <option value="alle">Alle Mannschaften</option>{filterTeams.map((team)=><option key={team} value={team}>{team}</option>)}
        </select>
        <button aria-label="Als Standardansicht speichern" title="Als Standard speichern" onClick={saveDefaultTeam} disabled={savedTeam===teamFilter} className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" style={{background:savedTeam===teamFilter?C.erfolgFlaeche:C.paperDim,color:savedTeam===teamFilter?C.secondary:C.textDim}}><Star size={13} fill={savedTeam===teamFilter?C.secondary:"none"}/></button>
      </div>}
      {terminFehler && (
        <div role="alert" className="flex items-center gap-1.5 text-xs mb-3 rounded-xl px-3 py-2.5" style={{ background: C.fehlerFlaeche, color: C.fehler, fontFamily: "Inter" }}>
          <AlertCircle size={13} /> {terminFehler}
        </div>
      )}
      {calendarOpen && <EventMonthCalendar events={filtered} onSelect={(ev) => setSelectedEvent(ev.id)} />}
      {filtered.map((ev) => (
        <EventCard key={ev.id} ev={ev}
          carpoolOn={!!myCarpools[ev.id]} onCarpool={handleCarpool}
          currentUser={currentUser} members={members} isAdminUser={isAdminUser}
          currentClub={currentClub} featureEnabled={featureEnabled}
          dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} onDienstSetzen={onDienstSetzen}
          canCancelTraining={canCancelFor(ev)} onCancelTraining={cancelTraining} onDeleteTraining={deleteTraining}
        />
      ))}
      {filtered.length===0&&<div className="rounded-2xl p-6 text-center text-xs" style={{background:C.paperDim,color:C.textDim}}>Für diese Mannschaft sind aktuell keine {filter === "training" ? "Trainingstermine" : "Spiele"} hinterlegt.</div>}

      {/* Termin aus dem Kalender. Bewusst dieselbe EventCard wie in der Liste —
          damit gelten hier zwangsläufig dieselben Lese- und Schreibrechte,
          inklusive Absagen, Löschen, Fahrgemeinschaft und Helferplanung. */}
      {openEvent && (
        <div className="fixed inset-0 z-50 flex items-end p-3" style={{ background: "rgba(20,21,26,.72)" }} onClick={() => setSelectedEvent(null)}>
          <div role="dialog" aria-modal="true" aria-label={openEvent.title} onClick={(e) => e.stopPropagation()} className="w-full rounded-3xl p-4 max-h-[85%] overflow-y-auto" style={{ background: C.glass }}>
            <div className="flex items-center justify-between mb-3">
              <div className="text-sm font-bold" style={{ fontFamily: "Oswald", color: C.ink }}>{typeMeta[openEvent.type].label}</div>
              <button onClick={() => setSelectedEvent(null)} aria-label="Schließen" className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><X size={15}/></button>
            </div>
            <EventCard ev={openEvent} initialOpen
              carpoolOn={!!myCarpools[openEvent.id]} onCarpool={handleCarpool}
              currentUser={currentUser} members={members} isAdminUser={isAdminUser}
              currentClub={currentClub} featureEnabled={featureEnabled}
              dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} onDienstSetzen={onDienstSetzen}
              canCancelTraining={canCancelFor(openEvent)} onCancelTraining={(id) => { cancelTraining(id); setSelectedEvent(null); }} onDeleteTraining={(...args) => { deleteTraining(...args); setSelectedEvent(null); }}
            />
          </div>
        </div>
      )}
      {deleteRequest && <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: "rgba(20,21,26,.72)" }} onClick={() => { setDeleteRequest(null); setTerminFehler(""); }}><div role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()} className="w-full max-w-sm rounded-2xl p-5" style={{ background: C.glass }}>{deleteRequest.seriesId ? <><div className="text-sm font-bold mb-1" style={{ color: C.ink }}>Wiederkehrendes Training</div><div className="text-xs mb-4" style={{ color: C.textDim }}>Sollen alle geplanten Sessions dieser Serie gelöscht werden, oder nur diese eine?</div><button onClick={performSeriesDelete} className="w-full py-2.5 rounded-xl text-xs font-bold mb-2" style={{ background: C.red, color: C.white }}>Alle Sessions</button><button onClick={performSingleDelete} className="w-full py-2.5 rounded-xl text-xs font-bold mb-2" style={{ background: C.paperDim, color: C.ink }}>Nur eine Session</button><button onClick={() => { setDeleteRequest(null); setTerminFehler(""); }} className="w-full py-2 text-xs font-bold" style={{ color: C.textDim }}>Abbrechen</button></> : <><div className="text-sm font-bold mb-1" style={{ color: C.ink }}>Wollen Sie die Trainingseinheit wirklich löschen?</div><div className="flex gap-2 mt-4"><button onClick={() => { setDeleteRequest(null); setTerminFehler(""); }} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.paperDim, color: C.ink }}>Nein</button><button onClick={performSingleDelete} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.red, color: C.white }}>Ja</button></div></>}</div></div>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Beiträge                                                             */
/* ------------------------------------------------------------------ */
function FeesView({ members, records, setRecords }) {
  const [selectedMemberId, setSelectedMemberId] = useState(null);
  const [form, setForm] = useState({ year: "2026", type: "Mitgliedsbeitrag", amount: "", paid: "offen", invoiceNumber: "", linkedMemberIds: [], manualNames: "", personCount: "1" });
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const selectedMember = members.find((member) => member.id === selectedMemberId);
  const memberRecords = records.filter((record) => record.memberId === selectedMemberId);
  const addRecord = async (event) => {
    event.preventDefault();
    if (!selectedMemberId || !form.year || !form.type.trim() || !form.amount.trim()) return;
    const manualNames = form.type === "Familienbeitrag" ? form.manualNames.split(",").map((name) => name.trim()).filter(Boolean) : [];
    const databaseMembership = !!supabase && isDbId(selectedMemberId);
    const amountNumber = Number(form.amount.replace(",", "."));
    if (!Number.isFinite(amountNumber) || amountNumber < 0) { setMessage("Bitte eine gültige Beitragshöhe eingeben."); return; }
    setSaving(true); setMessage("");
    let id = `fee-${Date.now()}`;
    if (databaseMembership) {
      const { data, error } = await supabase.rpc("save_fee_record", {
        target_club: selectedMember.clubId,
        target_membership: selectedMemberId,
        fee_year: Number(form.year),
        fee_kind: form.type,
        fee_amount: amountNumber,
        fee_status: form.paid,
        fee_invoice_number: form.invoiceNumber.trim() || null,
        fee_person_count: form.type === "Familienbeitrag" ? Math.max(1, Number(form.personCount) || 1) : 1,
        linked_memberships: form.type === "Familienbeitrag" ? form.linkedMemberIds : [],
        manual_people: manualNames,
      });
      if (error) { setMessage(error.message.includes("invoice") ? "Diese Rechnungsnummer ist bereits vergeben." : "Der Beitrag konnte nicht gespeichert werden."); setSaving(false); return; }
      id = data;
    }
    setRecords((all) => [{ id, memberId: selectedMemberId, year: form.year, type: form.type, amount: amountNumber.toFixed(2).replace(".", ","), paid: form.paid === "bezahlt", invoiceNumber: form.invoiceNumber.trim(), linkedMemberIds: form.type === "Familienbeitrag" ? form.linkedMemberIds : [], manualNames, personCount: form.type === "Familienbeitrag" ? Math.max(1, Number(form.personCount) || 1) : 1 }, ...all]);
    setForm((current) => ({ ...current, amount: "", invoiceNumber: "", linkedMemberIds: [], manualNames: "", personCount: current.type === "Familienbeitrag" ? "2" : "1" }));
    setSaving(false); setMessage("Beitragsdatensatz wurde gespeichert.");
  };
  const togglePaid = async (record) => {
    const nextPaid = !record.paid;
    if (supabase && isDbId(record.id)) {
      const { error } = await supabase.rpc("set_fee_payment_status", { target_fee: record.id, new_status: nextPaid ? "bezahlt" : "offen" });
      if (error) { setMessage("Der Zahlungsstatus konnte nicht gespeichert werden."); return; }
    }
    setRecords((all) => all.map((item) => item.id === record.id ? { ...item, paid: nextPaid } : item));
  };
  const deleteRecord = async (record) => {
    if (!window.confirm(`Beitragsdatensatz ${record.invoiceNumber || record.year} wirklich löschen?`)) return;
    if (supabase && isDbId(record.id)) {
      const { error } = await supabase.rpc("delete_fee_record", { target_fee: record.id });
      if (error) { setMessage("Der Beitragsdatensatz konnte nicht gelöscht werden."); return; }
    }
    setRecords((all) => all.filter((item) => item.id !== record.id));
  };
  const toggleFamilyMember = (memberId) => setForm((current) => ({ ...current, linkedMemberIds: current.linkedMemberIds.includes(memberId) ? current.linkedMemberIds.filter((id) => id !== memberId) : [...current.linkedMemberIds, memberId] }));

  if (!selectedMember) {
    return (
      <div className="px-4 pt-4 pb-24">
        <SectionTitle eyebrow="Geschäftsführung & Finanzmanagement" title="Beiträge" />
        <div className="rounded-2xl p-4 mb-4" style={{ background: C.ink }}>
          <div className="text-white text-sm" style={{ fontFamily: "Inter", fontWeight: 700 }}>{members.length} Vereinsmitglieder</div>
          <div className="text-xs mt-1" style={{ color: C.textDim }}>Mitglied auswählen, um Beiträge und Rechnungen zu verwalten.</div>
        </div>
        <div className="space-y-2">
          {members.map((member) => {
            const entries = records.filter((record) => record.memberId === member.id);
            const open = entries.filter((record) => !record.paid).length;
            return (
              <button key={member.id} onClick={() => setSelectedMemberId(member.id)} className="w-full flex items-center gap-3 p-3 rounded-2xl text-left" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
                <div className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0" style={{ background: member.color, color: C.white }}>{initialsOf(member.name)}</div>
                <div className="flex-1 min-w-0">
                  <div className="text-sm truncate" style={{ fontWeight: 700, color: C.ink }}>{member.name}</div>
                  <div className="text-[11px]" style={{ color: C.textDim }}>{member.team} · {entries.length} Datensätze</div>
                </div>
                <Pill bg={open ? C.fehler : C.erfolg}>{open ? `${open} offen` : "bezahlt"}</Pill>
                <ChevronRight size={15} style={{ color: C.textDim }} />
              </button>
            );
          })}
        </div>
      </div>
    );
  }

  return (
    <div className="px-4 pt-4 pb-24">
      <button onClick={() => setSelectedMemberId(null)} className="flex items-center gap-1 text-xs mb-3" style={{ color: C.textDim, fontWeight: 700 }}><ArrowLeft size={13} /> Alle Mitglieder</button>
      <SectionTitle eyebrow={selectedMember.team} title={selectedMember.name} />
      <div className="space-y-2 mb-5">
        {memberRecords.map((record) => (
          <div key={record.id} className="rounded-2xl p-3.5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <div className="flex items-start justify-between gap-2">
              <div><div className="text-sm" style={{ fontWeight: 700, color: C.ink }}>{record.type}</div><div className="text-[11px]" style={{ color: C.textDim }}>Jahr {record.year} · {record.invoiceNumber || "ohne Rechnungsnummer"}</div></div>
              <div className="text-right"><div className="text-sm" style={{ fontFamily: "JetBrains Mono", fontWeight: 700 }}>{record.amount} €</div></div>
            </div>
            {record.type === "Familienbeitrag" && (
              <div className="mt-2 rounded-xl px-3 py-2 text-[11px]" style={{ background: C.paperDim, color: C.textDim }}>
                <div style={{ fontWeight: 700, color: C.ink }}>{record.personCount || 1} Personen im Familienbeitrag</div>
                {[...(record.linkedMemberIds || []).map((id) => members.find((member) => member.id === id)?.name).filter(Boolean), ...(record.manualNames || [])].length > 0 && (
                  <div className="mt-0.5">{[...(record.linkedMemberIds || []).map((id) => members.find((member) => member.id === id)?.name).filter(Boolean), ...(record.manualNames || [])].join(", ")}</div>
                )}
              </div>
            )}
            <div className="mt-2 flex items-center gap-2"><button onClick={() => togglePaid(record)} className="px-2.5 py-1 rounded-full text-[11px]" style={{ background: record.paid ? C.erfolgFlaeche : C.fehlerFlaeche, color: record.paid ? C.erfolg : C.fehler, fontWeight: 700 }}>{record.paid ? "Bezahlt ✓" : "Noch nicht bezahlt"}</button><button onClick={() => deleteRecord(record)} className="px-2.5 py-1 rounded-full text-[11px]" style={{ background:C.paperDim,color:C.textDim,fontWeight:700 }}>Löschen</button></div>
          </div>
        ))}
        {memberRecords.length === 0 && <div className="rounded-2xl p-4 text-xs text-center" style={{ background: C.paperDim, color: C.textDim }}>Noch keine Beitragsdatensätze vorhanden.</div>}
      </div>
      <SectionTitle eyebrow="Neuer Datensatz" title="Beitrag hinterlegen" />
      {message&&<div className="mb-3 rounded-xl px-3 py-2 text-[11px] font-semibold" style={{background:message.includes("gespeichert")?C.erfolgFlaeche:C.fehlerFlaeche,color:message.includes("gespeichert")?C.erfolg:C.fehler}}>{message}</div>}
      <form onSubmit={addRecord} className="rounded-2xl p-4 space-y-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
        <div className="grid grid-cols-2 gap-2">
          <input value={form.year} onChange={(e) => setForm({ ...form, year: e.target.value })} placeholder="Jahr" inputMode="numeric" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
          <input value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="Beitragshöhe €" inputMode="decimal" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
        </div>
        <div>
          <label className="block text-[10px] mb-1" style={{ color: C.textDim, fontWeight: 700 }}>Beitragsart</label>
          <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value, linkedMemberIds: [], manualNames: "", personCount: e.target.value === "Familienbeitrag" ? "2" : "1" })} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}><option value="Mitgliedsbeitrag">Mitgliedsbeitrag</option><option value="Familienbeitrag">Familienbeitrag</option></select>
        </div>
        {form.type === "Familienbeitrag" && (
          <div className="rounded-xl p-3 space-y-3" style={{ background: C.paperDim, border: `1px solid ${C.line}` }}>
            <div>
              <div className="text-xs" style={{ fontWeight: 700, color: C.ink }}>Weitere Vereinsmitglieder</div>
              <div className="text-[10px] mt-0.5 mb-2" style={{ color: C.textDim }}>Alle Personen auswählen, die ebenfalls zu diesem Familienbeitrag gehören.</div>
              <div className="space-y-1.5 max-h-32 overflow-y-auto">
                {members.filter((member) => member.id !== selectedMemberId).map((member) => (
                  <label key={member.id} className="flex items-center gap-2 text-xs cursor-pointer">
                    <input type="checkbox" checked={form.linkedMemberIds.includes(member.id)} onChange={() => toggleFamilyMember(member.id)} />
                    <span style={{ color: C.ink }}>{member.name}</span><span className="text-[10px]" style={{ color: C.textDim }}>({member.team})</span>
                  </label>
                ))}
              </div>
            </div>
            <div>
              <label className="block text-[10px] mb-1" style={{ color: C.textDim, fontWeight: 700 }}>Weitere Namen ohne Benutzerkonto</label>
              <textarea value={form.manualNames} onChange={(e) => setForm({ ...form, manualNames: e.target.value })} placeholder="z. B. Max Mustermann, Lea Mustermann" rows={2} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none resize-none" style={{ background: C.glass }} />
              <div className="text-[9px] mt-1" style={{ color: C.textDim }}>Mehrere Namen bitte durch Komma trennen.</div>
            </div>
            <div>
              <label className="block text-[10px] mb-1" style={{ color: C.textDim, fontWeight: 700 }}>Anzahl der Personen insgesamt</label>
              <input value={form.personCount} onChange={(e) => setForm({ ...form, personCount: e.target.value })} min="1" type="number" inputMode="numeric" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.glass }} />
            </div>
          </div>
        )}
        <input value={form.invoiceNumber} onChange={(e) => setForm({ ...form, invoiceNumber: e.target.value })} placeholder="Rechnungsnummer (optional)" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
        <select value={form.paid} onChange={(e) => setForm({ ...form, paid: e.target.value })} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}><option value="offen">Noch nicht bezahlt</option><option value="bezahlt">Bezahlt</option></select>
        <button disabled={saving} type="submit" className="w-full py-2.5 rounded-xl text-xs" style={{ background: saving ? C.textDim : C.ink, color: C.white, fontWeight: 700 }}>{saving ? "Wird gespeichert …" : "Datensatz anlegen"}</button>
      </form>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Chat                                                                  */
/* ------------------------------------------------------------------ */
function ChatView({ user, channels, setChannels, activeId, setActiveId, members }) {
  /* ALLE Hooks stehen vor dem ersten return - ohne Ausnahme.
     Vorher lag der Ausstieg fuer "kein Kanal sichtbar" zwischen dem ersten und
     dem zweiten useState. Beim leeren Durchlauf rief die Komponente damit einen
     Hook auf, beim gefuellten drei. Sobald die Kanalliste zwischen leer und
     gefuellt wechselt - und genau das kann sie jetzt, weil ein Verein ohne
     Kanaele eine leere Liste bekommt statt der Demo-Kanaele -, wirft React
     "Rendered more hooks than during the previous render" und der Chat bricht
     ab. Die Regel gilt ausnahmslos: erst alle Hooks, dann jeder Ausstieg. */
  const [text, setText] = useState("");
  const [sendeFehler, setSendeFehler] = useState("");

  /* Sichtbare Kanaele.
     Die Mannschaftspruefung lautete "c.team === user.team" - also gegen die
     EINE Abkuerzung am Mitglied. Wer in Herren 1 und Herren 2 spielt, sah
     damit nur einen der beiden Kanaele; der andere fehlte ganz, obwohl er
     dort Mitglied ist. Ebenso fehlte dem Trainer der Kanal seiner
     Trainer-Mannschaft, sobald das nicht zufaellig auch seine Spielmannschaft
     war. Jetzt zaehlen alle Mannschaften der Person.
     Ein Kanal ohne Mannschaft (c.team leer) ist vereinsweit - etwa die
     Vereins-News. Er bleibt fuer alle sichtbar, sofern keine Rollen
     eingetragen sind; eine leere Rollenliste heisst ausdruecklich "alle",
     genau wie in der Datenbankregel.
     Aus der Datenbank kommen ohnehin nur erlaubte Kanaele - die Regel
     "members read channels" filtert bereits. Diese Pruefung hier traegt den
     Demo-Betrieb ohne Datenbank und darf ihr nur nicht widersprechen. */
  /* Kinder des Mitglieds. Auf dem Datensatz des Elternteils steht der Verweis
     mit relation "kind" - so legt es linkFamilyRecords an. */
  const kinderVon = (mitglied) => (mitglied?.familyLinks || [])
    .filter((verweis) => verweis.relation === "kind")
    .map((verweis) => (members || []).find((x) => x.id === verweis.memberId))
    .filter(Boolean);
  /* Nachbau der Datenbankregel "members read channels", Zeile fuer Zeile:
       (team_id is not null and gehoert_zu_mannschaft(team_id))
       or (team_id is null and (cardinality(visible_roles) = 0 or has_club_role(...)))
     Beim Mannschaftskanal entscheidet also NUR die Mannschaft, nicht die
     Rolle - und gehoert_zu_mannschaft zaehlt ausdruecklich auch Eltern, deren
     Kind in der Mannschaft steht. Ohne diesen Zweig waere die Ansicht
     strenger als die Datenbank: Sie bekaeme den Kanal geliefert und blendete
     ihn wieder aus, sodass Eltern den Mannschaftskanal ihres Kindes nirgends
     saehen. */
  /* Kein Admin-Kurzschluss. Die Datenbankregel kennt fuer Mannschaftskanaele
     ausdruecklich KEINE Ausnahme fuer Vorstand oder Geschaeftsfuehrung - wer
     nicht in der Mannschaft steht, liest dort nicht mit; das haelt
     20260904130000_demoverein_chat.sql als bewusste Datenschutzentscheidung
     fest. Fuer die Kanalliste war der Kurzschluss ohnehin wirkungslos, weil
     die Kanaele bereits gefiltert ankommen. Seit dieselbe Pruefung die
     EMPFAENGER bestimmt, wirkte er aber schreibend: notify_many trug jedem
     Admin den vollen Nachrichtentext ins Postfach - aus Kanaelen, die ihm die
     Datenbank verweigert. */
  const sichtbarFuer = (mitglied, kanal) => {
    if (kanal.team) {
      return memberInTeam(mitglied, kanal.team)
        || kinderVon(mitglied).some((kind) => memberInTeam(kind, kanal.team));
    }
    return !kanal.visibleRoles?.length || kanal.visibleRoles.some((r) => mitglied.roles?.includes(r));
  };
  const visibleChannels = channels.filter((c) => sichtbarFuer(user, c));
  const active = visibleChannels.find((c) => c.id === activeId) || visibleChannels[0];

  /* Apple-Richtlinie 1.2 verlangt bei nutzergenerierten Inhalten beides: melden
     UND blockieren. Gemeldet werden konnte bisher, blockieren nicht.
     Die Sperre gilt bewusst nur für die eigene Ansicht — sie ist kein
     Vereinsausschluss, den dürfen weiterhin nur Administratoren aussprechen.
     Deshalb liegt sie lokal auf dem Gerät und wird nicht in den Verein gespiegelt. */
  /* Die Sperrliste liegt in der Datenbank, nicht im Geraetespeicher.
     Vorher galt sie nur auf einem Geraet, war nach einer Neuinstallation weg
     und traf ueber den ANGEZEIGTEN NAMEN - zwei Mitglieder mit demselben Namen
     liessen sich nicht trennen, eine Umbenennung hob die Sperre auf. Jetzt
     trifft sie das Profil, und sie bleibt.
     Es bleibt dabei, dass sie nur die eigene Ansicht betrifft; ein
     Vereinsausschluss ist etwas anderes und bleibt der Vereinsleitung. */
  const [blocked, setBlocked] = useState([]);
  useEffect(() => {
    if (!supabase || !user.authProfileId || !isDbId(user.clubId)) return;
    let weg = false;
    supabase.from("blocked_authors").select("blocked_profile_id")
      .eq("profile_id", user.authProfileId).eq("club_id", user.clubId)
      .then(({ data }) => { if (!weg) setBlocked((data || []).map((z) => z.blocked_profile_id)); });
    return () => { weg = true; };
  }, [user.authProfileId, user.clubId]);

  /* Kein einziger Kanal sichtbar - moeglich, seit die Sichtbarkeit an der
     Mannschaft haengt: ein Mitglied ohne Mannschaft, ein Elternteil ohne
     Familienverknuepfung, ein frisch freigegebenes Konto. Und seit ein Verein
     ohne eigene Kanaele auch wirklich keine bekommt. */
  if (!active) {
    return (
      <div className="px-4 pt-4 pb-10">
        <div className="rounded-2xl p-5 text-center" style={{ background: C.paperDim }}>
          <MessageCircle size={22} style={{ color: C.textDim, margin: "0 auto 10px" }} />
          <div className="text-sm font-bold mb-1" style={{ color: C.ink, fontFamily: "Inter" }}>Noch kein Chat für dich</div>
          <div className="text-[11px] leading-snug" style={{ color: C.textDim, fontFamily: "Inter" }}>
            Chats gehören zu Mannschaften. Sobald du einer Mannschaft zugeordnet bist —
            oder dein Kind in einer steht — erscheint sie hier. Frag im Zweifel deinen
            Trainer oder die Vereinsverwaltung.
          </div>
        </div>
      </div>
    );
  }
  /* Wer schreiben darf, entscheiden die Schreibrollen des Kanals - sofern er
     welche hat. Nur wenn keine hinterlegt sind, greift adminOnly.

     Vorher stand hier "!active.adminOnly && ..." vor der Rollenpruefung. Beim
     Laden aus der Datenbank wird adminOnly aber auf true gesetzt, sobald ein
     Kanal ueberhaupt Schreibrollen hat (write_roles ist bei jedem
     Mannschaftskanal gefuellt). Die Rollenpruefung wurde damit nie erreicht,
     und uebrig blieb allein isAdmin. Trainer, Kapitaene und Teammanager standen
     also in write_roles, durften in der Oberflaeche aber nicht schreiben -
     obwohl die Datenbank es ihnen erlaubt haette. */
  const canPost = isAdmin(user)
    || (active.id === "news" && user.roles.includes("redakteur"))
    || (active.writeRoles ? active.writeRoles.some((r) => user.roles.includes(r)) : !active.adminOnly);

  const blockAuthor = async (autorId) => {
    if (!autorId || autorId === user.authProfileId || blocked.includes(autorId)) return;
    setBlocked((b) => [...b, autorId]);
    if (!supabase || !user.authProfileId || !isDbId(user.clubId)) return;
    const { error } = await supabase.from("blocked_authors").insert({
      profile_id: user.authProfileId, club_id: user.clubId, blocked_profile_id: autorId,
    });
    if (error) setBlocked((b) => b.filter((id) => id !== autorId));
  };
  const unblockAuthor = async (autorId) => {
    setBlocked((b) => b.filter((id) => id !== autorId));
    if (!supabase || !user.authProfileId || !isDbId(user.clubId)) return;
    const { error } = await supabase.from("blocked_authors").delete()
      .eq("profile_id", user.authProfileId).eq("club_id", user.clubId).eq("blocked_profile_id", autorId);
    if (error) setBlocked((b) => (b.includes(autorId) ? b : [...b, autorId]));
  };
  /* Fuer die Anzeige der Sperrliste braucht es Namen, gespeichert sind
     Kennungen. Wer nicht mehr im Verein ist, steht mit seiner alten Nachricht
     trotzdem da - deshalb der Rueckfall auf den Namen aus der Nachricht. */
  const nameZuProfil = (autorId) => (members || []).find((m) => m.authProfileId === autorId)?.name
    || (active?.messages || []).find((m) => m.authorId === autorId)?.who
    || "Unbekannt";

  /* Auf eine Meldung muss man auch reagieren koennen. Bisher gab es den
     Meldeknopf, aber niemand konnte eine Nachricht entfernen - auch der Vorstand
     nicht. Wer schreibt, darf zuruecknehmen; die Vereinsleitung darf jede
     Nachricht ihres Vereins entfernen. Trainer und Kapitaene bleiben aussen vor,
     sonst loescht der Kapitaen die unbequeme Nachricht seines Trainers.
     Dieselbe Aufteilung steht als Regel in der Datenbank - die Oberflaeche
     blendet nur aus, was ohnehin abgelehnt wuerde. */
  const darfModerieren = user.roles.some((r) => ["vorstand", "geschaeftsfuehrung", "vereinsadmin", "sysadmin"].includes(r));
  const nachrichtLoeschen = async (m) => {
    if (!window.confirm("Diese Nachricht dauerhaft loeschen?")) return;
    if (supabase && isDbId(m.id)) {
      const { error } = await supabase.from("messages").delete().eq("id", m.id);
      if (error) { setSendeFehler("Die Nachricht konnte nicht geloescht werden."); return; }
    }
    setSendeFehler("");
    setChannels((cs) => cs.map((c) => (c.id !== active.id ? c : { ...c, messages: c.messages.filter((x) => x.id !== m.id) })));
  };
  const visibleMessages = active.messages.filter((m) => m.authorId === user.authProfileId || !blocked.includes(m.authorId));

  const send = async () => {
    if (!text.trim() || !canPost) return;
    const inhalt = text.trim();

    /* In der Datenbank gefuehrte Kanaele: schreiben und auf die Bestaetigung
       warten. Erst danach steht die Nachricht in der Ansicht - sonst sieht der
       Absender sie liegen, obwohl sie nie ankam.
       Die Realtime-Meldung traegt sie bei allen anderen ein; beim Absender
       verhindert die Pruefung auf die Kennung, dass sie doppelt erscheint. */
    if (supabase && isDbId(active.id) && isDbId(user.authProfileId)) {
      setSendeFehler("");
      const { data: gespeichert, error } = await supabase
        .from("messages")
        .insert({ channel_id: active.id, author_id: user.authProfileId, body: inhalt })
        .select("id,channel_id,body,created_at,author_id,profiles(full_name)")
        .maybeSingle();
      if (error) {
        setSendeFehler("Die Nachricht konnte nicht gesendet werden.");
        return;
      }
      if (gespeichert) {
        setChannels((cs) => cs.map((c) => c.id !== active.id || c.messages.some((m) => m.id === gespeichert.id)
          ? c
          : { ...c, messages: [...c.messages, { ...zeileZuNachricht(gespeichert), me: true }].slice(-200) }));
      }
    } else {
      /* Demo-Betrieb ohne Datenbank: fluechtig, wie bisher. */
      setChannels((cs) => cs.map((c) => c.id === active.id
        ? { ...c, messages: [...c.messages, { who: user.name, init: initialsOf(user.name), color: user.color, text: inhalt, time: "jetzt", me: true }].slice(active.id === "news" ? -10 : -200) }
        : c));
    }
    if (supabase && Array.isArray(members)) {
      const recipients = members
        /* Spiegelbild der Sichtbarkeit: Benachrichtigt wird, wer den Kanal
           auch sehen darf. Vorher stand hier dieselbe Verkuerzung auf die
           eine Mannschaft - wer den Kanal sehen konnte, dessen Abkuerzung
           aber eine andere Mannschaft nannte, bekam nie eine Mitteilung und
           las die Nachricht erst zufaellig. */
        /* Wer noch nicht freigegeben ist, bekommt nichts. Die Mitgliederliste
           enthaelt auch Konten im Status "pending" - beim vereinsweiten
           News-Kanal, den jeder sehen darf, waeren das sonst Mitteilungen an
           Leute, die der Verein noch gar nicht aufgenommen hat. */
        .filter((m) => m.id !== user.id && !m.accountPending && sichtbarFuer(m, active))
        .map((m) => m.id)
        .filter((id) => isDbId(id));
      if (recipients.length > 0) {
        supabase.rpc("notify_many", { target_memberships: recipients, p_notif_type: "chat", p_title: `Neue Nachricht · ${active.name || "Chat"}`, p_body: `${user.name}: ${text.trim()}` });
      }
    }
    setText("");
  };

  return (
    /* Der Chat ist kein Scrollbereich mit Auslauf, sondern eine feste Saeule:
       Nachrichtenliste dehnbar, Schreibfeld unten buendig. Darum hier nicht
       pb-24 (das rechnet fuer Listen grosszuegig safe-area + 124px und liess
       genau die Luecke unter dem Schreibfeld), sondern die gemessene Hoehe der
       Navigationsleiste plus etwas Luft. */
    <div className="pt-4 flex flex-col" style={{ height: "100%", paddingBottom: "calc(var(--erg-nav-h, 96px) + 10px)" }}>
      <div className="px-4"><SectionTitle title="Chat" /></div>
      <div className="flex gap-2 px-4 mb-3 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {visibleChannels.map((c) => (
          <button key={c.id} onClick={() => setActiveId(c.id)} className="px-3 py-1.5 rounded-full text-xs flex-shrink-0"
            style={{ fontFamily: "Inter", fontWeight: 700, background: activeId === c.id ? C.ink : C.paperDim, color: activeId === c.id ? C.white : C.textDim }}>
            {c.emoji} {c.name}
          </button>
        ))}
      </div>
      {blocked.length > 0 && (
        <div className="mx-4 mb-3 rounded-xl px-3 py-2" style={{ background: C.paperDim }}>
          <div className="text-[10px] font-bold mb-1.5" style={{ color: C.textDim }}>Für dich ausgeblendet</div>
          <div className="flex flex-wrap gap-1.5">
            {blocked.map((autorId) => (
              <button key={autorId} onClick={() => unblockAuthor(autorId)} className="flex items-center gap-1 px-2 py-1 rounded-full text-[10px] font-bold" style={{ background: C.glass, border: `1px solid ${C.edge}`, color: C.ink }}>
                {nameZuProfil(autorId)} <X size={10} style={{ color: C.textDim }} />
              </button>
            ))}
          </div>
          <div className="text-[9px] mt-1.5" style={{ color: C.textDim }}>Tippe einen Namen an, um die Person wieder anzuzeigen.</div>
        </div>
      )}
      <div className="flex-1 overflow-y-auto px-4 space-y-3">
        {visibleMessages.map((m, i) => {
          /* Nach Kennung vergleichen, nicht nach Namen: Datenbank-Nachrichten
             tragen den Namen aus profiles, der angemeldete Nutzer seinen
             Anzeigenamen aus der Mitgliedschaft. Weichen die ab, erschienen
             eigene Nachrichten als fremde - samt "Melden" und "Blockieren" an
             der eigenen Nachricht. Der Namensvergleich bleibt als Rueckfall
             fuer den Demo-Betrieb ohne Datenbank. */
          const mine = m.authorId ? m.authorId === user.authProfileId : m.who === user.name;
          /* Den Namen aus der Mitgliederliste holen, nicht aus der Nachricht.
             In der Nachricht steht er naemlich fast nie: Er kommt dort ueber
             die Verknuepfung zu profiles, und die Leseregel gibt jedem nur das
             EIGENE Profil (initial_schema.sql:395). Bei fremden Nachrichten
             kam die Verknuepfung deshalb immer leer zurueck, und
             zeileZuNachricht fiel auf "Mitglied" zurueck - in jedem Verein, bei
             jeder fremden Nachricht.
             Die Mitgliederliste darf dagegen jedes Vereinsmitglied lesen
             (initial_schema.sql:398), sie liegt hier ohnehin vor, und der
             Anzeigename darin ist genau der, der auch in der Mitgliederansicht
             steht. Deshalb von dort - und nicht etwa die Leserechte an den
             Profilen aufweichen. */
          const verfasser = (m.authorId && (members || []).find((x) => x.authProfileId === m.authorId)?.name) || m.who;
          return (
            <div key={i} className={`flex gap-2 ${mine ? "flex-row-reverse" : ""}`}>
              <div className="w-7 h-7 rounded-full flex items-center justify-center text-[10px] font-bold flex-shrink-0" style={{ background: m.color, color: C.white, fontFamily: "Inter" }}>{initialsOf(verfasser) || m.init}</div>
              <div className={`max-w-[75%] ${mine ? "items-end" : "items-start"} flex flex-col`}>
                {!mine && <div className="text-[11px] mb-0.5" style={{ color: C.textDim, fontFamily: "Inter" }}>{verfasser}</div>}
                <div className="rounded-2xl text-sm overflow-hidden" style={{ fontFamily: "Inter", background: mine ? C.red : C.white, color: mine ? C.white : C.ink, border: mine ? "none" : `1px solid ${C.line}`, borderBottomRightRadius: mine ? 4 : 16, borderBottomLeftRadius: mine ? 16 : 4 }}>
                  {m.imageUrl && <img src={m.imageUrl} alt="" className="w-full block" style={{ maxHeight: 180, objectFit: "cover" }} />}
                  <div className="px-3 py-2">
                    {m.title && <div className="mb-1" style={{ fontFamily: "Oswald", fontWeight: 700, fontSize: 14 }}>{m.title}</div>}
                    {m.text}
                  </div>
                </div>
                <div className="flex items-center gap-2 mt-0.5">
                  <div className="text-[10px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.time}</div>
                  {!mine && <a href={`mailto:${legal.email}?subject=${encodeURIComponent("Nachricht melden - " + (active.name || "Chat"))}&body=${encodeURIComponent(`Ich möchte folgende Nachricht melden:\n\nVerfasser: ${m.who}\nInhalt: ${m.text || ""}\n\nGrund:\n`)}`} className="text-[10px]" style={{ color: C.textDim, fontFamily: "Inter", textDecoration: "underline" }}>Melden</a>}
                  {!mine && <button onClick={() => blockAuthor(m.authorId)} className="text-[10px]" style={{ color: C.textDim, fontFamily: "Inter", textDecoration: "underline" }}>Blockieren</button>}
                  {(mine || darfModerieren) && <button onClick={() => nachrichtLoeschen(m)} className="text-[10px]" style={{ color: C.textDim, fontFamily: "Inter", textDecoration: "underline" }}>Löschen</button>}
                </div>
              </div>
            </div>
          );
        })}
      </div>
      <div className="px-4 pt-3">
        {!canPost ? (
          <div className="text-xs text-center py-2 rounded-lg" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>{active.writeRoles ? "In dieser Gruppe schreiben Trainer, Kapitäne und freigegebene Teammitglieder." : "Nur berechtigte Rollen können hier schreiben."}</div>
        ) : (
          /* Der Fehler stand als Flex-Geschwister NEBEN dem Eingabefeld und
             quetschte es zusammen, sobald das Senden scheiterte. Er gehoert
             darueber. */
          <div>
            {sendeFehler && <div className="text-[10px] mb-1.5 rounded-xl px-3 py-2" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{sendeFehler}</div>}
            <div className="flex items-center gap-2">
            <input value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === "Enter" && send()} placeholder="Nachricht schreiben…"
              className="flex-1 px-3 py-2.5 rounded-full text-sm outline-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
            <button onClick={send} aria-label="Nachricht senden" className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: C.red }}><Send size={16} color="#fff" /></button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Redaktion (News schreiben)                                           */
/* ------------------------------------------------------------------ */
/* Die Vereins-News kommen aus der Tabelle news_posts.
 *
 * Vorher suchte diese Ansicht einen Chat-Kanal mit der Kennung "news". Den gab
 * es, solange die Kanaele fest im Code standen; seit sie aus der Tabelle
 * channels kommen, haben sie echte UUIDs - und die Suche ging fuer JEDEN
 * echten Verein ins Leere. Geschrieben wurde weiterhin nach news_posts,
 * gelesen wurde nichts: Die Vereins-News waren angelegt, aber unsichtbar.
 * Beim Anmelden wurden sie sogar geladen (samt signierter Bild-Adressen) und
 * das Ergebnis anschliessend weggeworfen. */
function RedaktionView({ user, news, setNews }) {
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState("");
  const [text, setText] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [imageFile, setImageFile] = useState(null);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [editingPost, setEditingPost] = useState(null);
  const items = (news || []).map((m, idx) => ({ ...m, idx })).reverse();

  const openEdit = (item) => {
    setEditingPost(item);
    setTitle(item.title || "");
    setText(item.text || "");
    setImageUrl(item.imageUrl || "");
    setImageFile(null);
    setMessage("");
    setShowForm(true);
  };
  const cancelForm = () => {
    setShowForm(false); setEditingPost(null);
    setTitle(""); setText(""); setImageUrl(""); setImageFile(null); setMessage("");
  };

  const deleteNews = async (item) => {
    if (!window.confirm(`News „${item.title || "Vereins-News"}“ wirklich löschen?`)) return;
    setMessage("");
    if (supabase && isDbId(item.id)) {
      const { data: imagePath, error } = await supabase.rpc("delete_news_post", { target_post: item.id });
      if (error) { setMessage("Die News konnte nicht gelöscht werden."); return; }
      if (imagePath) await supabase.storage.from("news-images").remove([imagePath]);
    }
    setNews((alle) => alle.filter((m, i) => (item.id ? m.id !== item.id : i !== item.idx)));
  };

  const onFile = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type) || file.size > 5 * 1024 * 1024) {
      setMessage("Bitte JPG, PNG oder WebP mit maximal 5 MB auswählen."); return;
    }
    setImageFile(file); setMessage("");
    const reader = new FileReader();
    reader.onload = () => setImageUrl(reader.result);
    reader.readAsDataURL(file);
  };

  const publish = async () => {
    if (!title.trim() || !text.trim()) return;
    setSaving(true); setMessage("");
    let id = editingPost?.id || `news-${Date.now()}`;
    let finalImageUrl = imageUrl || undefined;
    let imagePath = null;
    const databaseMembership = !!supabase && isDbId(user.id);
    if (databaseMembership) {
      if (imageFile) {
        const extension = imageFile.type === "image/png" ? "png" : imageFile.type === "image/webp" ? "webp" : "jpg";
        imagePath = `${user.clubId}/${Date.now()}-${Math.random().toString(36).slice(2)}.${extension}`;
        const { error: uploadError } = await supabase.storage.from("news-images").upload(imagePath, imageFile, { contentType: imageFile.type, upsert: false });
        if (uploadError) { setMessage("Das News-Bild konnte nicht hochgeladen werden."); setSaving(false); return; }
        const { data: signedImage, error: signedError } = await supabase.storage.from("news-images").createSignedUrl(imagePath, 604800);
        if (signedError) { await supabase.storage.from("news-images").remove([imagePath]); setMessage("Das News-Bild konnte nicht vorbereitet werden."); setSaving(false); return; }
        finalImageUrl = signedImage.signedUrl;
      }
      if (editingPost && isDbId(editingPost.id)) {
        const { data: replacedImagePath, error } = await supabase.rpc("update_news_post", {
          target_post: editingPost.id,
          new_title: title.trim(),
          new_body: text.trim(),
          new_image_path: imagePath,
        });
        if (error) { if (imagePath) await supabase.storage.from("news-images").remove([imagePath]); setMessage("Die News konnte nicht geändert werden."); setSaving(false); return; }
        if (replacedImagePath) await supabase.storage.from("news-images").remove([replacedImagePath]);
        if (!imageFile) finalImageUrl = editingPost.imageUrl;
      } else {
        const { data, error } = await supabase.rpc("create_news_post", {
          target_club: user.clubId,
          post_title: title.trim(),
          post_body: text.trim(),
          post_image_path: imagePath,
        });
        if (error) { if (imagePath) await supabase.storage.from("news-images").remove([imagePath]); setMessage("Die News konnte nicht gespeichert werden."); setSaving(false); return; }
        id = data;
      }
    }
    if (editingPost) {
      setNews((alle) => alle.map((m) => (m.id === editingPost.id
        ? { ...m, title: title.trim(), text: text.trim(), imageUrl: finalImageUrl, imagePath: imagePath || m.imagePath }
        : m)));
      cancelForm(); setSaving(false);
      return;
    }
    setNews((alle) => [...alle, {
      id, who: user.name, init: initialsOf(user.name), color: user.color,
      title: title.trim(), text: text.trim(), imageUrl: finalImageUrl, imagePath,
      time: new Date().toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "2-digit" }),
    }].slice(-100));
    setTitle(""); setText(""); setImageUrl(""); setImageFile(null); setShowForm(false); setSaving(false);
  };

  return (
    <div className="px-4 pt-4 pb-24">
      <SectionTitle title="Redaktion" eyebrow="Vereins-News" right={
        !showForm && <button onClick={() => setShowForm(true)} className="text-xs font-bold px-3 py-1.5 rounded-full" style={{ background: C.ink, color: "#fff", fontFamily: "Inter" }}>+ Neue News</button>
      } />

      {showForm && (
        <div className="rounded-2xl p-3 mb-5 space-y-2.5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          <div className="text-xs font-bold" style={{ fontFamily: "Inter", color: C.ink }}>{editingPost ? "News bearbeiten" : "Neue News"}</div>
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Titel"
            className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
          <textarea value={text} onChange={(e) => setText(e.target.value)} placeholder="Text der News…" rows={4}
            className="w-full px-3 py-2.5 rounded-lg text-sm outline-none resize-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
          <label className="flex items-center gap-2 px-3 py-2 rounded-lg text-xs cursor-pointer" style={{ background: C.paperDim, fontFamily: "Inter", color: C.textDim }}>
            <ImageIcon size={14} /> {imageUrl ? "Bild ändern" : "Bild auswählen (optional)"}
            <input type="file" accept="image/jpeg,image/png,image/webp" onChange={onFile} className="hidden" />
          </label>
          {imageUrl && <img src={imageUrl} alt="" className="w-full rounded-lg" style={{ maxHeight: 160, objectFit: "cover" }} />}
          <div className="flex gap-2">
            <button onClick={publish} disabled={saving || !title.trim() || !text.trim()} className="flex-1 py-2.5 rounded-lg text-xs" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: (saving || !title.trim() || !text.trim()) ? 0.5 : 1 }}>{saving ? "Wird gespeichert …" : editingPost ? "Änderungen speichern" : "Veröffentlichen"}</button>
            <button disabled={saving} onClick={cancelForm} className="px-4 py-2.5 rounded-lg text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter", fontWeight: 700 }}>Abbrechen</button>
          </div>
        </div>
      )}
      {message&&<div className="mb-3 rounded-xl px-3 py-2 text-[11px] font-semibold" style={{background:C.fehlerFlaeche,color:C.fehler}}>{message}</div>}

      <SectionTitle eyebrow="Veröffentlicht" title="Alle News" />
      <div className="space-y-2">
        {items.length === 0 ? (
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Noch keine News veröffentlicht.</div>
        ) : items.map((m) => (
          <div key={m.id || m.idx} className="rounded-2xl overflow-hidden" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            {m.imageUrl && <img src={m.imageUrl} alt="" className="w-full block" style={{ maxHeight: 160, objectFit: "cover" }} />}
            <div className="p-3">
              <div className="flex items-center justify-between mb-1">
                <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.who} · {m.time}</div>
                <div className="flex items-center gap-1.5 flex-shrink-0">
                  <button onClick={() => openEdit(m)} className="text-[11px] px-2 py-1 rounded-full" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter", fontWeight: 700 }}>Bearbeiten</button>
                  <button onClick={() => deleteNews(m)} className="text-[11px] px-2 py-1 rounded-full" style={{ background: C.fehlerFlaeche, color: C.fehler, fontFamily: "Inter", fontWeight: 700 }}>Löschen</button>
                </div>
              </div>
              {m.title ? <div className="text-sm mb-0.5" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{m.title}</div> : null}
              <div className="text-xs" style={{ fontFamily: "Inter", color: C.textDim }}>{m.text}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Familien-Stammbaum                                                   */
/* ------------------------------------------------------------------ */
function FamilyTree({ user, members }) {
  if (!user.familyId) {
    return (
      <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>
        Für dich ist noch kein Familienprofil hinterlegt. Du kannst es selbst ergänzen; bei Bedarf unterstützt der Sysadmin.
      </div>
    );
  }
  const family = members.filter((m) => m.familyId === user.familyId);
  const gen = (role) => family.filter((m) => m.familyRole === role);
  const rows = [
    { role: "großeltern", label: "Großeltern", list: gen("großeltern") },
    { role: "eltern", label: "Eltern", list: gen("eltern") },
    { role: "kind", label: "Kinder", list: gen("kind") },
  ].filter((r) => r.list.length);

  return (
    <div className="rounded-2xl p-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
      {rows.map((r, i) => (
        <div key={r.role}>
          <div className="text-[10px] uppercase tracking-widest font-semibold mb-2" style={{ color: C.textDim, fontFamily: "Inter" }}>{r.label}</div>
          <div className="flex flex-wrap gap-2 mb-2">
            {r.list.map((m) => (
              <div key={m.id} className="flex items-center gap-2 px-2.5 py-1.5 rounded-full" style={{ background: m.id === user.id ? C.fehlerFlaeche : C.paperDim, border: m.id === user.id ? `1px solid ${C.red}` : "none" }}>
                <div className="w-5 h-5 rounded-full flex items-center justify-center text-[9px] font-bold" style={{ background: m.color, color: "#fff" }}>{initialsOf(m.name)}</div>
                <span className="text-xs" style={{ fontFamily: "Inter", fontWeight: 600, color: C.ink }}>{m.name}{m.id === user.id ? " (Du)" : ""}</span>
              </div>
            ))}
          </div>
          {i < rows.length - 1 && <div className="w-px h-3 ml-4 mb-1" style={{ background: C.line }} />}
        </div>
      ))}
    </div>
  );
}

function FamilyLinkManager({ user, members, setMembers, adminMode = false }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [newName, setNewName] = useState("");
  const [relationMode, setRelationMode] = useState(user.roles.includes("eltern") ? "eltern" : "kind");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const databaseMembership = !!supabase && isDbId(user.id);
  const userIsParent = relationMode === "eltern";
  const wantedRole = userIsParent ? "spieler" : "eltern";
  const linkedIds = (user.familyLinks || []).map((l) => l.memberId);
  const familyConnections = members.filter((member) => linkedIds.includes(member.id));
  const results = members.filter((m) => m.id !== user.id && !linkedIds.includes(m.id) && !m.accountPending && m.roles.includes(wantedRole) && m.name.toLowerCase().includes(query.toLowerCase())).slice(0, 5);
  const connect = async (targetId) => {
    setSaving(true); setMessage("");
    let linkId = null;
    if (databaseMembership) {
      const { data, error } = await supabase.rpc("create_family_link", {
        target_club: user.clubId,
        acting_membership: user.id,
        related_membership: targetId,
        acting_relation: userIsParent ? "eltern" : "kind",
      });
      if (error) { setMessage("Die Verknüpfung konnte nicht gespeichert werden."); setSaving(false); return; }
      linkId = data;
    }
    setMembers((ms) => linkFamilyRecords(ms, user.id, targetId, userIsParent ? "eltern" : "kind", linkId));
    setQuery(""); setOpen(false); setSaving(false);
  };
  const createDependent = async () => {
    if (!newName.trim() || !userIsParent) return;
    setSaving(true); setMessage("");
    let id = `dependent-${Date.now()}`;
    let linkId = null;
    if (databaseMembership) {
      const { data, error } = await supabase.rpc("create_managed_child", {
        target_club: user.clubId,
        parent_membership: user.id,
        child_name: newName.trim(),
        child_birthdate: null,
        child_team: null,
      });
      if (error || !data?.membership_id) { setMessage("Das Kinderprofil konnte nicht gespeichert werden."); setSaving(false); return; }
      id = data.membership_id;
      linkId = data.family_link_id;
    }
    const child = { id, clubId: user.clubId, name: newName.trim(), email: "", password: "", team: "U11", number: null, since: new Date().getFullYear(), roles: ["mitglied", "spieler"], color: AVATAR_FARBEN[2], points: 0, tippPoints: 0, badges: [], birthdate: "", accountPending: true };
    setMembers((ms) => linkFamilyRecords([...ms, child], user.id, id, "eltern", linkId));
    setNewName(""); setOpen(false); setSaving(false);
  };
  const removeConnection = async (target) => {
    if (!window.confirm(`Familienverknüpfung zu ${target.name} wirklich löschen? Die Verbindung wird in beiden Profilen entfernt.`)) return;
    setSaving(true); setMessage("");
    const link = (user.familyLinks || []).find((item) => item.memberId === target.id);
    if (databaseMembership && link?.linkId) {
      const { error } = await supabase.rpc("delete_family_link", { target_link: link.linkId, acting_membership: user.id });
      if (error) { setMessage("Die Verknüpfung konnte nicht gelöscht werden."); setSaving(false); return; }
    }
    setMembers((all) => unlinkFamilyRecords(all, user.id, target.id));
    setSaving(false);
  };
  return <div className="rounded-2xl p-4 mb-5" style={{background:C.glass,border:`1px solid ${C.line}`}}>
    <div className="flex items-center justify-between"><div><div className="text-sm font-bold" style={{color:C.ink}}>Familienverknüpfung</div><div className="text-[11px]" style={{color:C.textDim}}>{adminMode ? `Sysadmin bearbeitet das Profil von ${user.name}.` : "Du verwaltest dein Familienprofil selbst."} Verknüpfungen gelten automatisch für beide Profile.</div></div><button disabled={saving} onClick={()=>setOpen(!open)} className="px-3 py-1.5 rounded-full text-xs font-bold" style={{background:C.paperDim,color:C.ink}}>{open?"Schließen":"＋ Verknüpfen"}</button></div>
    {message&&<div className="mt-2 text-[11px] font-semibold" style={{color:C.red}}>{message}</div>}
    {familyConnections.length>0&&<div className="mt-3 pt-3 space-y-1.5" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[10px] font-bold mb-1" style={{color:C.textDim}}>BESTEHENDE VERKNÜPFUNGEN</div>{familyConnections.map((member)=><div key={member.id} className="flex items-center gap-2 px-3 py-2 rounded-xl" style={{background:C.paperDim}}><div className="w-6 h-6 rounded-full flex items-center justify-center text-[9px] font-bold" style={{background:member.color,color:C.white}}>{initialsOf(member.name)}</div><div className="flex-1 min-w-0"><div className="text-xs font-bold truncate" style={{color:C.ink}}>{member.name}</div><div className="text-[10px]" style={{color:C.textDim}}>{member.familyRole||"Familie"}</div></div><button onClick={()=>removeConnection(member)} className="px-2.5 py-1.5 rounded-lg text-[10px] font-bold" style={{background:C.fehlerFlaeche,color:C.fehler}}>Löschen</button></div>)}</div>}
    {open&&<div className="mt-3 pt-3" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[11px] font-bold mb-1">Rolle in der Verknüpfung</div><select value={relationMode} onChange={(e)=>{setRelationMode(e.target.value);setQuery("");}} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{background:C.paperDim}}><option value="eltern">Elternteil – Athlet/in oder Kind hinzufügen</option><option value="kind">Athlet/in / Kind – Elternteil hinzufügen</option></select><input value={query} onChange={(e)=>setQuery(e.target.value)} placeholder={userIsParent?"Vorhandenen Athlet/in suchen …":"Vorhandenes Elternteil suchen …"} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{background:C.paperDim}}/>{query&&<div className="space-y-1">{results.map(m=><button key={m.id} onClick={()=>connect(m.id)} className="w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs" style={{background:C.paperDim,color:C.ink}}><span>{m.name} · {m.team}</span><span style={{color:C.red}}>Verbinden</span></button>)}{results.length===0&&<div className="text-[11px] py-2" style={{color:C.textDim}}>Kein passendes Profil gefunden.</div>}</div>}{userIsParent&&<div className="mt-3 pt-3" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[11px] font-bold mb-2">Kind ohne Account vorläufig anlegen</div><div className="flex gap-2"><input value={newName} onChange={(e)=>setNewName(e.target.value)} placeholder="Vor- und Nachname" className="flex-1 px-3 py-2 rounded-lg text-xs outline-none" style={{background:C.paperDim}}/><button onClick={createDependent} disabled={!newName.trim()} className="px-3 rounded-lg text-xs font-bold" style={{background:newName.trim()?C.red:C.line,color:"#fff"}}>Anlegen</button></div><div className="text-[10px] mt-2" style={{color:C.textDim}}>Das Kind kann sein vorläufiges Profil später beim Erstellen des eigenen Kontos übernehmen.</div></div>}</div>}
  </div>;
}

function AdminFamilyPanel({ members, setMembers }) {
  const [selectedId, setSelectedId] = useState("");
  const selected = members.find((member) => member.id === selectedId);
  return <div className="space-y-3"><div className="text-xs" style={{color:C.textDim}}>Nur der Sysadmin kann Familienprofile anderer Mitglieder ergänzen. Vorstand und weitere Verwaltungsrollen haben keinen Zugriff.</div><select value={selectedId} onChange={(e)=>setSelectedId(e.target.value)} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.glass,border:`1px solid ${C.line}`}}><option value="">Mitglied auswählen …</option>{members.map((member)=><option key={member.id} value={member.id}>{member.name} · {member.team}</option>)}</select>{selected&&<><FamilyTree user={selected} members={members}/><FamilyLinkManager user={selected} members={members} setMembers={setMembers} adminMode /></>}</div>;
}

/* ------------------------------------------------------------------ */
/* Profil                                                                */
/* ------------------------------------------------------------------ */
function TrainerTeamSettings({ user, members, setMembers }) {
  const [teams, setTeams] = useState([]);
  const [selectedTeamId, setSelectedTeamId] = useState("");
  const [players, setPlayers] = useState([]);
  const [captainId, setCaptainId] = useState("");
  const [savedCaptainId, setSavedCaptainId] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const databaseMembership = !!supabase && isDbId(user.id);

  useEffect(() => {
    const loadTrainerTeams = async () => {
      setLoading(true); setMessage("");
      if (!databaseMembership) {
        /* Kein Rueckfall auf user.team: Das ist die Spielmannschaft und macht
           aus einem Spieler keinen Trainer. Wer keine Trainer-Zuordnung hat,
           bekommt hier auch keine Mannschaft. */
        const assignedNames = memberTrainerTeams(user);
        const allNames = [...new Set([...TEAMS.filter((name) => name !== "Eltern / Angehörige"), ...members.flatMap((member) => memberPlayerTeams(member))])];
        const allLocalTeams = allNames.map((name) => ({ id: name, name }));
        const localTeams = allLocalTeams.filter((team) => assignedNames.includes(team.name));
        setTeams(localTeams); setSelectedTeamId((current) => current || hoechstesTeam(localTeams)?.id || ""); setLoading(false); return;
      }
      const { data, error } = await supabase.from("team_members").select("team_id,teams(id,name)").eq("membership_id", user.id).eq("function", "trainer");
      if (error) { setMessage("Die Trainer-Mannschaften konnten nicht geladen werden."); setLoading(false); return; }
      const assigned = (data || []).map((entry) => Array.isArray(entry.teams) ? entry.teams[0] : entry.teams).filter(Boolean);
      setTeams(assigned); setSelectedTeamId((current) => current || hoechstesTeam(assigned)?.id || ""); setLoading(false);
    };
    loadTrainerTeams();
  }, [user.id]);

  useEffect(() => {
    if (!selectedTeamId) { setPlayers([]); setCaptainId(""); setSavedCaptainId(""); return; }
    const loadRoster = async () => {
      setMessage("");
      if (!databaseMembership) {
        const selectedTeam = teams.find((team) => team.id === selectedTeamId)?.name;
        /* Verglichen wurde member.team - also die eine Abkuerzung. Im Kader der
           U15 fehlten damit alle, deren Abkuerzung "Herren 2" lautet, obwohl
           sie in beiden spielen: Der Trainer konnte sie nicht zum Kapitaen
           machen. Der Datenbankpfad darunter macht es laengst richtig, er
           liest team_members. */
        const roster = members.filter((member) => memberPlayerTeams(member).includes(selectedTeam)).map((member) => ({ id: member.id, name: member.name }));
        const captain = roster.find((player) => members.find((member) => member.id === player.id)?.roles.includes("kapitaen"))?.id || "";
        setPlayers(roster); setCaptainId(captain); setSavedCaptainId(captain); return;
      }
      const { data, error } = await supabase.from("team_members")
        .select("membership_id,function,club_memberships(id,display_name,status)")
        .eq("team_id", selectedTeamId).in("function", ["spieler", "kapitaen"]);
      if (error) { setMessage("Der Mannschaftskader konnte nicht geladen werden."); return; }
      const playerMap = new Map(); let currentCaptain = "";
      (data || []).forEach((entry) => {
        const membership = Array.isArray(entry.club_memberships) ? entry.club_memberships[0] : entry.club_memberships;
        if (!membership || membership.status !== "active") return;
        if (entry.function === "spieler") playerMap.set(entry.membership_id, { id: entry.membership_id, name: membership.display_name });
        if (entry.function === "kapitaen") currentCaptain = entry.membership_id;
      });
      const roster = [...playerMap.values()].sort((a, b) => a.name.localeCompare(b.name, "de"));
      setPlayers(roster); setCaptainId(currentCaptain); setSavedCaptainId(currentCaptain);
    };
    loadRoster();
  }, [selectedTeamId, databaseMembership, teams, members]);

  const saveCaptain = async () => {
    if (!captainId) { setMessage("Bitte zuerst einen Athlet/in auswählen."); return; }
    setSaving(true); setMessage("");
    if (!databaseMembership) {
      const selectedTeam = teams.find((team) => team.id === selectedTeamId)?.name;
      /* Die Datenbank laesst genau einen Kapitaen je Mannschaft zu (Index
         one_captain_per_team) - die Ansicht muss dasselbe tun. Entscheidend
         ist dabei, die Kapitaenswuerde MANNSCHAFTSWEISE zu fuehren: Die Rolle
         "kapitaen" steht global am Mitglied, und wer sie pauschal entzieht,
         nimmt sie auch dem Kapitaen einer ANDEREN Mannschaft, der hier bloss
         mitspielt. Deshalb wird captainTeams gepflegt und die Rolle erst
         entzogen, wenn dort nichts mehr uebrig ist. */
      setMembers((items) => items.map((member) => {
        if (member.id === captainId) {
          const roles = member.roles.includes("kapitaen") ? member.roles : [...member.roles, "kapitaen"];
          return { ...member, roles, captainTeams: [...new Set([...memberCaptainTeams(member), selectedTeam])] };
        }
        if (!memberCaptainTeams(member).includes(selectedTeam)) return member;
        const captainTeams = memberCaptainTeams(member).filter((name) => name !== selectedTeam);
        const roles = captainTeams.length ? member.roles : member.roles.filter((role) => role !== "kapitaen");
        return { ...member, roles, captainTeams };
      }));
      setSavedCaptainId(captainId); setMessage("Kapitän wurde für diese Mannschaft gespeichert."); setSaving(false); return;
    }
    const { error } = await supabase.rpc("set_team_captain", { target_team: selectedTeamId, target_membership: captainId });
    if (error) setMessage("Der Kapitän konnte nicht gespeichert werden.");
    else { setSavedCaptainId(captainId); setMessage("Kapitän wurde für diese Mannschaft gespeichert."); }
    setSaving(false);
  };

  return <div className="rounded-2xl p-4 mb-5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
    <div className="flex items-center gap-2 mb-1 text-sm font-bold" style={{ color: C.ink }}><Trophy size={15} style={{ color: C.secondary }}/> Trainer-Einstellungen</div>
    <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Deine Trainer-Mannschaften werden vom Vereinsadmin oder Sys-Admin zugewiesen. Für diese Teams kannst du anschließend einen Athlet/in als Kapitän bestimmen.</div>
    {loading ? <div className="text-xs py-3" style={{ color: C.textDim }}>Mannschaften werden geladen …</div> : <>
      <div className="text-[10px] font-bold mb-1" style={{ color: C.textDim }}>ZUGEWIESENE TRAINER-MANNSCHAFTEN</div>
      <div className="space-y-1.5 mb-4">{teams.map((team) => <div key={team.id} className="w-full flex items-center justify-between px-3 py-2 rounded-xl" style={{ background: C.primaerWeich, border: "1px solid C.red" }}><span className="text-xs font-bold" style={{ color: C.ink }}>{team.name}</span><Check size={14} style={{ color: C.red }}/></div>)}</div>
      {teams.length === 0 ? <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Dir wurde noch keine Mannschaft als Trainer/in zugewiesen. Bitte wende dich an den Vereinsadmin.</div> : <>
      <div className="pt-3 mb-3" style={{ borderTop: `1px solid ${C.line}` }}><div className="text-xs font-bold" style={{ color: C.ink }}>Kapitänsrolle zuweisen</div><div className="text-[10px]" style={{ color: C.textDim }}>Die Kapitänsrolle gilt immer für die ausgewählte Mannschaft.</div></div>
      <div className="text-[10px] font-bold mb-1" style={{ color: C.textDim }}>MANNSCHAFT</div>
      <select value={selectedTeamId} onChange={(event) => setSelectedTeamId(event.target.value)} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-3" style={{ background: C.paperDim, color: C.ink }}>{teams.map((team) => <option key={team.id} value={team.id}>{team.name}</option>)}</select>
      <div className="text-[10px] font-bold mb-1" style={{ color: C.textDim }}>KAPITÄN</div>
      <select value={captainId} onChange={(event) => { setCaptainId(event.target.value); setMessage(""); }} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-3" style={{ background: C.paperDim, color: C.ink }}><option value="">Athlet/in auswählen …</option>{players.map((player) => <option key={player.id} value={player.id}>{player.name}</option>)}</select>
      {players.length === 0 && <div className="text-[11px] -mt-1 mb-3" style={{ color: C.textDim }}>Für diese Mannschaft sind noch keine aktiven Athlet/innen hinterlegt.</div>}
      <button onClick={saveCaptain} disabled={!captainId || saving || captainId === savedCaptainId} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: captainId && captainId !== savedCaptainId ? C.ink : C.paperDim, color: captainId && captainId !== savedCaptainId ? C.white : C.textDim, opacity: saving ? .6 : 1 }}>{saving ? "Wird gespeichert …" : captainId === savedCaptainId && captainId ? "Kapitän gespeichert" : "Kapitän speichern"}</button>
      </>}
    </>}
    {message && <div role="status" className="text-[11px] mt-2" style={{ color: message.includes("gespeichert") ? C.erfolg : C.fehler }}>{message}</div>}
  </div>;
}

function PlayerTeamSettings({ user, setMembers }) {
  const [teams, setTeams] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const databaseMembership = !!supabase && isDbId(user.id);
  useEffect(() => {
    const load = async () => {
      setLoading(true); setMessage("");
      if (!databaseMembership) {
        const names = memberPlayerTeams(user);
        setTeams(names.map((name) => ({ id: name, name })));
        setLoading(false); return;
      }
      const [{ data: teamData, error: teamError }, { data: assignmentData, error: assignmentError }] = await Promise.all([
        supabase.from("teams").select("id,name,category").eq("club_id", user.clubId).eq("active", true).order("name"),
        supabase.from("team_members").select("team_id").eq("membership_id", user.id).eq("function", "spieler"),
      ]);
      if (teamError || assignmentError) { setMessage("Deine Mannschaften konnten nicht geladen werden."); setLoading(false); return; }
      /* Hier standen zwei Aufrufe von setMyTeamIds - einer Funktion, die es
         nirgends gibt. Sie warfen mitten im Laden, noch vor setLoading(false),
         sodass "Meine Mannschaften" dauerhaft auf "Wird geladen ..." stand.
         Gelesen wurde der Wert nie: Die Kanaele filtert die Datenbankregel
         "members read channels" ueber team_members, und in der Ansicht
         entscheidet memberInTeam ueber alle Mannschaften der Person. */
      const myIds = (assignmentData || []).map((entry) => entry.team_id);
      setTeams((teamData || []).filter((team) => myIds.includes(team.id)));
      setLoading(false);
    };
    load();
  }, [user.id, user.clubId, databaseMembership]);
  return <div className="rounded-2xl p-4 mb-5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
    <div className="flex items-center gap-2 mb-1 text-sm font-bold" style={{ color: C.ink }}><Users size={15} style={{ color: C.secondary }}/> Meine Mannschaften</div>
    <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Deine Mannschaftszuordnung wird von Trainer, Teammanager oder Vereins-Admin verwaltet.</div>
    {loading ? <div className="text-xs py-3" style={{ color: C.textDim }}>Wird geladen …</div> : teams.length === 0 ? <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Du bist aktuell keiner Mannschaft zugeordnet.</div> : <div className="flex flex-wrap gap-2">{teams.map((team) => <span key={team.id} className="px-3 py-1.5 rounded-full text-xs font-bold" style={{ background: C.erfolgFlaeche, color: C.erfolg }}>{team.name}</span>)}</div>}
    {message && <div role="status" className="text-[11px] mt-2" style={{ color: C.red }}>{message}</div>}
  </div>;
}
function TeamsView({ currentUser, members, setMembers, currentClub }) {
  const [teams, setTeams] = useState([]);
  const [selectedTeamId, setSelectedTeamId] = useState("");
  const [selectedPlayerId, setSelectedPlayerId] = useState("");
  const [showPlayerPicker, setShowPlayerPicker] = useState(false);
  const [showNewPlayer, setShowNewPlayer] = useState(false);
  const [newPlayerName, setNewPlayerName] = useState("");
  const [creatingPlayer, setCreatingPlayer] = useState(false);
  const [playerTeamIds, setPlayerTeamIds] = useState([]);
  const [savedPlayerTeamIds, setSavedPlayerTeamIds] = useState([]);
  const [savingPlayer, setSavingPlayer] = useState(false);
  const [playerMessage, setPlayerMessage] = useState("");
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [category, setCategory] = useState("");
  const [isAdultTeam, setIsAdultTeam] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [editingTeam, setEditingTeam] = useState(false);
  const [editName, setEditName] = useState("");
  const [editCategory, setEditCategory] = useState("");
  const [savingTeamEdit, setSavingTeamEdit] = useState(false);
  const [archivingTeam, setArchivingTeam] = useState(false);
  const databaseMembership = !!supabase && isDbId(currentUser.id);
  const canCreate = currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role));
  const canAssignPlayers = currentUser.roles.some((role) => ["vereinsadmin", "sysadmin", "trainer", "teammanager"].includes(role));
  const [canManagePenalties, setCanManagePenalties] = useState(false);
  const [penaltyRules, setPenaltyRules] = useState([]);
  const [assignRuleId, setAssignRuleId] = useState("");
  const [assigningPenalty, setAssigningPenalty] = useState(false);
  const [penaltyMessage, setPenaltyMessage] = useState("");
  const [playerPenalties, setPlayerPenalties] = useState([]);
  const [teamsOpen, setTeamsOpen] = useState(false);
  const [penaltyOpen, setPenaltyOpen] = useState(false);
  useEffect(() => {
    if (!databaseMembership || !selectedTeamId) { setCanManagePenalties(false); setPenaltyRules([]); return; }
    const checkPenaltyAccess = async () => {
      const { data } = await supabase.from("team_members")
        .select("function")
        .eq("team_id", selectedTeamId)
        .eq("membership_id", currentUser.id)
        .in("function", ["trainer", "kapitaen", "teammanager"]);
      setCanManagePenalties((data || []).length > 0);
      const { data: rules } = await supabase.from("team_penalty_rules")
        .select("id,title,amount").eq("team_id", selectedTeamId).order("title");
      setPenaltyRules((rules || []).map((r) => ({ ...r, amount: Number(r.amount) })));
    };
    checkPenaltyAccess();
  }, [databaseMembership, selectedTeamId, currentUser.id]);
  useEffect(() => {
    if (!databaseMembership || !selectedPlayerId || !selectedTeamId) { setPlayerPenalties([]); return; }
    const loadPlayerPenalties = async () => {
      const { data } = await supabase.from("team_penalty_assignments")
        .select("id,assigned_at,paid_at,team_penalty_rules(title,amount)")
        .eq("team_id", selectedTeamId)
        .eq("membership_id", selectedPlayerId)
        .is("archived_season", null)
        .order("assigned_at", { ascending: false });
      setPlayerPenalties((data || []).map((entry) => {
        const rule = Array.isArray(entry.team_penalty_rules) ? entry.team_penalty_rules[0] : entry.team_penalty_rules;
        return { id: entry.id, title: rule?.title || "—", amount: Number(rule?.amount || 0), assignedAt: entry.assigned_at, paidAt: entry.paid_at };
      }));
    };
    loadPlayerPenalties();
  }, [databaseMembership, selectedPlayerId, selectedTeamId, penaltyMessage]);
  const assignPenaltyToPlayer = async () => {
    if (!assignRuleId || !selectedPlayerId) return;
    setAssigningPenalty(true); setPenaltyMessage("");
    const { error } = await supabase.from("team_penalty_assignments")
      .insert({ team_id: selectedTeamId, rule_id: assignRuleId, membership_id: selectedPlayerId });
    if (error) { setPenaltyMessage("Die Strafe konnte nicht zugewiesen werden."); setAssigningPenalty(false); return; }
    setAssignRuleId(""); setPenaltyMessage("Strafe wurde zugewiesen."); setAssigningPenalty(false);
  };
  const removePlayerPenalty = async (penalty) => {
    if (!window.confirm("Strafe wirklich entfernen?")) return;
    setPenaltyMessage("");
    const { error } = await supabase.from("team_penalty_assignments").delete().eq("id", penalty.id);
    if (error) { setPenaltyMessage("Konnte nicht entfernt werden."); return; }
    setPlayerPenalties((current) => current.filter((item) => item.id !== penalty.id));
    setPenaltyMessage("Strafe wurde entfernt.");
  };
  const togglePlayerPenaltyPaid = async (penalty) => {
    setPenaltyMessage("");
    const nextPaid = !penalty.paidAt;
    if (databaseMembership) {
      const { error } = await supabase.rpc("mark_penalty_paid", { target_assignment: penalty.id, mark_paid: nextPaid });
      if (error) { setPenaltyMessage("Bezahlt-Status konnte nicht geändert werden."); return; }
    }
    setPlayerPenalties((current) => current.map((item) => item.id === penalty.id ? { ...item, paidAt: nextPaid ? new Date().toISOString() : null } : item));
    setPenaltyMessage(nextPaid ? "Strafe als bezahlt markiert." : "Strafe als offen markiert.");
  };

  const loadTeams = useCallback(async () => {
    setLoading(true); setMessage("");
    if (!databaseMembership) {
      const names = [...new Set([...TEAMS.filter((team) => team !== "Eltern / Angehörige"), ...members.flatMap((member) => memberPlayerTeams(member))])];
      setTeams((current) => names.map((teamName) => current.find((team) => team.name === teamName) || { id: teamName, name: teamName, category: "Mannschaft" }));
      setLoading(false); return;
    }
    const { data, error } = await supabase.from("teams").select("id,name,category,active").eq("club_id", currentUser.clubId).eq("active", true).order("name");
    if (error) setMessage("Die Mannschaften konnten nicht geladen werden.");
    else setTeams(data || []);
    setLoading(false);
  }, [databaseMembership, currentUser.clubId, members]);
  useEffect(() => { loadTeams(); }, [loadTeams]);

  const rosterFor = (team) => members.filter((member) => member.roles.includes("spieler") && memberPlayerTeams(member).includes(team.name)).sort((a, b) => a.name.localeCompare(b.name, "de"));
  const ownNames = memberPlayerTeams(currentUser);
  const ownTeams = teams.filter((team) => ownNames.includes(team.name));
  const selectedTeam = teams.find((team) => team.id === selectedTeamId);
  const selectedPlayer = members.find((member) => member.id === selectedPlayerId);
  const players = members.filter((member) => member.roles.includes("spieler")).sort((a, b) => a.name.localeCompare(b.name, "de"));
  const openPlayer = (player) => {
    const assignedNames = memberPlayerTeams(player);
    const assignedIds = teams.filter((team) => assignedNames.includes(team.name)).map((team) => team.id);
    setSelectedPlayerId(player.id);
    setPlayerTeamIds(assignedIds);
    setSavedPlayerTeamIds(assignedIds);
    setPlayerMessage("");
    setTeamsOpen(false);
    setPenaltyOpen(false);
  };
  const createPlayerWithoutAccount = async () => {
    if (!newPlayerName.trim() || !canAssignPlayers) return;
    setCreatingPlayer(true); setPlayerMessage("");
    let id = `player-${Date.now()}`;
    if (databaseMembership) {
      const { data, error } = await supabase.rpc("create_team_player", {
        target_club: currentUser.clubId,
        player_name: newPlayerName.trim(),
        membership_number: null,
      });
      if (error || !data) { setPlayerMessage("Der Spieler konnte nicht angelegt werden."); setCreatingPlayer(false); return; }
      id = data;
    }
    const player = { id, clubId: currentUser.clubId, name: newPlayerName.trim(), email: "", password: "", team: "", number: null, since: new Date().getFullYear(), roles: ["mitglied", "spieler"], color: AVATAR_FARBEN[2], points: 0, tippPoints: 0, badges: [], birthdate: "", accountPending: true };
    setMembers((ms) => [...ms, player]);
    setNewPlayerName(""); setShowNewPlayer(false); setCreatingPlayer(false);
    openPlayer(player);
  };
  const togglePlayerTeam = (teamId) => {
    setPlayerMessage("");
    setPlayerTeamIds((current) => {
      if (current.includes(teamId)) return current.filter((id) => id !== teamId);
      if (current.length >= 3) { setPlayerMessage("Athlet/innen können höchstens drei Mannschaften zugeordnet sein."); return current; }
      return [...current, teamId];
    });
  };
  const savePlayerTeams = async () => {
    if (!selectedPlayer || !canAssignPlayers) return;
    setSavingPlayer(true); setPlayerMessage("");
    if (databaseMembership) {
      const { error } = await supabase.rpc("set_managed_player_teams", {
        target_club: currentUser.clubId,
        target_membership: selectedPlayer.id,
        target_team_ids: playerTeamIds,
      });
      if (error) { setPlayerMessage("Die Mannschaftszuordnung konnte nicht gespeichert werden."); setSavingPlayer(false); return; }
    }
    const assignedNames = teams.filter((team) => playerTeamIds.includes(team.id)).map((team) => team.name);
    setMembers((items) => items.map((member) => member.id === selectedPlayer.id ? {
      ...member,
      playerTeams: assignedNames,
      team: hoechsteMannschaft(assignedNames) || "Mitglied",
      teams: [...new Set([...assignedNames, ...(member.trainerTeams || []), member.managedTeam].filter(Boolean))],
    } : member));
    setSavedPlayerTeamIds(playerTeamIds);
    setPlayerMessage("Mannschaftszuordnung gespeichert.");
    setSavingPlayer(false);
  };
  const createTeam = async (event) => {
    event.preventDefault();
    if (!name.trim()) { setMessage("Bitte einen Mannschaftsnamen eingeben."); return; }
    setSaving(true); setMessage("");
    let createdId = `team-${Date.now()}`;
    if (databaseMembership) {
      const { data, error } = await supabase.rpc("create_club_team", { target_club: currentUser.clubId, team_name: name.trim(), team_category: category.trim() || null, team_is_adult: isAdultTeam });
      if (error) { setMessage(error.message?.includes("already exists") ? "Diese Mannschaft ist bereits vorhanden." : "Die Mannschaft konnte nicht angelegt werden."); setSaving(false); return; }
      createdId = data;
      await loadTeams();
    } else {
      setTeams((current) => [...current, { id: createdId, name: name.trim(), category: category.trim() || "Mannschaft", is_adult: isAdultTeam }].sort((a, b) => a.name.localeCompare(b.name, "de")));
    }
    setName(""); setCategory(""); setIsAdultTeam(false); setShowCreate(false); setSelectedTeamId(createdId); setMessage("Mannschaft wurde angelegt."); setSaving(false);
  };
  const openEditTeam = (team) => {
    setEditName(team.name); setEditCategory(team.category || ""); setEditingTeam(true); setMessage("");
  };
  const saveTeamEdit = async () => {
    if (!selectedTeam || !editName.trim()) { setMessage("Bitte einen Mannschaftsnamen eingeben."); return; }
    setSavingTeamEdit(true); setMessage("");
    if (databaseMembership) {
      const { error } = await supabase.rpc("update_club_team", { target_club: currentUser.clubId, target_team: selectedTeam.id, new_name: editName.trim(), new_category: editCategory.trim() || null });
      if (error) { setMessage(error.message?.includes("already exists") ? "Diese Mannschaft ist bereits vorhanden." : "Die Mannschaft konnte nicht geändert werden."); setSavingTeamEdit(false); return; }
      await loadTeams();
    } else {
      setTeams((current) => current.map((team) => team.id === selectedTeam.id ? { ...team, name: editName.trim(), category: editCategory.trim() || "Mannschaft" } : team));
    }
    setEditingTeam(false); setMessage("Mannschaft wurde geändert."); setSavingTeamEdit(false);
  };
  const archiveTeam = async () => {
    if (!selectedTeam) return;
    if (!window.confirm(`Mannschaft „${selectedTeam.name}“ wirklich archivieren? Sie verschwindet aus allen Auswahllisten, die Historie (Termine, Aufgaben, Strafen) bleibt erhalten.`)) return;
    setArchivingTeam(true); setMessage("");
    if (databaseMembership) {
      const { error } = await supabase.rpc("archive_club_team", { target_club: currentUser.clubId, target_team: selectedTeam.id });
      if (error) { setMessage("Die Mannschaft konnte nicht archiviert werden."); setArchivingTeam(false); return; }
    }
    setTeams((current) => current.filter((team) => team.id !== selectedTeam.id));
    setSelectedTeamId(""); setEditingTeam(false); setMessage("Mannschaft wurde archiviert."); setArchivingTeam(false);
  };
  const TeamCard = ({ team }) => {
    const roster = rosterFor(team); const own = ownNames.includes(team.name);
    return <button onClick={() => setSelectedTeamId(team.id)} className="w-full flex items-center gap-3 rounded-2xl px-3.5 py-3 text-left" style={{ background: C.glass, border: own ? `1px solid ${C.secondary}` : `1px solid ${C.line}` }}><div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ background: own ? C.erfolgFlaeche : C.paperDim, color: own ? C.erfolg : C.fehler }}><Users size={18}/></div><div className="flex-1 min-w-0"><div className="text-sm font-bold truncate" style={{ color: C.ink }}>{team.name}</div><div className="text-[11px]" style={{ color: C.textDim }}>{team.category || "Mannschaft"} · {roster.length} Athlet{roster.length === 1 ? "" : "/innen"}</div></div>{own && <span className="text-[9px] font-bold px-2 py-1 rounded-full" style={{ background: C.erfolgFlaeche, color: C.erfolg }}>MEIN TEAM</span>}<ChevronRight size={15} style={{ color: C.textDim }}/></button>;
  };

  return <div className="px-4 pt-4 pb-24">
    <SectionTitle eyebrow="Verein" title="Teams" right={canCreate ? <button onClick={() => setShowCreate((value) => !value)} className="px-3 py-1.5 rounded-full text-[10px] font-bold" style={{ background: C.ink, color: C.white }}>{showCreate ? "Schließen" : "+ Team"}</button> : null}/>
    <div className="text-xs mb-4 -mt-2" style={{ color: C.textDim }}>Alle Mannschaften von {currentClub?.shortName}. Öffne ein Team, um den Athletenkader anzusehen.</div>
    {showCreate && <form onSubmit={createTeam} className="rounded-2xl p-4 mb-5" style={{ background: C.glass, border: `1px solid ${C.line}` }}><div className="text-sm font-bold mb-1" style={{ color: C.ink }}>Neue Mannschaft anlegen</div><div className="text-[11px] mb-3" style={{ color: C.textDim }}>Danach können Athlet/innen das Team in ihrem Profil auswählen.</div><input value={name} onChange={(event) => setName(event.target.value)} maxLength={80} placeholder="Mannschaftsname, z. B. U17" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim }}/><input value={category} onChange={(event) => setCategory(event.target.value)} maxLength={80} placeholder="Kategorie, z. B. Jugend oder Herren" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim }}/><button type="button" onClick={() => setIsAdultTeam((v) => !v)} className="w-full flex items-center justify-between rounded-xl px-3 py-2.5 mb-2" style={{ background: isAdultTeam ? C.fehlerFlaeche : C.paperDim, border: isAdultTeam ? `1px solid ${C.red}` : "1px solid transparent" }}><div className="text-left"><div className="text-xs font-bold" style={{ color: C.ink }}>Erwachsenenmannschaft?</div><div className="text-[10px]" style={{ color: C.textDim }}>Nur dann gibt es Strafenkatalog & Zuweisungen für dieses Team.</div></div><span className="w-10 h-6 rounded-full flex items-center px-0.5" style={{ background: isAdultTeam ? C.red : C.line, justifyContent: isAdultTeam ? "flex-end" : "flex-start" }}><span className="w-5 h-5 rounded-full" style={{ background: C.glass }}/></span></button><button disabled={saving || !name.trim()} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: name.trim() ? C.red : C.line, color: C.white }}>{saving ? "Wird angelegt …" : "Mannschaft anlegen"}</button></form>}
    {message && <div role="status" className="text-[11px] rounded-xl px-3 py-2 mb-4" style={{ background: (message.includes("angelegt")||message.includes("geändert")||message.includes("archiviert")) ? C.erfolgFlaeche : C.fehlerFlaeche, color: (message.includes("angelegt")||message.includes("geändert")||message.includes("archiviert")) ? C.erfolg : C.fehler }}>{message}</div>}
    {selectedTeam ? <div><button onClick={() => { setSelectedTeamId(""); setShowPlayerPicker(false); setEditingTeam(false); }} className="flex items-center gap-1 text-xs font-bold mb-3" style={{ color: C.fehler }}><ArrowLeft size={14}/> Alle Teams</button><div className="rounded-2xl p-4 mb-4" style={{ background: C.ink, color: C.white }}><div className="text-[10px] uppercase tracking-widest mb-1" style={{ color: C.textDim }}>{selectedTeam.category || "Mannschaft"}</div><div className="text-xl font-bold" style={{ fontFamily: "Oswald" }}>{selectedTeam.name}</div><div className="text-xs mt-1" style={{ color: C.textDim }}>{rosterFor(selectedTeam).length} verknüpfte Athlet/innen</div></div>{canCreate && !editingTeam && <div className="flex gap-2 mb-4"><button onClick={() => openEditTeam(selectedTeam)} className="flex-1 py-2 rounded-xl text-xs font-bold" style={{ background: C.paperDim, color: C.ink }}>Bearbeiten</button><button onClick={archiveTeam} disabled={archivingTeam} className="flex-1 py-2 rounded-xl text-xs font-bold" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{archivingTeam ? "…" : "Archivieren"}</button></div>}{canCreate && editingTeam && <div className="rounded-2xl p-3.5 mb-4" style={{ background: C.paperDim }}><input value={editName} onChange={(e) => setEditName(e.target.value)} maxLength={80} placeholder="Mannschaftsname" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.glass }}/><input value={editCategory} onChange={(e) => setEditCategory(e.target.value)} maxLength={80} placeholder="Kategorie" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.glass }}/><div className="flex gap-2"><button onClick={saveTeamEdit} disabled={savingTeamEdit} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white }}>{savingTeamEdit ? "…" : "Speichern"}</button><button onClick={() => setEditingTeam(false)} className="px-4 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.glass, color: C.textDim }}>Abbrechen</button></div></div>}<SectionTitle eyebrow="Kader" title="Athlet/innen" right={canAssignPlayers ? <button onClick={() => setShowPlayerPicker((value) => !value)} className="px-3 py-1.5 rounded-full text-[10px] font-bold" style={{ background: C.ink, color: C.white }}>{showPlayerPicker ? "Schließen" : "+ Zuweisen"}</button> : null}/>{showPlayerPicker && <div className="rounded-2xl p-3 mb-4" style={{ background: C.paperDim }}><div className="text-[11px] mb-2" style={{ color: C.textDim }}>Athlet/in auswählen und anschließend seine Mannschaften festlegen.</div>{!showNewPlayer ? <button type="button" onClick={() => setShowNewPlayer(true)} className="w-full flex items-center justify-center gap-1.5 rounded-xl px-3 py-2 mb-2 text-[11px] font-bold" style={{ background: C.glass, color: C.fehler, border: `1px dashed ${C.red}` }}><Plus size={13}/> Spieler ohne Account anlegen</button> : <div className="rounded-xl p-2.5 mb-2" style={{ background: C.glass }}><div className="text-[10px] mb-1.5" style={{ color: C.textDim }}>Für Athlet/innen ohne eigenes Handy/Konto (z. B. Kindermannschaften). Vorname und Nachname reichen — die Verknüpfung mit einem Elternteil erfolgt separat in den Familienprofilen.</div><input value={newPlayerName} onChange={(e) => setNewPlayerName(e.target.value)} placeholder="Vor- und Nachname" className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-2" style={{ background: C.paperDim }}/><div className="flex gap-2"><button type="button" onClick={() => { setShowNewPlayer(false); setNewPlayerName(""); }} className="flex-1 py-2 rounded-lg text-[11px] font-bold" style={{ background: C.paperDim, color: C.ink }}>Abbrechen</button><button type="button" disabled={creatingPlayer || !newPlayerName.trim()} onClick={createPlayerWithoutAccount} className="flex-1 py-2 rounded-lg text-[11px] font-bold" style={{ background: newPlayerName.trim() ? C.ink : C.line, color: C.white }}>{creatingPlayer ? "…" : "Anlegen"}</button></div></div>}<div className="space-y-1.5 max-h-56 overflow-y-auto">{players.map((player) => <button key={player.id} onClick={() => openPlayer(player)} className="w-full flex items-center gap-2 rounded-xl px-3 py-2 text-left" style={{ background: C.glass }}><div className="w-7 h-7 rounded-full flex items-center justify-center text-[9px] font-bold" style={{ background: player.color, color: C.white }}>{initialsOf(player.name)}</div><div className="flex-1"><div className="text-xs font-bold" style={{ color: C.ink }}>{player.name}</div><div className="text-[9px]" style={{ color: C.textDim }}>{memberPlayerTeams(player).join(" · ") || "Noch ohne Mannschaft"}</div></div><ChevronRight size={13} style={{ color: C.textDim }}/></button>)}</div></div>}{rosterFor(selectedTeam).length ? <div className="space-y-2">{rosterFor(selectedTeam).map((player) => <button key={player.id} onClick={() => openPlayer(player)} className="w-full flex items-center gap-3 rounded-xl px-3 py-2.5 text-left" style={{ background: C.glass, border: `1px solid ${C.line}` }}><div className="w-9 h-9 rounded-full flex items-center justify-center text-[10px] font-bold" style={{ background: player.color, color: C.white }}>{initialsOf(player.name)}</div><div className="flex-1"><div className="text-xs font-bold" style={{ color: C.ink }}>{player.name}</div><div className="text-[10px]" style={{ color: C.textDim }}>{memberPlayerTeams(player).join(" · ")}</div></div><ChevronRight size={14} style={{ color: C.textDim }}/></button>)}</div> : <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim }}>Dieser Mannschaft sind noch keine Athlet/innen zugeordnet.</div>}</div> : loading ? <div className="text-xs py-4" style={{ color: C.textDim }}>Mannschaften werden geladen …</div> : <><SectionTitle eyebrow="Persönlich" title="Meine Teams"/><div className="space-y-2 mb-6">{ownTeams.length ? ownTeams.map((team) => <TeamCard key={team.id} team={team}/>) : <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim }}>Du bist noch keiner Mannschaft als Athlet/in zugeordnet. Athlet/innen können im Profil bis zu drei Teams auswählen.</div>}</div><SectionTitle eyebrow="Vereinsübersicht" title="Alle Mannschaften"/><div className="space-y-2">{teams.map((team) => <TeamCard key={team.id} team={team}/>)}{teams.length === 0 && <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim }}>Noch keine Mannschaften angelegt.</div>}</div></>}
    {selectedPlayer && <div className="absolute inset-0 z-50 flex items-end p-3" style={{ background: "rgba(20,21,26,.72)" }} onClick={() => setSelectedPlayerId("")}><div role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()} className="w-full rounded-3xl p-5 max-h-[82%] overflow-y-auto" style={{ background: C.glass }}><div className="flex items-start justify-between mb-4"><div className="flex items-center gap-3"><div className="w-12 h-12 rounded-full flex items-center justify-center text-sm font-bold" style={{ background: selectedPlayer.color, color: C.white }}>{initialsOf(selectedPlayer.name)}</div><div><div className="text-lg font-bold" style={{ fontFamily: "Oswald", color: C.ink }}>{selectedPlayer.name}</div><div className="text-xs" style={{ color: C.textDim }}>Athlet/in · dabei seit {selectedPlayer.since}</div></div></div><button onClick={() => setSelectedPlayerId("")} className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><X size={15}/></button></div><div className="flex items-center justify-between mb-2"><div className="text-[10px] uppercase tracking-widest font-bold" style={{ color: C.textDim }}>Mannschaften</div>{canAssignPlayers && <span className="text-[10px] font-bold" style={{ color: playerTeamIds.length === 3 ? C.red : C.textDim }}>{playerTeamIds.length}/3</span>}{canAssignPlayers && <button type="button" onClick={() => setTeamsOpen((v) => !v)} className="p-1"><ChevronRight size={14} style={{ color: C.textDim, transform: teamsOpen ? "rotate(90deg)" : "rotate(0deg)", transition: "transform .15s" }}/></button>}</div>{canAssignPlayers ? (teamsOpen && <div className="space-y-2">{teams.map((team) => { const active = playerTeamIds.includes(team.id); return <button key={team.id} onClick={() => togglePlayerTeam(team.id)} className="w-full flex items-center justify-between rounded-xl px-3 py-2.5 text-left" style={{ background: active ? C.erfolgFlaeche : C.paperDim, border: active ? `1px solid ${C.secondary}` : "1px solid transparent" }}><div><div className="text-xs font-bold" style={{ color: C.ink }}>{team.name}</div><div className="text-[9px]" style={{ color: C.textDim }}>{team.category || "Mannschaft"}</div></div><span className="w-5 h-5 rounded-full flex items-center justify-center" style={{ background: active ? C.secondary : C.white, color: C.white }}>{active && <Check size={13}/>}</span></button>; })}<button onClick={savePlayerTeams} disabled={savingPlayer || JSON.stringify([...playerTeamIds].sort()) === JSON.stringify([...savedPlayerTeamIds].sort())} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: JSON.stringify([...playerTeamIds].sort()) !== JSON.stringify([...savedPlayerTeamIds].sort()) ? C.ink : C.paperDim, color: JSON.stringify([...playerTeamIds].sort()) !== JSON.stringify([...savedPlayerTeamIds].sort()) ? C.white : C.textDim, opacity: savingPlayer ? .6 : 1 }}>{savingPlayer ? "Wird gespeichert …" : "Zuordnung speichern"}</button>{playerMessage && <div role="status" className="text-[11px]" style={{ color: playerMessage.includes("gespeichert") ? C.erfolg : C.fehler }}>{playerMessage}</div>}</div>) : <div className="flex flex-wrap gap-2">{memberPlayerTeams(selectedPlayer).length ? memberPlayerTeams(selectedPlayer).map((team) => <span key={team} className="px-3 py-1.5 rounded-full text-xs font-bold" style={{ background: C.erfolgFlaeche, color: C.erfolg }}>{team}</span>) : <span className="text-xs" style={{ color: C.textDim }}>Noch keiner Mannschaft zugeordnet.</span>}</div>}{canManagePenalties && (<div className="mt-4 pt-4" style={{ borderTop: `1px solid ${C.line}` }}><button type="button" onClick={() => setPenaltyOpen((v) => !v)} className="w-full flex items-center justify-between mb-2"><div className="text-[10px] uppercase tracking-widest font-bold" style={{ color: C.textDim }}>Strafenverwaltung</div><ChevronRight size={14} style={{ color: C.textDim, transform: penaltyOpen ? "rotate(90deg)" : "rotate(0deg)", transition: "transform .15s" }}/></button>{penaltyOpen && (<><div className="flex gap-2 mb-3"><select value={assignRuleId} onChange={(e) => setAssignRuleId(e.target.value)} className="flex-1 px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim, color: C.ink }}><option value="">Strafe wählen …</option>{penaltyRules.map((r) => <option key={r.id} value={r.id}>{r.title} ({r.amount.toLocaleString("de-DE", { minimumFractionDigits: 2 })} €)</option>)}</select><button onClick={assignPenaltyToPlayer} disabled={assigningPenalty || !assignRuleId} className="px-4 rounded-xl text-xs font-bold" style={{ background: assignRuleId ? C.ink : C.line, color: C.white }}>{assigningPenalty ? "…" : "Zuweisen"}</button></div>{penaltyMessage && <div role="status" className="text-[11px] mb-2" style={{ color: penaltyMessage.includes("zugewiesen") ? C.erfolg : C.fehler }}>{penaltyMessage}</div>}<div className="text-[10px] uppercase tracking-widest font-bold mb-1.5" style={{ color: C.textDim }}>Bisherige Strafen</div><div className="space-y-1.5">{playerPenalties.map((p) => <div key={p.id} className="flex items-center justify-between px-3 py-2 rounded-xl" style={{ background: C.paperDim }}><span className="text-xs font-bold" style={{ color: C.ink }}>{p.title}</span><span className="text-xs font-bold" style={{ color: C.red, fontFamily: "JetBrains Mono" }}>{p.amount.toLocaleString("de-DE", { minimumFractionDigits: 2 })} €</span><button type="button" onClick={() => togglePlayerPenaltyPaid(p)} className="px-2 py-1 rounded-lg text-[9px] font-bold flex-shrink-0" style={{ background: p.paidAt ? C.erfolgFlaeche : C.white, color: p.paidAt ? C.secondary : C.textDim }}>{p.paidAt ? "Bezahlt" : "Offen"}</button><button type="button" onClick={() => removePlayerPenalty(p)} aria-label="Strafe entfernen" className="w-6 h-6 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: C.glass, color: C.red }}><X size={12}/></button></div>)}{playerPenalties.length === 0 && <div className="text-[11px]" style={{ color: C.textDim }}>Noch keine Strafen vergeben.</div>}</div></>)}</div>)}</div></div>}
  </div>;
}

function TeamPenaltyCatalog({ user }) {
  const [teams, setTeams] = useState([]);
  const [selectedTeamId, setSelectedTeamId] = useState("");
  const [rules, setRules] = useState([]);
  const [localRules, setLocalRules] = useState([]);
  const [title, setTitle] = useState("");
  const [amount, setAmount] = useState("");
  const [editingId, setEditingId] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [teamPlayers, setTeamPlayers] = useState([]);
  const [assignments, setAssignments] = useState([]);
  const [localAssignments, setLocalAssignments] = useState([]);
  const [assignPlayerId, setAssignPlayerId] = useState("");
  const [assignRuleId, setAssignRuleId] = useState("");
  const [assigning, setAssigning] = useState(false);
  const [filterRuleId, setFilterRuleId] = useState("");
  const [showHistory, setShowHistory] = useState(false);
  const [historyAssignments, setHistoryAssignments] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [seasonLabel, setSeasonLabel] = useState("");
  const [resettingSeason, setResettingSeason] = useState(false);
  const databaseMembership = !!supabase && isDbId(user.id);
  const canManageSelectedTeam = !!teams.find((team) => team.id === selectedTeamId)?.canManage;
  const canManageSeasons = databaseMembership && user.roles.some((role) => ["vorstand", "finanzmanager", "sysadmin", "vereinsadmin"].includes(role));
  useEffect(() => {
    const loadTeams = async () => {
      setLoading(true); setMessage("");
      if (!databaseMembership) {
        /* Gemeint waren immer ALLE eigenen Mannschaften. Fuer den Spieleranteil
           stand hier aber nur user.team - wer in Herren 1 und Herren 2 spielt,
           fand die zweite im Auswahlfeld nicht. Und der Rueckfall
           (user.trainerTeams || [user.team]) erklaerte die Spielmannschaft zur
           Trainer-Mannschaft und gab dort Schreibrechte, die es nicht gibt. */
        const names = memberAllTeams(user);
        const localTeams = names.map((name) => ({
          id: name,
          name,
          canManage: memberTrainerTeams(user).includes(name)
            || memberManagedTeams(user).includes(name)
            || memberCaptainTeams(user).includes(name),
        }));
        setTeams(localTeams);
        /* Vorbelegt die hoechste Mannschaft, nicht die zufaellig erste. */
        setSelectedTeamId((current) => current || hoechsteMannschaft(names) || "");
        setLoading(false);
        return;
      }
      const { data, error } = await supabase.from("team_members")
        .select("team_id,function,teams(id,name,is_adult)")
        .eq("membership_id", user.id)
        .in("function", ["spieler", "trainer", "teammanager", "kapitaen"]);
      if (error) { setMessage("Die Mannschaften konnten nicht geladen werden."); setLoading(false); return; }
      const byId = new Map();
      (data || []).forEach((entry) => {
        const team = Array.isArray(entry.teams) ? entry.teams[0] : entry.teams;
        if (team && team.is_adult) byId.set(team.id, { ...team, canManage: byId.get(team.id)?.canManage || ["trainer", "teammanager", "kapitaen"].includes(entry.function) });
      });
      const assigned = [...byId.values()].sort((a, b) => a.name.localeCompare(b.name, "de"));
      setTeams(assigned);
      setSelectedTeamId((current) => current || hoechstesTeam(assigned)?.id || "");
      setLoading(false);
    };
    loadTeams();
  }, [user.id, databaseMembership]);
  useEffect(() => {
    if (!selectedTeamId) { setRules([]); return; }
    const loadRules = async () => {
      setMessage("");
      if (!databaseMembership) {
        setRules(localRules.filter((rule) => rule.teamId === selectedTeamId));
        return;
      }
      const { data, error } = await supabase.from("team_penalty_rules")
        .select("id,team_id,title,amount,created_at")
        .eq("team_id", selectedTeamId)
        .order("title", { ascending: true });
      if (error) { setMessage("Der Strafenkatalog konnte nicht geladen werden."); return; }
      setRules((data || []).map((rule) => ({ ...rule, teamId: rule.team_id, amount: Number(rule.amount) })));
    };
    loadRules();
  }, [selectedTeamId, databaseMembership, localRules]);
  useEffect(() => {
    if (!selectedTeamId || !databaseMembership) { setTeamPlayers([]); return; }
    const loadPlayers = async () => {
      const { data, error } = await supabase.from("team_members")
        .select("membership_id,club_memberships(display_name)")
        .eq("team_id", selectedTeamId);
      if (error) return;
      const byId = new Map();
      (data || []).forEach((entry) => {
        const membership = Array.isArray(entry.club_memberships) ? entry.club_memberships[0] : entry.club_memberships;
        if (membership) byId.set(entry.membership_id, membership.display_name);
      });
      setTeamPlayers([...byId.entries()].map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name, "de")));
    };
    loadPlayers();
  }, [selectedTeamId, databaseMembership]);
  useEffect(() => {
    if (!selectedTeamId) { setAssignments([]); return; }
    if (!databaseMembership) {
      setAssignments(localAssignments.filter((a) => a.teamId === selectedTeamId));
      return;
    }
    const loadAssignments = async () => {
      const { data, error } = await supabase.from("team_penalty_assignments")
        .select("id,assigned_at,paid_at,rule_id,membership_id,team_penalty_rules(title,amount),club_memberships(display_name)")
        .eq("team_id", selectedTeamId)
        .is("archived_season", null)
        .order("assigned_at", { ascending: false });
      if (error) { setMessage("Die vergebenen Strafen konnten nicht geladen werden."); return; }
      setAssignments((data || []).map((entry) => {
        const rule = Array.isArray(entry.team_penalty_rules) ? entry.team_penalty_rules[0] : entry.team_penalty_rules;
        const membership = Array.isArray(entry.club_memberships) ? entry.club_memberships[0] : entry.club_memberships;
        return { id: entry.id, teamId: selectedTeamId, ruleId: entry.rule_id, ruleTitle: rule?.title || "—", amount: Number(rule?.amount || 0), membershipId: entry.membership_id, playerName: membership?.display_name || "—", assignedAt: entry.assigned_at, paidAt: entry.paid_at };
      }));
    };
    loadAssignments();
  }, [selectedTeamId, databaseMembership, localAssignments]);
  useEffect(() => {
    if (!showHistory || !selectedTeamId || !databaseMembership) { setHistoryAssignments([]); return; }
    const loadHistory = async () => {
      setHistoryLoading(true);
      const { data, error } = await supabase.from("team_penalty_assignments")
        .select("id,assigned_at,paid_at,archived_season,rule_id,membership_id,team_penalty_rules(title,amount),club_memberships(display_name)")
        .eq("team_id", selectedTeamId)
        .not("archived_season", "is", null)
        .order("archived_season", { ascending: false })
        .order("assigned_at", { ascending: false });
      if (error) { setMessage("Die Saison-Historie konnte nicht geladen werden."); setHistoryLoading(false); return; }
      setHistoryAssignments((data || []).map((entry) => {
        const rule = Array.isArray(entry.team_penalty_rules) ? entry.team_penalty_rules[0] : entry.team_penalty_rules;
        const membership = Array.isArray(entry.club_memberships) ? entry.club_memberships[0] : entry.club_memberships;
        return { id: entry.id, season: entry.archived_season, ruleTitle: rule?.title || "—", amount: Number(rule?.amount || 0), playerName: membership?.display_name || "—", assignedAt: entry.assigned_at, paidAt: entry.paid_at };
      }));
      setHistoryLoading(false);
    };
    loadHistory();
  }, [showHistory, selectedTeamId, databaseMembership]);
  const addRule = async (event) => {
    event.preventDefault();
    const normalizedAmount = Number(amount.replace(",", "."));
    if (!title.trim() || !Number.isFinite(normalizedAmount) || normalizedAmount < 0) {
      setMessage("Bitte einen Titel und einen gültigen Betrag eingeben."); return;
    }
    if (!canManageSelectedTeam) { setMessage("Für diese Mannschaft darfst du den Katalog nur ansehen."); return; }
    setSaving(true); setMessage("");
    let created = { id: editingId || `penalty-${Date.now()}`, teamId: selectedTeamId, title: title.trim(), amount: normalizedAmount };
    if (databaseMembership) {
      const request = editingId
        ? supabase.from("team_penalty_rules").update({ title: title.trim(), amount: normalizedAmount, updated_at: new Date().toISOString() }).eq("id", editingId)
        : supabase.from("team_penalty_rules").insert({ team_id: selectedTeamId, title: title.trim(), amount: normalizedAmount });
      const { data, error } = await request
        .select("id,team_id,title,amount,created_at").single();
      if (error) { setMessage("Die Regel konnte nicht gespeichert werden."); setSaving(false); return; }
      created = { ...data, teamId: data.team_id, amount: Number(data.amount) };
    }
    const replaceOrAdd = (current) => [...current.filter((rule) => rule.id !== created.id), created].sort((a, b) => a.title.localeCompare(b.title, "de"));
    if (!databaseMembership) setLocalRules(replaceOrAdd);
    setRules(replaceOrAdd);
    setTitle(""); setAmount(""); setEditingId(""); setMessage("Regel wurde gespeichert."); setSaving(false);
  };
  const editRule = (rule) => {
    setEditingId(rule.id);
    setTitle(rule.title);
    setAmount(rule.amount.toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
    setMessage("");
  };
  const removeRule = async (rule) => {
    if (!window.confirm(`Regel „${rule.title}“ wirklich löschen?`)) return;
    if (!canManageSelectedTeam) return;
    setSaving(true); setMessage("");
    if (databaseMembership) {
      const { error } = await supabase.from("team_penalty_rules").delete().eq("id", rule.id);
      if (error) { setMessage("Die Regel konnte nicht gelöscht werden."); setSaving(false); return; }
    }
    if (!databaseMembership) setLocalRules((current) => current.filter((item) => item.id !== rule.id));
    setRules((current) => current.filter((item) => item.id !== rule.id));
    setMessage("Regel wurde gelöscht."); setSaving(false);
  };
  const assignPenalty = async (event) => {
    event.preventDefault();
    if (!assignPlayerId || !assignRuleId) { setMessage("Bitte Athlet/in und Strafe auswählen."); return; }
    setAssigning(true); setMessage("");
    const rule = rules.find((r) => r.id === assignRuleId);
    if (databaseMembership) {
      const { error } = await supabase.from("team_penalty_assignments")
        .insert({ team_id: selectedTeamId, rule_id: assignRuleId, membership_id: assignPlayerId });
      if (error) { setMessage("Die Strafe konnte nicht zugewiesen werden."); setAssigning(false); return; }
      setLocalAssignments((current) => [...current]);
    } else {
      const player = teamPlayers.find((p) => p.id === assignPlayerId);
      setLocalAssignments((current) => [...current, { id: `assign-${Date.now()}`, teamId: selectedTeamId, ruleId: assignRuleId, ruleTitle: rule?.title || "—", amount: rule?.amount || 0, membershipId: assignPlayerId, playerName: player?.name || assignPlayerId, assignedAt: new Date().toISOString(), paidAt: null }]);
    }
    if (databaseMembership) {
      const { data } = await supabase.from("team_penalty_assignments")
        .select("id,assigned_at,paid_at,rule_id,membership_id,team_penalty_rules(title,amount),club_memberships(display_name)")
        .eq("team_id", selectedTeamId)
        .is("archived_season", null)
        .order("assigned_at", { ascending: false });
      setAssignments((data || []).map((entry) => {
        const r = Array.isArray(entry.team_penalty_rules) ? entry.team_penalty_rules[0] : entry.team_penalty_rules;
        const membership = Array.isArray(entry.club_memberships) ? entry.club_memberships[0] : entry.club_memberships;
        return { id: entry.id, teamId: selectedTeamId, ruleId: entry.rule_id, ruleTitle: r?.title || "—", amount: Number(r?.amount || 0), membershipId: entry.membership_id, playerName: membership?.display_name || "—", assignedAt: entry.assigned_at, paidAt: entry.paid_at };
      }));
    }
    setAssignPlayerId(""); setAssignRuleId(""); setMessage("Strafe wurde zugewiesen."); setAssigning(false);
  };
  const removeAssignment = async (assignment) => {
    if (!window.confirm(`Strafe „${assignment.ruleTitle}“ bei ${assignment.playerName} wirklich entfernen?`)) return;
    if (databaseMembership) {
      const { error } = await supabase.from("team_penalty_assignments").delete().eq("id", assignment.id);
      if (error) { setMessage("Konnte nicht entfernt werden."); return; }
    } else {
      setLocalAssignments((current) => current.filter((item) => item.id !== assignment.id));
    }
    setAssignments((current) => current.filter((item) => item.id !== assignment.id));
  };
  const toggleAssignmentPaid = async (assignment) => {
    setMessage("");
    const nextPaid = !assignment.paidAt;
    if (databaseMembership) {
      const { error } = await supabase.rpc("mark_penalty_paid", { target_assignment: assignment.id, mark_paid: nextPaid });
      if (error) { setMessage("Bezahlt-Status konnte nicht geändert werden."); return; }
    } else {
      setLocalAssignments((current) => current.map((item) => item.id === assignment.id ? { ...item, paidAt: nextPaid ? new Date().toISOString() : null } : item));
    }
    setAssignments((current) => current.map((item) => item.id === assignment.id ? { ...item, paidAt: nextPaid ? new Date().toISOString() : null } : item));
    setMessage(nextPaid ? "Strafe als bezahlt markiert." : "Strafe als offen markiert.");
  };
  const runSeasonReset = async () => {
    if (!seasonLabel.trim()) { setMessage("Bitte eine Saisonbezeichnung eingeben, z. B. 2025/26."); return; }
    if (!window.confirm(`Alle bezahlten Strafen des Vereins werden unter „${seasonLabel.trim()}“ archiviert und aus der aktiven Ansicht entfernt. Fortfahren?`)) return;
    setResettingSeason(true); setMessage("");
    const { data, error } = await supabase.rpc("run_season_reset", { target_club: user.clubId, season_label: seasonLabel.trim() });
    if (error) { setMessage("Der Saison-Reset konnte nicht durchgeführt werden."); setResettingSeason(false); return; }
    setAssignments((current) => current.filter((item) => !item.paidAt));
    setSeasonLabel("");
    setMessage(`Saison-Reset abgeschlossen. ${data ?? 0} bezahlte Strafe(n) archiviert.`);
    setResettingSeason(false);
  };
  const filteredAssignments = filterRuleId ? assignments.filter((a) => a.ruleId === filterRuleId) : assignments;
  const totalsByPlayer = filteredAssignments.reduce((acc, a) => { acc[a.playerName] = (acc[a.playerName] || 0) + a.amount; return acc; }, {});
  const historyBySeasons = historyAssignments.reduce((acc, a) => { (acc[a.season] = acc[a.season] || []).push(a); return acc; }, {});
  return <div className="rounded-2xl p-4 mb-5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
    <div className="flex items-center gap-2 mb-1 text-sm font-bold" style={{ color: C.ink }}><ClipboardList size={16} style={{ color: C.red }}/> Strafenkatalog</div>
    <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Regeln und Kosten werden für jede Mannschaft getrennt geführt.</div>
    {loading ? <div className="text-xs py-3" style={{ color: C.textDim }}>Mannschaften werden geladen …</div> : teams.length === 0 ? <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Der Strafenkatalog ist nur für Erwachsenenmannschaften verfügbar. Dir ist aktuell keine Erwachsenenmannschaft als Athlet/in, Kapitän/in, Trainer/in oder Teammanager/in zugeordnet.</div> : <>
      <div className="text-[10px] font-bold mb-1" style={{ color: C.textDim }}>MANNSCHAFT</div>
      <select value={selectedTeamId} onChange={(event) => { setSelectedTeamId(event.target.value); setMessage(""); setShowHistory(false); }} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-3" style={{ background: C.paperDim, color: C.ink }}>{teams.map((team) => <option key={team.id} value={team.id}>{team.name}</option>)}</select>
      <div className="space-y-2 mb-3">
        {rules.map((rule) => <div key={rule.id} className="flex items-center gap-2 px-3 py-2.5 rounded-xl" style={{ background: C.paperDim }}><div className="flex-1 min-w-0"><div className="text-xs font-bold truncate" style={{ color: C.ink }}>{rule.title}</div></div><div className="text-xs font-bold whitespace-nowrap" style={{ color: C.red, fontFamily: "JetBrains Mono" }}>{rule.amount.toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} €</div>{canManageSelectedTeam && <><button type="button" disabled={saving} onClick={() => editRule(rule)} className="px-2 py-1.5 rounded-lg text-[10px] font-bold" style={{ background: C.glass, color: C.ink }}>Ändern</button><button type="button" disabled={saving} onClick={() => removeRule(rule)} aria-label={`${rule.title} löschen`} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: C.glass, color: C.red }}><X size={14}/></button></>}</div>)}
        {rules.length === 0 && <div className="text-[11px] rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Für diese Mannschaft sind noch keine Regeln hinterlegt.</div>}
      </div>
      {canManageSelectedTeam && <form onSubmit={addRule} className="pt-3" style={{ borderTop: `1px solid ${C.line}` }}><div className="flex items-center justify-between mb-2"><div className="text-[10px] font-bold" style={{ color: C.textDim }}>{editingId ? "REGEL BEARBEITEN" : "NEUE REGEL"}</div>{editingId && <button type="button" onClick={() => { setEditingId(""); setTitle(""); setAmount(""); }} className="text-[10px] font-bold" style={{ color: C.red }}>Abbrechen</button>}</div><input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={120} placeholder="Titel, z. B. Zuspätkommen" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim, color: C.ink }}/><div className="flex gap-2"><div className="relative flex-1"><input value={amount} onChange={(event) => setAmount(event.target.value)} inputMode="decimal" placeholder="Kosten" className="w-full px-3 pr-8 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim, color: C.ink }}/><span className="absolute right-3 top-2.5 text-xs" style={{ color: C.textDim }}>€</span></div><button type="submit" disabled={saving || !title.trim() || !amount.trim()} className="px-4 rounded-xl text-xs font-bold" style={{ background: title.trim() && amount.trim() ? C.ink : C.line, color: C.white }}>{saving ? "…" : editingId ? "Speichern" : "Hinzufügen"}</button></div></form>}
      {canManageSelectedTeam && (
        <div className="pt-4 mt-4" style={{ borderTop: `1px solid ${C.line}` }}>
          <div className="text-[10px] font-bold mb-2" style={{ color: C.textDim }}>STRAFE ZUWEISEN</div>
          <form onSubmit={assignPenalty} className="flex flex-col gap-2 mb-4">
            <select value={assignPlayerId} onChange={(e) => setAssignPlayerId(e.target.value)} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim, color: C.ink }}>
              <option value="">Athlet/in wählen …</option>
              {teamPlayers.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
            <select value={assignRuleId} onChange={(e) => setAssignRuleId(e.target.value)} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim, color: C.ink }}>
              <option value="">Strafe wählen …</option>
              {rules.map((r) => <option key={r.id} value={r.id}>{r.title} ({r.amount.toLocaleString("de-DE", { minimumFractionDigits: 2 })} €)</option>)}
            </select>
            <button type="submit" disabled={assigning || !assignPlayerId || !assignRuleId} className="px-4 py-2.5 rounded-xl text-xs font-bold" style={{ background: assignPlayerId && assignRuleId ? C.ink : C.line, color: C.white }}>{assigning ? "…" : "Zuweisen"}</button>
          </form>
          <div className="flex items-center justify-between mb-2">
            <div className="text-[10px] font-bold" style={{ color: C.textDim }}>VERGEBENE STRAFEN</div>
            <select value={filterRuleId} onChange={(e) => setFilterRuleId(e.target.value)} className="px-2 py-1.5 rounded-lg text-[10px] outline-none" style={{ background: C.paperDim, color: C.ink }}>
              <option value="">Alle Strafen</option>
              {rules.map((r) => <option key={r.id} value={r.id}>{r.title}</option>)}
            </select>
          </div>
          {Object.keys(totalsByPlayer).length > 0 && (
            <div className="flex flex-wrap gap-1.5 mb-3">
              {Object.entries(totalsByPlayer).map(([name, total]) => (
                <span key={name} className="text-[10px] font-bold px-2 py-1 rounded-full" style={{ background: C.paperDim, color: C.ink }}>{name}: {total.toLocaleString("de-DE", { minimumFractionDigits: 2 })} €</span>
              ))}
            </div>
          )}
          <div className="space-y-2 mb-4">
            {filteredAssignments.map((a) => (
              <div key={a.id} className="flex items-center gap-2 px-3 py-2.5 rounded-xl" style={{ background: C.paperDim }}>
                <div className="flex-1 min-w-0">
                  <div className="text-xs font-bold truncate" style={{ color: C.ink }}>{a.playerName}</div>
                  <div className="text-[10px] truncate" style={{ color: C.textDim }}>{a.ruleTitle} · {new Date(a.assignedAt).toLocaleDateString("de-DE")}</div>
                </div>
                <div className="text-xs font-bold whitespace-nowrap" style={{ color: C.red, fontFamily: "JetBrains Mono" }}>{a.amount.toLocaleString("de-DE", { minimumFractionDigits: 2 })} €</div>
                <button type="button" onClick={() => toggleAssignmentPaid(a)} className="px-2 py-1.5 rounded-lg text-[10px] font-bold flex-shrink-0" style={{ background: a.paidAt ? C.erfolgFlaeche : C.white, color: a.paidAt ? C.secondary : C.textDim }}>{a.paidAt ? "Bezahlt" : "Offen"}</button>
                <button type="button" onClick={() => removeAssignment(a)} aria-label={`Strafe bei ${a.playerName} entfernen`} className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: C.glass, color: C.red }}><X size={14}/></button>
              </div>
            ))}
            {filteredAssignments.length === 0 && <div className="text-[11px] rounded-xl p-3" style={{ background: C.glass, color: C.textDim }}>Noch keine Strafen vergeben.</div>}
          </div>
          {databaseMembership && <button type="button" onClick={() => setShowHistory((v) => !v)} className="text-[11px] font-bold mb-2" style={{ color: C.ink }}>{showHistory ? "Historie ausblenden" : "Saison-Historie anzeigen"}</button>}
          {showHistory && (
            <div className="rounded-xl p-3 mb-2" style={{ background: C.paperDim }}>
              {historyLoading ? <div className="text-[11px]" style={{ color: C.textDim }}>Historie wird geladen …</div> : Object.keys(historyBySeasons).length === 0 ? <div className="text-[11px]" style={{ color: C.textDim }}>Für diese Mannschaft liegt noch keine abgeschlossene Saison vor.</div> : Object.entries(historyBySeasons).map(([season, items]) => (
                <div key={season} className="mb-3 last:mb-0">
                  <div className="text-[10px] font-bold mb-1.5" style={{ color: C.ink }}>Saison {season} · {items.reduce((sum, i) => sum + i.amount, 0).toLocaleString("de-DE", { minimumFractionDigits: 2 })} €</div>
                  <div className="space-y-1">
                    {items.map((i) => <div key={i.id} className="flex items-center justify-between text-[11px] px-2 py-1.5 rounded-lg" style={{ background: C.glass }}><span style={{ color: C.ink }}>{i.playerName} · {i.ruleTitle}</span><span className="font-bold" style={{ color: C.red, fontFamily: "JetBrains Mono" }}>{i.amount.toLocaleString("de-DE", { minimumFractionDigits: 2 })} €</span></div>)}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
      {canManageSeasons && (
        <div className="pt-4 mt-4" style={{ borderTop: `1px solid ${C.line}` }}>
          <div className="text-[10px] font-bold mb-2" style={{ color: C.textDim }}>SAISON ABSCHLIESSEN (VEREINSWEIT)</div>
          <div className="text-[11px] mb-2" style={{ color: C.textDim }}>Archiviert alle bereits als bezahlt markierten Strafen des gesamten Vereins unter der angegebenen Saisonbezeichnung. Offene Strafen bleiben aktiv.</div>
          <div className="flex gap-2">
            <input value={seasonLabel} onChange={(e) => setSeasonLabel(e.target.value)} placeholder="z. B. 2025/26" className="flex-1 px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim, color: C.ink }}/>
            <button type="button" onClick={runSeasonReset} disabled={resettingSeason || !seasonLabel.trim()} className="px-4 rounded-xl text-xs font-bold" style={{ background: seasonLabel.trim() ? C.red : C.line, color: C.white }}>{resettingSeason ? "…" : "Abschließen"}</button>
          </div>
        </div>
      )}
    </>}
    {message && <div role="status" className="text-[11px] mt-2" style={{ color: message.includes("gespeichert") || message.includes("gelöscht") || message.includes("zugewiesen") || message.includes("markiert") || message.includes("abgeschlossen") ? C.erfolg : C.fehler }}>{message}</div>}
  </div>;
}
function TaskCreateForm({ form, setForm, onSubmit, onCancel, editing = false }) {
  return (
    <div className="rounded-2xl p-3.5 mb-3" style={{ background: C.paperDim }}>
      <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} maxLength={120} placeholder="Titel, z. B. Kuchen backen" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.glass, color: C.ink }}/>
      <input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} maxLength={300} placeholder="Beschreibung (optional)" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.glass, color: C.ink }}/>
      <div className="flex gap-2 mb-2">
        <input type="date" value={form.dueDate} onChange={(e) => setForm({ ...form, dueDate: e.target.value })} className="flex-1 px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.glass, color: C.ink }}/>
        <input type="number" min="1" value={form.slots} onChange={(e) => setForm({ ...form, slots: e.target.value })} placeholder="Personen" className="w-24 px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.glass, color: C.ink }}/>
      </div>
      <div className="flex gap-2">
        <button onClick={onSubmit} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white }}>{editing ? "Änderungen speichern" : "Anlegen"}</button>
        <button onClick={onCancel} className="px-4 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.glass, color: C.textDim }}>Abbrechen</button>
      </div>
    </div>
  );
}
function TasksView({ currentUser, members }) {
  const databaseMembership = !!supabase && isDbId(currentUser.id);
  const [clubTasks, setClubTasks] = useState([]);
  const [teamTasks, setTeamTasks] = useState([]);
  const [myTeams, setMyTeams] = useState([]);
  const [manageableTeamIds, setManageableTeamIds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [showCreateClub, setShowCreateClub] = useState(false);
  const [showCreateTeamId, setShowCreateTeamId] = useState("");
  const [editingTaskId, setEditingTaskId] = useState(null);
  const [form, setForm] = useState({ title: "", description: "", dueDate: "", slots: "1" });
  const canCreateClubTask = currentUser.roles.some((r) => !["spieler", "mitglied"].includes(r));
  const loadAll = useCallback(async () => {
    if (!databaseMembership) { setLoading(false); return; }
    setLoading(true); setMessage("");
    const { data: teamRows } = await supabase.from("team_members")
      .select("team_id,function,teams(id,name)")
      .eq("membership_id", currentUser.id);
    const teamMap = new Map();
    const manageIds = [];
    (teamRows || []).forEach((row) => {
      const team = Array.isArray(row.teams) ? row.teams[0] : row.teams;
      if (!team) return;
      teamMap.set(team.id, team.name);
      if (["trainer", "kapitaen", "teammanager"].includes(row.function)) manageIds.push(team.id);
    });
    setMyTeams([...teamMap.entries()].map(([id, name]) => ({ id, name })));
    setManageableTeamIds([...new Set(manageIds)]);
    const { data: tasksData, error } = await supabase.from("club_tasks")
      .select("id,team_id,title,description,due_date,slots_needed,created_by,teams(name),club_task_signups(membership_id,club_memberships(display_name))")
      .eq("club_id", currentUser.clubId)
      .order("created_at", { ascending: false });
    if (error) { setMessage("Die Aufgaben konnten nicht geladen werden."); setLoading(false); return; }
    const mapped = (tasksData || []).map((row) => {
      const team = Array.isArray(row.teams) ? row.teams[0] : row.teams;
      const signups = (row.club_task_signups || []).map((s) => {
        const m = Array.isArray(s.club_memberships) ? s.club_memberships[0] : s.club_memberships;
        return { membershipId: s.membership_id, name: m?.display_name || "—" };
      });
      return { id: row.id, teamId: row.team_id, teamName: team?.name, title: row.title, description: row.description, dueDate: row.due_date, slots: row.slots_needed, createdBy: row.created_by, signups };
    });
    setClubTasks(mapped.filter((t) => !t.teamId));
    setTeamTasks(mapped.filter((t) => t.teamId));
    setLoading(false);
  }, [databaseMembership, currentUser.id, currentUser.clubId]);
  useEffect(() => { loadAll(); }, [loadAll]);
  const resetForm = () => setForm({ title: "", description: "", dueDate: "", slots: "1" });
  const createTask = async (teamId) => {
    if (!form.title.trim()) { setMessage("Bitte einen Titel eingeben."); return; }
    const slotsNeeded = Math.max(1, Number(form.slots) || 1);
    if (editingTaskId) {
      const { error } = await supabase.from("club_tasks").update({
        title: form.title.trim(), description: form.description.trim() || null,
        due_date: form.dueDate || null, slots_needed: slotsNeeded,
      }).eq("id", editingTaskId);
      if (error) { setMessage("Aufgabe konnte nicht geändert werden."); return; }
      resetForm(); setEditingTaskId(null); setShowCreateClub(false); setShowCreateTeamId(""); setMessage("Aufgabe wurde geändert.");
      await loadAll();
      return;
    }
    const { error } = await supabase.from("club_tasks").insert({
      club_id: currentUser.clubId, team_id: teamId || null, title: form.title.trim(),
      description: form.description.trim() || null, due_date: form.dueDate || null,
      slots_needed: slotsNeeded, created_by: currentUser.id,
    });
    if (error) { setMessage("Aufgabe konnte nicht angelegt werden."); return; }
    resetForm(); setShowCreateClub(false); setShowCreateTeamId(""); setMessage("Aufgabe wurde angelegt.");
    await loadAll();
  };
  const openEditTask = (task) => {
    setForm({ title: task.title, description: task.description || "", dueDate: task.dueDate || "", slots: String(task.slots) });
    setEditingTaskId(task.id);
    setMessage("");
    if (task.teamId) { setShowCreateTeamId(task.teamId); setShowCreateClub(false); }
    else { setShowCreateClub(true); setShowCreateTeamId(""); }
  };
  const signUp = async (taskId) => {
    setMessage("");
    const { error } = await supabase.from("club_task_signups").insert({ task_id: taskId, membership_id: currentUser.id });
    if (error) { setMessage("Eintragen nicht möglich."); return; }
    await loadAll();
    supabase.rpc("check_task_reminder_threshold", { target_club: currentUser.clubId });
  };
  const withdraw = async (taskId) => {
    setMessage("");
    const { error } = await supabase.from("club_task_signups").delete().eq("task_id", taskId).eq("membership_id", currentUser.id);
    if (error) { setMessage("Konnte nicht entfernt werden."); return; }
    await loadAll();
  };
  const removeTask = async (task) => {
    if (!window.confirm(`Aufgabe „${task.title}“ wirklich löschen?`)) return;
    const { error } = await supabase.from("club_tasks").delete().eq("id", task.id);
    if (error) { setMessage("Konnte nicht gelöscht werden."); return; }
    await loadAll();
  };
  const TaskCard = ({ task, canManage, onEdit }) => {
    const taken = task.signups.length;
    const free = task.slots - taken;
    const isSignedUp = task.signups.some((s) => s.membershipId === currentUser.id);
    const isCreator = task.createdBy === currentUser.id;
    return (
      <div className="rounded-2xl p-3.5 mb-2" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
        <div className="flex items-start justify-between gap-2 mb-1">
          <div className="text-sm font-bold" style={{ color: C.ink }}>{task.title}</div>
          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full whitespace-nowrap" style={{ background: free > 0 ? C.erfolgFlaeche : C.fehlerFlaeche, color: free > 0 ? C.erfolg : C.fehler }}>{free > 0 ? `${free}/${task.slots} frei` : "voll"}</span>
        </div>
        {task.description && <div className="text-xs mb-1.5" style={{ color: C.textDim }}>{task.description}</div>}
        <div className="text-[10px] mb-2" style={{ color: C.textDim }}>{task.teamName ? `${task.teamName} · ` : "Verein · "}{task.dueDate ? `Fällig bis ${new Date(task.dueDate).toLocaleDateString("de-DE")}` : "Kein Fälligkeitsdatum"}</div>
        {taken > 0 && <div className="text-[10px] mb-2" style={{ color: C.textDim }}>Eingetragen: {task.signups.map((s) => s.name).join(", ")}</div>}
        <div className="flex gap-2">
          {!isSignedUp && free > 0 && <button onClick={() => signUp(task.id)} className="flex-1 py-2 rounded-lg text-xs font-bold" style={{ background: C.ink, color: C.white }}>Eintragen</button>}
          {isSignedUp && <button onClick={() => withdraw(task.id)} className="flex-1 py-2 rounded-lg text-xs font-bold" style={{ background: C.paperDim, color: C.red }}>Austragen</button>}
          {(isCreator || canManage) && <button onClick={() => onEdit(task)} className="px-3 py-2 rounded-lg text-xs font-bold" style={{ background: C.paperDim, color: C.textDim }}>Bearbeiten</button>}
          {(isCreator || canManage) && <button onClick={() => removeTask(task)} className="px-3 py-2 rounded-lg text-xs font-bold" style={{ background: C.paperDim, color: C.red }}>Löschen</button>}
        </div>
      </div>
    );
  };
  if (!databaseMembership) return <div className="px-4 pt-4 pb-24"><div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Aufgaben sind nur mit einem echten Vereinskonto verfügbar.</div></div>;
  return (
    <div className="px-4 pt-4 pb-24">
      <SectionTitle eyebrow="Verein" title="Aufgaben" right={canCreateClubTask ? <button onClick={() => { if (showCreateClub) { setEditingTaskId(null); resetForm(); } setShowCreateClub((v) => !v); }} className="px-3 py-1.5 rounded-full text-[10px] font-bold" style={{ background: C.ink, color: C.white }}>{showCreateClub ? "Schließen" : "+ Aufgabe"}</button> : null}/>
      <div className="text-xs mb-4 -mt-2" style={{ color: C.textDim }}>Vereins- und Mannschaftsaufgaben, für die sich Mitglieder freiwillig eintragen können.</div>
      {message && <div role="status" className="text-[11px] rounded-xl px-3 py-2 mb-4" style={{ background: (message.includes("angelegt")||message.includes("geändert")) ? C.erfolgFlaeche : C.fehlerFlaeche, color: (message.includes("angelegt")||message.includes("geändert")) ? C.erfolg : C.fehler }}>{message}</div>}
      {loading ? <div className="text-xs py-4" style={{ color: C.textDim }}>Aufgaben werden geladen …</div> : <>
        <SectionTitle eyebrow="Vereinsweit" title="Vereinsaufgaben"/>
        {showCreateClub && <TaskCreateForm form={form} setForm={setForm} editing={!!editingTaskId} onSubmit={() => createTask(null)} onCancel={() => { setShowCreateClub(false); resetForm(); setEditingTaskId(null); }}/>}
        {clubTasks.length === 0 ? <div className="text-xs rounded-xl p-3 mb-5" style={{ background: C.paperDim, color: C.textDim }}>Aktuell keine offenen Vereinsaufgaben.</div> : <div className="mb-5">{clubTasks.map((t) => <TaskCard key={t.id} task={t} canManage={canCreateClubTask} onEdit={openEditTask}/>)}</div>}
        {myTeams.map((team) => {
          const tasks = teamTasks.filter((t) => t.teamId === team.id);
          const canManage = manageableTeamIds.includes(team.id);
          return (
            <div key={team.id} className="mb-5">
              <SectionTitle eyebrow="Mannschaft" title={`Aufgaben · ${team.name}`} right={canManage ? <button onClick={() => { if (showCreateTeamId === team.id) { setEditingTaskId(null); resetForm(); } setShowCreateTeamId((v) => v === team.id ? "" : team.id); }} className="px-3 py-1.5 rounded-full text-[10px] font-bold" style={{ background: C.ink, color: C.white }}>{showCreateTeamId === team.id ? "Schließen" : "+ Aufgabe"}</button> : null}/>
              {showCreateTeamId === team.id && <TaskCreateForm form={form} setForm={setForm} editing={!!editingTaskId} onSubmit={() => createTask(team.id)} onCancel={() => { setShowCreateTeamId(""); resetForm(); setEditingTaskId(null); }}/>}
              {tasks.length === 0 ? <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Aktuell keine Aufgaben für {team.name}.</div> : tasks.map((t) => <TaskCard key={t.id} task={t} canManage={canManage} onEdit={openEditTask}/>)}
            </div>
          );
        })}
      </>}
    </div>
  );
}

function VehiclesView({ currentUser, currentClub }) {
  const cfg = sportConfig(currentClub?.sport);
  const databaseMembership = !!supabase && isDbId(currentUser.id);
  const canManageFleet = currentUser.roles.some((r) => ["vorstand", "vereinsadmin", "geschaeftsfuehrung"].includes(r));
  const canBook = canManageFleet || currentUser.roles.some((r) => ["trainer", "teammanager", "kapitaen", "finanzmanager"].includes(r));
  const hasPhone = (currentUser.contactPhones || []).some((p) => p && p.trim());
  const [vehicles, setVehicles] = useState([]);
  const [teams, setTeams] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [monthDate, setMonthDate] = useState(() => { const d = new Date(); d.setDate(1); d.setHours(0,0,0,0); return d; });
  const [showAddVehicle, setShowAddVehicle] = useState(false);
  const [newVehicle, setNewVehicle] = useState({ label: "", plate: "", seats: "" });
  const [savingVehicle, setSavingVehicle] = useState(false);
  const [editingVehicleId, setEditingVehicleId] = useState(null);
  const [selectedVehicle, setSelectedVehicle] = useState(null);
  const [editingBookingId, setEditingBookingId] = useState(null);
  const [bookingForm, setBookingForm] = useState({ startDate: "", startHour: "8", endDate: "", endHour: "18", teamId: "", isPrivate: false, privateLabel: "" });
  const [savingBooking, setSavingBooking] = useState(false);
  const [viewingBooking, setViewingBooking] = useState(null);
  const [viewingPhones, setViewingPhones] = useState(null);
  const [loadingPhones, setLoadingPhones] = useState(false);
  const [copiedPhone, setCopiedPhone] = useState("");
  const HOURS = Array.from({ length: 24 }, (_, i) => i);
  const loadVehicles = useCallback(async () => {
    if (!databaseMembership) { setVehicles([]); return; }
    const { data, error } = await supabase.from("club_vehicles").select("id,label,license_plate,seats").eq("club_id", currentUser.clubId).order("label");
    if (error) { setMessage("Die Fahrzeuge konnten nicht geladen werden."); return; }
    setVehicles(data || []);
  }, [databaseMembership, currentUser.clubId]);
  const loadTeams = useCallback(async () => {
    if (!databaseMembership) { setTeams([]); return; }
    const { data } = await supabase.from("teams").select("id,name").eq("club_id", currentUser.clubId).eq("active", true).order("name");
    setTeams(data || []);
  }, [databaseMembership, currentUser.clubId]);
  const loadBookings = useCallback(async () => {
    if (!databaseMembership) { setBookings([]); setLoading(false); return; }
    setLoading(true);
    const monthStart = new Date(monthDate.getFullYear(), monthDate.getMonth(), 1);
    const monthEnd = new Date(monthDate.getFullYear(), monthDate.getMonth() + 1, 1);
    const { data, error } = await supabase.from("vehicle_bookings")
      .select("id,vehicle_id,membership_id,team_id,private_label,starts_at,ends_at,club_vehicles(label),teams(name),club_memberships(display_name)")
      .eq("club_id", currentUser.clubId)
      .lt("starts_at", monthEnd.toISOString())
      .gt("ends_at", monthStart.toISOString())
      .order("starts_at");
    if (error) { setMessage("Die Buchungen konnten nicht geladen werden."); setLoading(false); return; }
    setBookings((data || []).map((row) => {
      const vehicle = Array.isArray(row.club_vehicles) ? row.club_vehicles[0] : row.club_vehicles;
      const team = Array.isArray(row.teams) ? row.teams[0] : row.teams;
      const member = Array.isArray(row.club_memberships) ? row.club_memberships[0] : row.club_memberships;
      return { id: row.id, vehicleId: row.vehicle_id, membershipId: row.membership_id, teamId: row.team_id, privateLabel: row.private_label, vehicleLabel: vehicle?.label || "—", label: team?.name || row.private_label || "Privat", bookedBy: member?.display_name || "—", startsAt: new Date(row.starts_at), endsAt: new Date(row.ends_at) };
    }));
    setLoading(false);
  }, [databaseMembership, currentUser.clubId, monthDate]);
  useEffect(() => { loadVehicles(); loadTeams(); }, [loadVehicles, loadTeams]);
  useEffect(() => { loadBookings(); }, [loadBookings]);
  const addVehicle = async () => {
    if (!newVehicle.label.trim() || !newVehicle.plate.trim() || !Number(newVehicle.seats)) { setMessage("Bitte alle Felder ausfüllen."); return; }
    setSavingVehicle(true); setMessage("");
    const payload = { label: newVehicle.label.trim(), license_plate: newVehicle.plate.trim(), seats: Number(newVehicle.seats) };
    const { error } = editingVehicleId
      ? await supabase.from("club_vehicles").update(payload).eq("id", editingVehicleId)
      : await supabase.from("club_vehicles").insert({ ...payload, club_id: currentUser.clubId, created_by: currentUser.id });
    if (error) { setMessage(editingVehicleId ? "Fahrzeug konnte nicht geändert werden." : "Fahrzeug konnte nicht angelegt werden."); setSavingVehicle(false); return; }
    setNewVehicle({ label: "", plate: "", seats: "" }); setEditingVehicleId(null); setShowAddVehicle(false); setSavingVehicle(false);
    await loadVehicles();
  };
  const openEditVehicle = (vehicle) => {
    setNewVehicle({ label: vehicle.label, plate: vehicle.license_plate, seats: String(vehicle.seats) });
    setEditingVehicleId(vehicle.id);
    setShowAddVehicle(true);
    setMessage("");
  };
  const removeVehicle = async (vehicle) => {
    if (!window.confirm(`Fahrzeug „${vehicle.label}“ wirklich löschen? Bestehende Buchungen werden ebenfalls entfernt.`)) return;
    const { error } = await supabase.from("club_vehicles").delete().eq("id", vehicle.id);
    if (error) { setMessage("Konnte nicht gelöscht werden."); return; }
    await loadVehicles(); await loadBookings();
  };
  const openBooking = (vehicle) => {
    setSelectedVehicle(vehicle);
    setEditingBookingId(null);
    const today = new Date().toISOString().slice(0, 10);
    setBookingForm({ startDate: today, startHour: "8", endDate: today, endHour: "18", teamId: "", isPrivate: false, privateLabel: "" });
    setMessage("");
  };
  const openEditBooking = (booking) => {
    const vehicle = vehicles.find((v) => v.id === booking.vehicleId);
    if (!vehicle) return;
    setSelectedVehicle(vehicle);
    setEditingBookingId(booking.id);
    setBookingForm({
      startDate: booking.startsAt.toISOString().slice(0, 10), startHour: String(booking.startsAt.getHours()),
      endDate: booking.endsAt.toISOString().slice(0, 10), endHour: String(booking.endsAt.getHours()),
      teamId: booking.teamId || "", isPrivate: !booking.teamId, privateLabel: booking.privateLabel || "",
    });
    setMessage("");
  };
  const openBookingDetail = async (booking) => {
    setViewingBooking(booking);
    setViewingPhones(null);
    setLoadingPhones(true);
    const { data } = await supabase.rpc("get_booking_contact_phone", { target_booking: booking.id });
    setViewingPhones(data || []);
    setLoadingPhones(false);
  };
  const copyPhone = (phone) => {
    navigator.clipboard?.writeText(phone);
    setCopiedPhone(phone);
    setTimeout(() => setCopiedPhone(""), 1500);
  };
  const submitBooking = async () => {
    if (!editingBookingId && !hasPhone) { setMessage("Bitte hinterlege zuerst eine Telefonnummer in deinem Profil (Profil → Kontaktdaten), um ein Fahrzeug zu buchen."); return; }
    if (!bookingForm.startDate || !bookingForm.endDate) { setMessage("Bitte Start- und Enddatum angeben."); return; }
    if (!bookingForm.isPrivate && !bookingForm.teamId) { setMessage("Bitte eine Mannschaft auswählen oder auf „Privat“ umschalten."); return; }
    if (bookingForm.isPrivate && !bookingForm.privateLabel.trim()) { setMessage("Bitte einen Namen für die private Buchung angeben."); return; }
    const startsAt = `${bookingForm.startDate}T${String(bookingForm.startHour).padStart(2, "0")}:00:00`;
    const endsAt = `${bookingForm.endDate}T${String(bookingForm.endHour).padStart(2, "0")}:00:00`;
    if (new Date(endsAt) <= new Date(startsAt)) { setMessage("Das Ende muss nach dem Start liegen."); return; }
    setSavingBooking(true); setMessage("");
    const payload = {
      vehicle_id: selectedVehicle.id,
      team_id: bookingForm.isPrivate ? null : bookingForm.teamId,
      private_label: bookingForm.isPrivate ? bookingForm.privateLabel.trim() : null,
      starts_at: startsAt, ends_at: endsAt,
    };
    const { error } = editingBookingId
      ? await supabase.from("vehicle_bookings").update(payload).eq("id", editingBookingId)
      : await supabase.from("vehicle_bookings").insert({ ...payload, club_id: currentUser.clubId, membership_id: currentUser.id });
    if (error) {
      setMessage(error.message?.includes("exclude") || error.code === "23P01" ? "Das Fahrzeug ist in diesem Zeitraum bereits gebucht." : editingBookingId ? "Buchung konnte nicht geändert werden." : "Buchung konnte nicht angelegt werden.");
      setSavingBooking(false); return;
    }
    if (!editingBookingId) {
      notifyClubAdmins(currentUser.clubId, "vehicle", "Neue Fahrzeugbuchung", `${currentUser.name} hat ${selectedVehicle.label} gebucht (${bookingForm.startDate} – ${bookingForm.endDate}).`, currentUser.id);
    }
    setSelectedVehicle(null); setEditingBookingId(null); setSavingBooking(false);
    await loadBookings();
  };
  const cancelBooking = async (booking) => {
    if (!window.confirm("Buchung wirklich stornieren?")) return;
    const { error } = await supabase.from("vehicle_bookings").delete().eq("id", booking.id);
    if (error) { setMessage("Konnte nicht storniert werden."); return; }
    await loadBookings();
  };
  const monthLabel = monthDate.toLocaleDateString("de-DE", { month: "long", year: "numeric" });
  const startOfMonth = new Date(monthDate.getFullYear(), monthDate.getMonth(), 1);
  const daysInMonth = new Date(monthDate.getFullYear(), monthDate.getMonth() + 1, 0).getDate();
  const startWeekday = (startOfMonth.getDay() + 6) % 7;
  const totalCells = Math.ceil((startWeekday + daysInMonth) / 7) * 7;
  const cells = Array.from({ length: totalCells }, (_, i) => {
    const dayNum = i - startWeekday + 1;
    if (dayNum < 1 || dayNum > daysInMonth) return null;
    return new Date(monthDate.getFullYear(), monthDate.getMonth(), dayNum);
  });
  const bookingsForDay = (day) => {
    if (!day) return [];
    const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate());
    const dayEnd = new Date(dayStart.getTime() + 86400000);
    return bookings.filter((b) => b.startsAt < dayEnd && b.endsAt > dayStart);
  };
  const canCancel = (booking) => booking.membershipId === currentUser.id || canManageFleet;
  if (!databaseMembership) return <div className="px-4 pt-4 pb-24"><div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Fahrzeugbuchungen sind nur mit einem echten Vereinskonto verfügbar.</div></div>;
  return (
    <div className="px-4 pt-4 pb-24">
      <SectionTitle eyebrow="Verein" title={cfg.vehicleTabLabel} right={canManageFleet ? <button onClick={() => { if (showAddVehicle) { setEditingVehicleId(null); setNewVehicle({ label: "", plate: "", seats: "" }); } setShowAddVehicle((v) => !v); }} className="px-3 py-1.5 rounded-full text-[10px] font-bold" style={{ background: C.ink, color: C.white }}>{showAddVehicle ? "Schließen" : "+ Fahrzeug"}</button> : null}/>
      <div className="text-xs mb-4 -mt-2" style={{ color: C.textDim }}>{cfg.vehicleIntro} Buchen können Vorstand, Vereinsadmin, Trainer, Teammanager, Kapitäne, Finanzmanager und Geschäftsführung.</div>
      {message && <div role="status" className="text-[11px] rounded-xl px-3 py-2 mb-4" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{message}</div>}
      {showAddVehicle && (
        <div className="rounded-2xl p-4 mb-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          <div className="text-sm font-bold mb-2">{editingVehicleId ? "Fahrzeug bearbeiten" : "Neues Fahrzeug"}</div>
          <input value={newVehicle.label} onChange={(e) => setNewVehicle({ ...newVehicle, label: e.target.value })} placeholder="Bezeichnung, z. B. Vereinsbus" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim }}/>
          <input value={newVehicle.plate} onChange={(e) => setNewVehicle({ ...newVehicle, plate: e.target.value })} placeholder="Kennzeichen" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim }}/>
          <input value={newVehicle.seats} onChange={(e) => setNewVehicle({ ...newVehicle, seats: e.target.value })} inputMode="numeric" placeholder="Anzahl Plätze" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim }}/>
          <div className="flex gap-2">
            <button onClick={addVehicle} disabled={savingVehicle} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white }}>{savingVehicle ? "…" : editingVehicleId ? "Änderungen speichern" : "Anlegen"}</button>
            {editingVehicleId && <button onClick={() => { setEditingVehicleId(null); setNewVehicle({ label: "", plate: "", seats: "" }); setShowAddVehicle(false); }} className="px-4 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.paperDim, color: C.textDim }}>Abbrechen</button>}
          </div>
        </div>
      )}
      <div className="space-y-2 mb-5">
        {vehicles.map((v) => (
          <div key={v.id} className="flex items-center gap-3 rounded-2xl px-3.5 py-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ background: C.paperDim, color: C.red }}><Car size={18}/></div>
            <button onClick={() => { if (!canBook) return; if (!hasPhone) { setMessage("Bitte hinterlege zuerst eine Telefonnummer in deinem Profil (Profil → Kontaktdaten), um ein Fahrzeug zu buchen."); return; } openBooking(v); }} disabled={!canBook} className="flex-1 text-left">
              <div className="text-sm font-bold" style={{ color: C.ink }}>{v.label}</div>
              <div className="text-[11px]" style={{ color: C.textDim }}>{v.license_plate} · {v.seats} Plätze</div>
            </button>
            {canBook && <ChevronRight size={15} style={{ color: C.textDim }}/>}
            {canManageFleet && <button onClick={() => openEditVehicle(v)} aria-label={`${v.label} bearbeiten`} className="px-2.5 py-1.5 rounded-lg text-[10px] font-bold flex-shrink-0" style={{ background: C.paperDim, color: C.textDim }}>Bearbeiten</button>}
            {canManageFleet && <button onClick={() => removeVehicle(v)} aria-label={`${v.label} löschen`} className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: C.paperDim, color: C.red }}><X size={14}/></button>}
          </div>
        ))}
        {vehicles.length === 0 && !loading && <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Noch keine Fahrzeuge hinterlegt.</div>}
      </div>
      <div className="flex items-center justify-between mb-3">
        <button onClick={() => setMonthDate((d) => new Date(d.getFullYear(), d.getMonth() - 1, 1))} aria-label="Vorheriger Monat" className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><ArrowLeft size={14}/></button>
        <div className="text-sm font-bold" style={{ color: C.ink, textTransform: "capitalize" }}>{monthLabel}</div>
        <button onClick={() => setMonthDate((d) => new Date(d.getFullYear(), d.getMonth() + 1, 1))} aria-label="Nächster Monat" className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><ArrowLeft size={14} style={{ transform: "rotate(180deg)" }}/></button>
      </div>
      {loading ? <div className="text-xs py-4 text-center" style={{ color: C.textDim }}>Kalender wird geladen …</div> : (
        <div className="rounded-2xl p-2 mb-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          <div className="grid grid-cols-7 gap-1 mb-1">
            {["Mo","Di","Mi","Do","Fr","Sa","So"].map((d) => <div key={d} className="text-center text-[9px] font-bold py-1" style={{ color: C.textDim }}>{d}</div>)}
          </div>
          <div className="grid grid-cols-7 gap-1">
            {cells.map((day, i) => {
              const dayBookings = bookingsForDay(day);
              return (
                <div key={i} className="rounded-lg p-1 min-h-[54px]" style={{ background: day ? C.paperDim : "transparent" }}>
                  {day && <div className="text-[9px] font-bold mb-0.5" style={{ color: C.textDim }}>{day.getDate()}</div>}
                  {dayBookings.slice(0, 2).map((b) => (
                    <div key={b.id} className="text-[8px] px-1 py-0.5 rounded mb-0.5 truncate" style={{ background: C.fehlerFlaeche, color: C.fehler }} title={`${b.vehicleLabel} · ${b.label} · ${b.bookedBy}`}>{b.vehicleLabel}: {b.label}</div>
                  ))}
                  {dayBookings.length > 2 && <div className="text-[8px]" style={{ color: C.textDim }}>+{dayBookings.length - 2} mehr</div>}
                </div>
              );
            })}
          </div>
        </div>
      )}
      <SectionTitle eyebrow="Übersicht" title="Buchungen diesen Monat"/>
      <div className="space-y-2">
        {bookings.map((b) => (
          <div key={b.id} className="flex items-center gap-3 rounded-xl px-3 py-2.5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <button onClick={() => openBookingDetail(b)} className="flex-1 min-w-0 text-left">
              <div className="text-xs font-bold truncate" style={{ color: C.ink }}>{b.vehicleLabel} · {b.label}</div>
              <div className="text-[10px] truncate" style={{ color: C.textDim }}>{b.bookedBy} · {b.startsAt.toLocaleDateString("de-DE")} {String(b.startsAt.getHours()).padStart(2,"0")}:00 – {b.endsAt.toLocaleDateString("de-DE")} {String(b.endsAt.getHours()).padStart(2,"0")}:00</div>
            </button>
            {canCancel(b) && (
              <div className="flex items-center gap-1.5 flex-shrink-0">
                <button onClick={() => openEditBooking(b)} className="px-2.5 py-1.5 rounded-lg text-[10px] font-bold" style={{ background: C.paperDim, color: C.textDim }}>Bearbeiten</button>
                <button onClick={() => cancelBooking(b)} aria-label="Buchung stornieren" className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: C.paperDim, color: C.red }}><X size={14}/></button>
              </div>
            )}
          </div>
        ))}
        {bookings.length === 0 && !loading && <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Keine Buchungen in diesem Monat.</div>}
      </div>
      {selectedVehicle && (
        <div className="fixed inset-0 z-50 flex items-end p-3" style={{ background: "rgba(20,21,26,.72)" }} onClick={() => { setSelectedVehicle(null); setEditingBookingId(null); }}>
          <div role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()} className="w-full rounded-3xl p-5 max-h-[85%] overflow-y-auto" style={{ background: C.glass }}>
            <div className="flex items-center justify-between mb-4">
              <div className="text-lg font-bold" style={{ fontFamily: "Oswald", color: C.ink }}>{selectedVehicle.label} {editingBookingId ? "bearbeiten" : "buchen"}</div>
              <button onClick={() => { setSelectedVehicle(null); setEditingBookingId(null); }} className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><X size={15}/></button>
            </div>
            <div className="text-[10px] font-bold mb-1" style={{ color: C.textDim }}>VON</div>
            <div className="flex gap-2 mb-3">
              <input type="date" value={bookingForm.startDate} onChange={(e) => setBookingForm({ ...bookingForm, startDate: e.target.value })} className="flex-1 px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}/>
              <select value={bookingForm.startHour} onChange={(e) => setBookingForm({ ...bookingForm, startHour: e.target.value })} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}>{HOURS.map((h) => <option key={h} value={h}>{String(h).padStart(2,"0")}:00</option>)}</select>
            </div>
            <div className="text-[10px] font-bold mb-1" style={{ color: C.textDim }}>BIS</div>
            <div className="flex gap-2 mb-3">
              <input type="date" value={bookingForm.endDate} onChange={(e) => setBookingForm({ ...bookingForm, endDate: e.target.value })} className="flex-1 px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}/>
              <select value={bookingForm.endHour} onChange={(e) => setBookingForm({ ...bookingForm, endHour: e.target.value })} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}>{HOURS.map((h) => <option key={h} value={h}>{String(h).padStart(2,"0")}:00</option>)}</select>
            </div>
            <label className="flex items-center gap-2 mb-3"><input type="checkbox" checked={bookingForm.isPrivate} onChange={(e) => setBookingForm({ ...bookingForm, isPrivate: e.target.checked })}/><span className="text-xs font-bold" style={{ color: C.ink }}>Private Buchung (keine Mannschaft)</span></label>
            {bookingForm.isPrivate ? (
              <input value={bookingForm.privateLabel} onChange={(e) => setBookingForm({ ...bookingForm, privateLabel: e.target.value })} placeholder="Name / Zweck" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-3" style={{ background: C.paperDim }}/>
            ) : (
              <select value={bookingForm.teamId} onChange={(e) => setBookingForm({ ...bookingForm, teamId: e.target.value })} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-3" style={{ background: C.paperDim }}>
                <option value="">Mannschaft wählen …</option>
                {teams.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
              </select>
            )}
            <button onClick={submitBooking} disabled={savingBooking} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white }}>{savingBooking ? (editingBookingId ? "Wird gespeichert …" : "Wird gebucht …") : (editingBookingId ? "Änderungen speichern" : "Fahrzeug buchen")}</button>
          </div>
        </div>
      )}
      {viewingBooking && (
        <div className="fixed inset-0 z-50 flex items-end p-3" style={{ background: "rgba(20,21,26,.72)" }} onClick={() => setViewingBooking(null)}>
          <div role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()} className="w-full rounded-3xl p-5 max-h-[85%] overflow-y-auto" style={{ background: C.glass }}>
            <div className="flex items-center justify-between mb-4">
              <div className="text-lg font-bold" style={{ fontFamily: "Oswald", color: C.ink }}>{viewingBooking.vehicleLabel}</div>
              <button onClick={() => setViewingBooking(null)} className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><X size={15}/></button>
            </div>
            <div className="text-xs font-bold mb-1" style={{ color: C.ink }}>{viewingBooking.label}</div>
            <div className="text-[11px] mb-4" style={{ color: C.textDim }}>{viewingBooking.startsAt.toLocaleDateString("de-DE")} {String(viewingBooking.startsAt.getHours()).padStart(2,"0")}:00 – {viewingBooking.endsAt.toLocaleDateString("de-DE")} {String(viewingBooking.endsAt.getHours()).padStart(2,"0")}:00</div>
            <div className="rounded-2xl p-3.5" style={{ background: C.paperDim }}>
              <div className="text-[10px] font-bold mb-1" style={{ color: C.textDim }}>GEBUCHT VON</div>
              <div className="text-sm font-bold mb-2.5" style={{ color: C.ink }}>{viewingBooking.bookedBy}</div>
              {loadingPhones ? (
                <div className="text-xs" style={{ color: C.textDim }}>Telefonnummer wird geladen …</div>
              ) : viewingPhones && viewingPhones.filter(Boolean).length > 0 ? (
                <div className="flex flex-col gap-1.5">
                  {viewingPhones.filter(Boolean).map((phone, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <a href={`tel:${phone.replace(/\s+/g, "")}`} className="flex-1 flex items-center gap-2 text-sm font-bold" style={{ color: C.red }}>
                        <Phone size={14}/> {phone}
                      </a>
                      <button onClick={() => copyPhone(phone)} aria-label="Telefonnummer kopieren" className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: C.glass, color: copiedPhone === phone ? C.secondary : C.textDim }}>
                        {copiedPhone === phone ? <Check size={13}/> : <Copy size={13}/>}
                      </button>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-xs" style={{ color: C.textDim }}>Keine Telefonnummer hinterlegt.</div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function DutyTasksSection({ ev, currentUser, sport }) {
  const cfg = sportConfig(sport);
  const [tasks, setTasks] = useState([]);
  const [templates, setTemplates] = useState([]);
  const [duMembers, setDutyMembers] = useState([]);
  const [canManage, setCanManage] = useState(false);
  const [loading, setLoading] = useState(true);
  const [selectedTemplate, setSelectedTemplate] = useState("");
  const [applying, setApplying] = useState(false);
  const [message, setMessage] = useState("");

  const loadTasks = useCallback(async () => {
    const { data, error } = await supabase.from("duty_tasks")
      .select("id,title,due_date,done,assignee_membership_id,club_memberships(display_name)")
      .eq("event_id", ev.id)
      .order("created_at", { ascending: true });
    if (!error) {
      setTasks((data || []).map((row) => {
        const assignee = Array.isArray(row.club_memberships) ? row.club_memberships[0] : row.club_memberships;
        return { id: row.id, title: row.title, dueDate: row.due_date, done: row.done, assigneeId: row.assignee_membership_id, assigneeName: assignee?.display_name || null };
      }));
    }
    setLoading(false);
  }, [ev.id]);

  useEffect(() => {
    let active = true;
    supabase.rpc("can_manage_duty_task", { target_event: ev.id }).then(({ data }) => { if (active) setCanManage(!!data); });
    loadTasks();
    return () => { active = false; };
  }, [ev.id, loadTasks]);

  useEffect(() => {
    if (!canManage) return;
    (async () => {
      const [{ data: templateRows }, { data: memberRows }] = await Promise.all([
        supabase.from("duty_task_templates").select("id,name").eq("club_id", currentUser.clubId).order("name"),
        supabase.from("club_memberships").select("id,display_name").eq("club_id", currentUser.clubId).eq("status", "active").order("display_name"),
      ]);
      setTemplates(templateRows || []);
      setDutyMembers(memberRows || []);
    })();
  }, [canManage, currentUser.clubId]);

  const applyTemplate = async () => {
    if (!selectedTemplate) return;
    setApplying(true); setMessage("");
    const { error } = await supabase.rpc("apply_duty_template", { target_event: ev.id, target_template: selectedTemplate });
    setApplying(false);
    if (error) { setMessage("Vorlage konnte nicht angewendet werden."); return; }
    setSelectedTemplate("");
    setMessage("Vorlage wurde angewendet.");
    await loadTasks();
  };
  const assignTask = async (taskId, membershipId) => { const { error } = await supabase.from("duty_tasks").update({ assignee_membership_id: membershipId || null }).eq("id", taskId); if (!error) await loadTasks(); };
  const setDueDate = async (taskId, date) => { const { error } = await supabase.from("duty_tasks").update({ due_date: date || null }).eq("id", taskId); if (!error) await loadTasks(); };
  const toggleDone = async (task) => { const { error } = await supabase.from("duty_tasks").update({ done: !task.done }).eq("id", task.id); if (!error) await loadTasks(); };
  const deleteTask = async (taskId) => { if (!window.confirm("Diese Station wirklich löschen?")) return; const { error } = await supabase.from("duty_tasks").delete().eq("id", taskId); if (!error) await loadTasks(); };
  const claimTask = async (taskId) => {
    setMessage("");
    const { error } = await supabase.rpc("claim_duty_task", { target_task: taskId });
    if (error) { setMessage("Aktion nicht möglich."); return; }
    await loadTasks();
  };

  if (!supabase) return null;
  if (loading) return <div className="mt-3 text-xs" style={{ color: C.textDim }}>{cfg.dutyTabLabel} wird geladen …</div>;

  return (
    <div className="mt-3">
      <div className="text-xs font-semibold mb-2" style={{ fontFamily: "Inter", color: C.ink }}>{cfg.dutyTabLabel}</div>
      {canManage && templates.length > 0 && (
        <div className="flex gap-2 mb-2.5">
          <select value={selectedTemplate} onChange={(e) => setSelectedTemplate(e.target.value)} className="flex-1 px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, color: C.ink }}>
            <option value="">Satz vorladen …</option>
            {templates.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
          <button onClick={applyTemplate} disabled={!selectedTemplate || applying} className="px-3 py-2 rounded-lg text-xs font-bold" style={{ background: selectedTemplate ? C.ink : C.line, color: C.white }}>{applying ? "…" : "Anwenden"}</button>
        </div>
      )}
      {tasks.length === 0 ? (
        <div className="text-[11px] rounded-xl p-2.5" style={{ background: C.paperDim, color: C.textDim }}>Noch keine Stationen für diesen {cfg.homeEventLabel} eingetragen.</div>
      ) : (
        <div className="flex flex-col gap-2">
          {tasks.map((task) => (
            <div key={task.id} className="rounded-xl p-2.5" style={{ background: C.paperDim }}>
              <div className="flex items-center justify-between gap-2 mb-1">
                <div className="text-xs font-bold flex items-center gap-1.5" style={{ color: C.ink }}>
                  {task.done ? <CheckCircle2 size={13} style={{ color: C.secondary }} /> : <Circle size={13} style={{ color: C.textDim }} />}
                  {task.title}
                </div>
                {canManage && <button onClick={() => deleteTask(task.id)} className="text-[10px] font-bold" style={{ color: C.red }}>Löschen</button>}
              </div>
              <div className="text-[10px] mb-1.5" style={{ color: C.textDim }}>
                {task.assigneeName ? `Zugewiesen: ${task.assigneeName}` : "Noch niemandem zugewiesen"}
                {task.dueDate ? ` · Frist ${new Date(task.dueDate).toLocaleDateString("de-DE")}` : ""}
              </div>
              {canManage && (
                <div className="flex gap-1.5">
                  <select value={task.assigneeId || ""} onChange={(e) => assignTask(task.id, e.target.value)} className="flex-1 px-2 py-1.5 rounded-lg text-[11px] outline-none" style={{ background: C.glass, color: C.ink }}>
                    <option value="">Nicht zugewiesen</option>
                    {duMembers.map((m) => <option key={m.id} value={m.id}>{m.display_name}</option>)}
                  </select>
                  <input type="date" value={task.dueDate || ""} onChange={(e) => setDueDate(task.id, e.target.value)} className="px-2 py-1.5 rounded-lg text-[11px] outline-none" style={{ background: C.glass, color: C.ink }}/>
                  <button onClick={() => toggleDone(task)} className="px-2 py-1.5 rounded-lg text-[11px] font-bold" style={{ background: task.done ? C.erfolgFlaeche : C.white, color: task.done ? C.secondary : C.textDim }}>{task.done ? "Erledigt" : "Erledigt?"}</button>
                </div>
              )}
              {!canManage && !task.assigneeId && <button onClick={() => claimTask(task.id)} className="w-full py-1.5 rounded-lg text-[11px] font-bold" style={{ background: C.ink, color: C.white }}>Ich übernehme das</button>}
              {!canManage && task.assigneeId === currentUser.id && <button onClick={() => claimTask(task.id)} className="w-full py-1.5 rounded-lg text-[11px] font-bold" style={{ background: C.glass, color: C.red }}>Zurückziehen</button>}
            </div>
          ))}
        </div>
      )}
      {message && <div className="text-[11px] mt-1.5" style={{ color: message.includes("wurde") ? C.erfolg : C.fehler }}>{message}</div>}
    </div>
  );
}

function DutyTemplatesPanel({ currentUser, sport }) {
  const cfg = sportConfig(sport);
  const [templates, setTemplates] = useState([]);
  const [loading, setLoading] = useState(true);
  const [newName, setNewName] = useState("");
  const [newItemTitles, setNewItemTitles] = useState({});
  const [expandedId, setExpandedId] = useState(null);
  const [message, setMessage] = useState("");
  const [messageOk, setMessageOk] = useState(false);

  const loadTemplates = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase.from("duty_task_templates")
      .select("id,name,duty_task_template_items(id,title,sort_order)")
      .eq("club_id", currentUser.clubId)
      .order("name");
    if (error) { setMessage("Sätze konnten nicht geladen werden."); setMessageOk(false); setLoading(false); return; }
    setTemplates((data || []).map((row) => ({
      id: row.id, name: row.name,
      items: (row.duty_task_template_items || []).slice().sort((a, b) => a.sort_order - b.sort_order),
    })));
    setLoading(false);
  }, [currentUser.clubId]);
  useEffect(() => { loadTemplates(); }, [loadTemplates]);

  const createTemplate = async () => {
    if (!newName.trim()) return;
    const { error } = await supabase.from("duty_task_templates").insert({ club_id: currentUser.clubId, name: newName.trim(), created_by: currentUser.id });
    if (error) { setMessage("Satz konnte nicht angelegt werden."); setMessageOk(false); return; }
    setNewName(""); setMessage("Satz wurde angelegt."); setMessageOk(true); await loadTemplates();
  };
  const deleteTemplate = async (id) => {
    if (!window.confirm("Diesen Satz inklusive aller Stationen wirklich löschen?")) return;
    const { error } = await supabase.from("duty_task_templates").delete().eq("id", id);
    if (error) { setMessage("Satz konnte nicht gelöscht werden."); setMessageOk(false); return; }
    await loadTemplates();
  };
  const addItem = async (templateId) => {
    const title = (newItemTitles[templateId] || "").trim();
    if (!title) return;
    const template = templates.find((t) => t.id === templateId);
    const nextOrder = template?.items.length || 0;
    const { error } = await supabase.from("duty_task_template_items").insert({ template_id: templateId, title, sort_order: nextOrder });
    if (error) { setMessage("Station konnte nicht hinzugefügt werden."); setMessageOk(false); return; }
    setNewItemTitles((all) => ({ ...all, [templateId]: "" }));
    await loadTemplates();
  };
  const removeItem = async (itemId) => { const { error } = await supabase.from("duty_task_template_items").delete().eq("id", itemId); if (!error) await loadTemplates(); };

  if (!supabase) return <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>{cfg.dutyTabLabel}-Sätze sind nur mit einem echten Vereinskonto verfügbar.</div>;
  if (loading) return <div className="text-xs py-4" style={{ color: C.textDim }}>{cfg.dutyTabLabel}-Sätze werden geladen …</div>;

  return (
    <div>
      <SectionTitle eyebrow={cfg.dutyTabLabel} title="Sätze & Stationen" />
      <div className="text-xs mb-4 -mt-2" style={{ color: C.textDim }}>Wiederverwendbare Vorlagen mit Stationen, die beim Anlegen eines {cfg.homeEventLabel}s vorgeladen werden können.</div>
      {message && <div role="status" className="text-[11px] rounded-xl px-3 py-2 mb-4" style={{ background: messageOk ? C.erfolgFlaeche : C.fehlerFlaeche, color: messageOk ? C.erfolg : C.fehler }}>{message}</div>}
      <div className="rounded-2xl p-3.5 mb-4" style={{ background: C.paperDim }}>
        <div className="flex gap-2">
          <input value={newName} onChange={(e) => setNewName(e.target.value)} maxLength={80} placeholder={`Name, z. B. Standard ${cfg.homeEventLabel}tag`} className="flex-1 px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.glass, color: C.ink }}/>
          <button onClick={createTemplate} disabled={!newName.trim()} className="px-4 py-2.5 rounded-xl text-xs font-bold" style={{ background: newName.trim() ? C.ink : C.line, color: C.white }}>Anlegen</button>
        </div>
      </div>
      {templates.length === 0 ? (
        <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Noch keine Sätze angelegt.</div>
      ) : templates.map((t) => {
        const open = expandedId === t.id;
        return (
          <div key={t.id} className="rounded-2xl mb-2.5 overflow-hidden" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <button className="w-full text-left p-3.5 flex items-center justify-between" onClick={() => setExpandedId(open ? null : t.id)}>
              <div>
                <div className="text-sm font-bold" style={{ color: C.ink }}>{t.name}</div>
                <div className="text-[10px]" style={{ color: C.textDim }}>{t.items.length} Station{t.items.length === 1 ? "" : "en"}</div>
              </div>
              <ChevronDown size={16} style={{ color: C.textDim, transform: open ? "rotate(180deg)" : "none", transition: "transform .2s" }} />
            </button>
            {open && (
              <div className="px-3.5 pb-3.5">
                {t.items.map((item) => (
                  <div key={item.id} className="flex items-center justify-between gap-2 rounded-lg px-2.5 py-1.5 mb-1.5" style={{ background: C.paperDim }}>
                    <span className="text-xs" style={{ color: C.ink }}>{item.title}</span>
                    <button onClick={() => removeItem(item.id)} className="text-[10px] font-bold" style={{ color: C.red }}>Entfernen</button>
                  </div>
                ))}
                <div className="flex gap-2 mt-2">
                  <input value={newItemTitles[t.id] || ""} onChange={(e) => setNewItemTitles((all) => ({ ...all, [t.id]: e.target.value }))} maxLength={60} placeholder={`Station, ${cfg.dutyStationExamples}`} className="flex-1 px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, color: C.ink }}/>
                  <button onClick={() => addItem(t.id)} disabled={!(newItemTitles[t.id] || "").trim()} className="px-3 py-2 rounded-lg text-xs font-bold" style={{ background: (newItemTitles[t.id] || "").trim() ? C.ink : C.line, color: C.white }}>+ Station</button>
                </div>
                <button onClick={() => deleteTemplate(t.id)} className="w-full mt-3 py-2 rounded-lg text-xs font-bold" style={{ background: C.paperDim, color: C.red }}>Satz löschen</button>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function PlayerDataCard({ user, setMembers }) {
  const [editing, setEditing] = useState(false);
  const [number, setNumber] = useState(user.number ?? "");

  const save = () => {
    setMembers((ms) => ms.map((m) => (m.id === user.id ? { ...m, number: number === "" ? null : Number(number) } : m)));
    setEditing(false);
  };
  const cancel = () => { setNumber(user.number ?? ""); setEditing(false); };

  return (
    <div className="rounded-2xl p-4 mb-5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2 text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}><Star size={15} style={{ color: C.secondary }} /> Athletendaten</div>
        {!editing && (
          <button onClick={() => setEditing(true)} className="text-xs font-bold px-2.5 py-1 rounded-full" style={{ background: C.paperDim, color: C.ink, fontFamily: "Inter" }}>Bearbeiten</button>
        )}
      </div>

      {!editing ? (
        <div>
          <div className="rounded-xl px-3 py-2.5" style={{ background: C.paperDim }}>
            <div className="text-[10px] uppercase tracking-widest" style={{ color: C.textDim, fontFamily: "Inter" }}>Rückennummer</div>
            <div className="text-sm" style={{ fontFamily: "JetBrains Mono", fontWeight: 700, color: C.ink }}>{user.number ?? "—"}</div>
          </div>
        </div>
      ) : (
        <div className="space-y-2.5">
          <div>
            <div className="text-[11px] mb-1" style={{ color: C.textDim, fontFamily: "Inter" }}>Rückennummer</div>
            <input type="number" min="0" max="99" value={number} onChange={(e) => setNumber(e.target.value)} placeholder="z. B. 14"
              className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", color: C.ink }} />
          </div>
          <div className="flex gap-2">
            <button onClick={save} className="flex-1 py-2 rounded-lg text-xs" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700 }}>Speichern</button>
            <button onClick={cancel} className="px-4 py-2 rounded-lg text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter", fontWeight: 700 }}>Abbrechen</button>
          </div>
        </div>
      )}
    </div>
  );
}

/* Zugang und Freischaltung.
 *
 * Hier stand bis zum 31.08.2026 der In-App-Kauf: Tarifauswahl, Preise,
 * Kaufknopf, Wiederherstellen. Das ist ersatzlos entfallen, und zwar nicht der
 * Provision wegen.
 *
 * Ein Apple-Abo gehoert einer Person, nicht einem Verein. Wechselt der
 * Kassenwart, geht das Abo mit ihm. Wer zwei Vereine betreut, kann fuer den
 * zweiten nicht zahlen - das ist beim Testen aufgefallen und kein Fehler,
 * sondern Apples Modell. Und der Verein bekommt keine Rechnung, sondern eine
 * Belastung auf einem privaten Konto; fuer einen eingetragenen Verein mit
 * Kassenpruefung ist das kaum verbuchbar.
 *
 * Stattdessen fragt die Vereinsleitung den Vollzugang hier an, der Betreiber
 * stellt eine Rechnung, und nach Zahlungseingang wird freigeschaltet. Die
 * Freischaltung selbst ist unveraendert - ein Eintrag in club_subscriptions,
 * den club_subscription_tier auswertet.
 *
 * Wichtig fuer Apple: In der ganzen App wird NICHTS verkauft. Keine Preise,
 * kein Kaufknopf, kein Verweis auf eine Zahlungsseite. Richtlinie 3.1.3 laesst
 * das fuer Dienste zu, die an Organisationen verkauft werden - aber nur, wenn
 * in der App weder gekauft noch zum Kauf aufgefordert wird. */
function SubscriptionPanel({ user }) {
  const [clubStatus, setClubStatus] = useState(null);
  const [accountUsage, setAccountUsage] = useState(null);
  const [anfrage, setAnfrage] = useState(undefined); // undefined = laedt, null = keine
  const [formularOffen, setFormularOffen] = useState(false);
  const [form, setForm] = useState({ contact_name: user.name || "", contact_email: user.email || "", contact_phone: "", expected_accounts: "", note: "", sponsoring: false });
  const [sendet, setSendet] = useState(false);
  const [message, setMessage] = useState("");

  const databaseClub = !!supabase && isDbId(user.clubId);
  /* Der Text weiter unten nennt ausdruecklich "Vorstand, Geschaeftsfuehrung
     oder Vereinsadmin". Ein Vorstand bekam bisher genau diesen Satz zu lesen -
     und keinen Knopf. */
  const darfAnfragen = canManageSubscription(user);

  const laden = useCallback(async () => {
    if (!databaseClub) { setAnfrage(null); return; }
    const [{ data: tarif }, { data: nutzung }, { data: offen }] = await Promise.all([
      supabase.rpc("club_subscription_tier", { target_club: user.clubId }),
      supabase.rpc("club_account_usage", { target_club: user.clubId }),
      /* Nur laufende Vorgaenge. Ohne den Filter blieb die zuletzt auf
         "freigeschaltet" oder "abgelehnt" gesetzte Zeile stehen, und der Verein
         sah bis in alle Ewigkeit "Anfrage liegt vor - wir melden uns" - ohne
         Formular und ohne Knopf zum Zuruecknehmen. Damit konnte weder ein
         abgelehnter Verein es erneut versuchen noch ein zahlender seine
         Verlaengerung anfragen. Die Datenbank haette beides erlaubt. */
      supabase.from("club_access_requests").select("id,status,created_at,contact_name").eq("club_id", user.clubId).in("status", ["offen", "berechnet"]).order("created_at", { ascending: false }).limit(1),
    ]);
    setClubStatus({ tier: tarif || "none" });
    setAccountUsage(nutzung?.[0] || null);
    setAnfrage(offen?.[0] || null);
  }, [databaseClub, user.clubId]);
  useEffect(() => { laden(); }, [laden]);

  const absenden = async (e) => {
    e.preventDefault();
    if (!form.contact_name.trim() || !form.contact_email.trim()) { setMessage("Bitte Name und E-Mail angeben."); return; }
    setSendet(true); setMessage("");
    const { error } = await supabase.from("club_access_requests").insert({
      club_id: user.clubId,
      requested_by: isDbId(user.id) ? user.id : null,
      contact_name: form.contact_name.trim(),
      contact_email: form.contact_email.trim(),
      contact_phone: form.contact_phone.trim() || null,
      expected_accounts: form.expected_accounts ? Number(form.expected_accounts) : null,
      sponsoring_gewuenscht: form.sponsoring,
      note: form.note.trim() || null,
    });
    if (error) {
      /* Der eindeutige Index laesst nur eine offene Anfrage je Verein zu -
         sonst sammelt sich beim Betreiber derselbe Wunsch mehrfach, weil in der
         App mehrere Berechtigte sitzen. */
      setMessage(/duplicate|unique/i.test(error.message || "")
        ? "Für euren Verein liegt bereits eine Anfrage vor. Wir melden uns."
        : "Die Anfrage konnte nicht gesendet werden.");
      setSendet(false); return;
    }
    setFormularOffen(false); setSendet(false);
    await laden();
  };

  const zurueckziehen = async () => {
    if (!anfrage || !window.confirm("Anfrage zurückziehen?")) return;
    await supabase.from("club_access_requests").delete().eq("id", anfrage.id);
    await laden();
  };

  const vollzugang = clubStatus && clubStatus.tier !== "none";

  return <div>
    {message && <div role="status" className="text-[11px] rounded-xl px-3 py-2 mb-4" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{message}</div>}

    <SectionTitle eyebrow="Mein Zugang" title="Für dich kostenlos" />
    <div className="rounded-2xl p-4 mb-3" style={{ background: C.erfolgFlaeche, border: `1px solid ${C.erfolgRand}` }}>
      <div className="text-sm font-bold mb-1" style={{ color: C.ink }}>Kein eigenes Abo nötig</div>
      <div className="text-[11px]" style={{ color: C.textDim }}>Dein Zugang wird vom Verein bezahlt. Welche Funktionen du nutzen kannst, hängt allein von deinen Rollen im Verein ab.</div>
    </div>

    {clubStatus && (
      <div className="rounded-2xl p-4 mb-5" style={{ background: vollzugang ? C.erfolgFlaeche : C.paperDim, border: `1px solid ${vollzugang ? C.erfolgRand : C.line}` }}>
        <div className="text-sm font-bold mb-1" style={{ color: C.ink }}>
          {vollzugang ? `Vollzugang aktiv (${CLUB_TIER_INFO[clubStatus.tier]?.label || clubStatus.tier})` : "Kostenlose Stufe"}
        </div>
        {accountUsage && <div className="text-[11px]" style={{ color: accountUsage.used >= accountUsage.allowed ? C.red : C.textDim }}>
          {accountUsage.used} von {accountUsage.allowed} Zugängen belegt{accountUsage.used >= accountUsage.allowed ? " — für weitere Mitglieder braucht ihr den Vollzugang." : ""}
        </div>}
        {!vollzugang && <div className="text-[11px] mt-1.5" style={{ color: C.textDim }}>Trainings- und Spielpläne sind dauerhaft kostenlos. Mannschaften, Chat, Vereins-News, Helferplanung, Fahrzeugbuchung und das Kalender-Abo kommen mit dem Vollzugang dazu.</div>}
      </div>
    )}

    {/* Ohne Datenbank gibt es nichts abzuschicken: supabase ist dann null, und
        der Knopf fuehrte in einen TypeError, nach dem er auf "Wird gesendet ..."
        stehen blieb. */}
    {!vollzugang && databaseClub && anfrage !== undefined && (
      <>
        <SectionTitle eyebrow="Vollzugang" title="Für den ganzen Verein freischalten" />

        {anfrage ? (
          <div className="rounded-2xl p-4 mb-5" style={{ background: C.sekundaerWeich, border: `1px solid ${C.edge}` }}>
            <div className="text-sm font-bold mb-1" style={{ color: C.ink }}>
              {anfrage.status === "berechnet" ? "Rechnung ist unterwegs" : "Anfrage liegt vor"}
            </div>
            <div className="text-[11px]" style={{ color: C.textDim }}>
              {anfrage.status === "berechnet"
                ? "Wir haben euch die Rechnung geschickt. Nach dem Zahlungseingang schalten wir den Verein frei."
                : `Eingegangen am ${new Date(anfrage.created_at).toLocaleDateString("de-DE")} durch ${anfrage.contact_name}. Wir melden uns mit einem Angebot.`}
            </div>
            {anfrage.status === "offen" && darfAnfragen && (
              <button onClick={zurueckziehen} className="text-[11px] font-bold mt-2.5 underline" style={{ color: C.textDim }}>Anfrage zurückziehen</button>
            )}
          </div>
        ) : darfAnfragen ? (
          formularOffen ? (
            <form onSubmit={absenden} className="rounded-2xl p-4 mb-5 space-y-2.5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
              <div className="text-[11px] mb-1" style={{ color: C.textDim }}>Wir melden uns mit einem Angebot für euren Verein und stellen eine Rechnung. Nach dem Zahlungseingang ist der Verein freigeschaltet.</div>
              <input value={form.contact_name} onChange={(e) => setForm({ ...form, contact_name: e.target.value })} placeholder="Ansprechpartner *" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
              <input type="email" value={form.contact_email} onChange={(e) => setForm({ ...form, contact_email: e.target.value })} placeholder="E-Mail für die Rechnung *" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
              <input type="tel" value={form.contact_phone} onChange={(e) => setForm({ ...form, contact_phone: e.target.value })} placeholder="Telefon (optional)" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
              <input type="number" min="1" value={form.expected_accounts} onChange={(e) => setForm({ ...form, expected_accounts: e.target.value })} placeholder="Wie viele Mitglieder bekommen einen Zugang?" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
              {/* Der Zusatz steht im Formular und nicht in einer Preisliste
                  daneben: Wer ihn hier nicht ankreuzt, bekommt eine Rechnung
                  ohne ihn - und das ist dann auch so gewollt. */}
              <button type="button" onClick={() => setForm({ ...form, sponsoring: !form.sponsoring })} className="w-full flex items-start gap-2.5 px-3 py-2.5 rounded-xl text-left" style={{ background: C.paperDim }}>
                <span className="w-4 h-4 rounded flex-shrink-0 flex items-center justify-center mt-0.5" style={{ background: form.sponsoring ? C.ink : "transparent", border: `1.5px solid ${form.sponsoring ? C.ink : C.line}` }}>{form.sponsoring && <Check size={11} style={{ color: C.white }} />}</span>
                <span className="flex-1">
                  <span className="text-xs block" style={{ color: C.ink, fontWeight: 600 }}>Eigene Sponsoren zeigen</span>
                  <span className="text-[10px] block mt-0.5" style={{ color: C.textDim }}>Die Werbeplätze in der App mit euren eigenen Sponsoren belegen, inklusive zeitlich begrenzter Aktionen.</span>
                </span>
              </button>
              <textarea value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} rows={2} placeholder="Anmerkung (optional)" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none resize-none" style={{ background: C.paperDim }} />
              <div className="flex gap-2">
                <button type="submit" disabled={sendet} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white, opacity: sendet ? .6 : 1 }}>{sendet ? "Wird gesendet …" : "Anfrage senden"}</button>
                <button type="button" onClick={() => setFormularOffen(false)} className="px-4 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.paperDim, color: C.textDim }}>Abbrechen</button>
              </div>
            </form>
          ) : (
            <div className="rounded-2xl p-4 mb-5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
              <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Der Vollzugang wird dem Verein in Rechnung gestellt, nicht dir persönlich. Sag uns Bescheid, dann melden wir uns mit einem Angebot.</div>
              <button onClick={() => setFormularOffen(true)} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white }}>Vollzugang anfragen</button>
            </div>
          )
        ) : (
          <div className="rounded-2xl p-4 mb-5 text-[11px]" style={{ background: C.paperDim, color: C.textDim }}>
            Den Vollzugang kann die Vereinsleitung anfragen — Vorstand, Geschäftsführung oder Vereinsadmin.
          </div>
        )}
      </>
    )}
  </div>;
}

/* Unterseite über dem Profil: liegt als eigene milchige Glasfläche über dem Inhalt.
   Die Ebene dahinter bleibt schemenhaft sichtbar, wird aber kräftig weichgezeichnet —
   ohne diese Deckung würde man mitten durch die Seite auf die Liste darunter lesen. */
function ProfileUnderlay({ title, eyebrow = "Profileinstellungen", onClose, onSave, saving = false, saveDisabled = false, children }) {
  return <div className="erg-underlay absolute inset-0 z-40 flex flex-col">
    <div className="erg-underlay-bar flex items-center gap-3 px-4 py-3 flex-shrink-0" style={{ borderBottom: `1px solid ${C.line}` }}>
      <button onClick={onClose} aria-label="Zurück zum Profil" className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: C.glass, border: `1px solid ${C.edge}` }}><ArrowLeft size={16}/></button>
      <div className="flex-1 min-w-0"><div className="text-[9px] uppercase tracking-widest font-bold" style={{ color: C.red }}>{eyebrow}</div><div className="text-base font-bold truncate" style={{ fontFamily: "Oswald", color: C.ink }}>{title}</div></div>
      {onSave && <button onClick={onSave} disabled={saving || saveDisabled} className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-[11px] font-bold flex-shrink-0" style={{ background: C.red, color: C.white, opacity: saving || saveDisabled ? .45 : 1 }}><Save size={13}/>{saving ? "Speichert …" : "Speichern"}</button>}
    </div>
    <div className="flex-1 overflow-y-auto px-4 pt-4 pb-24">{children}</div>
  </div>;
}

function ProfileSettingsCard({ icon: Icon, title, description, onClick, color = C.red }) {
  return <button onClick={onClick} className="w-full flex items-center gap-3.5 rounded-2xl px-4 py-3.5 text-left" style={{ background: C.glass, border: `1px solid ${C.edge}`, boxShadow: "0 10px 26px rgba(60,30,45,0.07)" }}><div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: `linear-gradient(155deg, color-mix(in srgb, ${color} 72%, #fff), ${color})`, boxShadow: `0 6px 14px color-mix(in srgb, ${color} 34%, transparent), inset 0 1px 0 rgba(255,255,255,0.45)`, color: "#fff" }}><Icon size={18}/></div><div className="flex-1 min-w-0"><div className="text-sm font-bold" style={{ color: C.ink }}>{title}</div><div className="text-[10px] leading-snug" style={{ color: C.textDim }}>{description}</div></div><ChevronRight size={15} style={{ color: C.textDim }}/></button>;
}

function HowToVideoLibrary({ user, vorhanden = null }) {
  const [openId, setOpenId] = useState("");
  /* Welche Videos sich nicht laden liessen.
     Vorher zeigte der Player in dem Fall eine schwarze Flaeche - ohne jede
     Meldung, ohne Hinweis, dass die Datei fehlt. Genau diese Klasse ("wirkt
     unfertig") faellt bei einer App-Pruefung auf. */
  const [fehlend, setFehlend] = useState([]);
  /* Nur Eintraege, zu denen auch eine Datei im Speicher liegt. Liegen zwei von
     vier, stehen zwei da - und nicht zwei plus zwei Fehlermeldungen. */
  const videos = howToVideosFor(user).filter((video) => !vorhanden || vorhanden.includes(video.file));
  return (
    <div className="space-y-2">
      <div className="text-[11px] mb-1" style={{ color: C.textDim }}>Kurze Videos, passend zu dem, was du in deinem Verein tun kannst — nur Aktionen, die deine Rolle auch wirklich ausführen darf.</div>
      {videos.map((video) => {
        const open = openId === video.id;
        return (
          <div key={video.id} className="rounded-2xl overflow-hidden" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <button onClick={() => setOpenId(open ? "" : video.id)} className="w-full flex items-center gap-3 px-3.5 py-3 text-left">
              <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: C.paperDim, color: C.red }}><PlayCircle size={18}/></div>
              <div className="flex-1 min-w-0"><div className="text-sm font-bold" style={{ color: C.ink }}>{video.title}</div><div className="text-[10px] leading-snug" style={{ color: C.textDim }}>{video.description}</div></div>
              <ChevronDown size={15} style={{ color: C.textDim, transform: open ? "rotate(180deg)" : "none", transition: "transform .2s" }}/>
            </button>
            {open && (
              <div className="px-3.5 pb-3.5">
                {fehlend.includes(video.id) ? (
                  <div className="rounded-xl px-3.5 py-4 text-[11px] leading-relaxed" style={{ background: C.paperDim, color: C.textDim }}>
                    Dieses Video ist gerade nicht abrufbar. Die Beschreibung oben sagt dir trotzdem,
                    wo die Funktion zu finden ist.
                  </div>
                ) : (
                  <video
                    key={video.id}
                    src={howToVideoUrl(video.file)}
                    controls
                    playsInline
                    onError={() => setFehlend((alle) => (alle.includes(video.id) ? alle : [...alle, video.id]))}
                    className="w-full rounded-xl"
                    style={{ background: C.ink, aspectRatio: "9 / 16", maxHeight: 420 }}
                  />
                )}
              </div>
            )}
          </div>
        );
      })}
      {videos.length === 0 && <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim }}>Für deine aktuellen Rollen gibt es noch keine Videos.</div>}
    </div>
  );
}

function BoardMemberOverview({ members, currentUser }) {
  const [search, setSearch] = useState("");
  const [liveMembers, setLiveMembers] = useState(null);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [selectedMember, setSelectedMember] = useState(null);
  useEffect(() => {
    const load = async () => {
      setLoading(true); setMessage("");
      if (!supabase || !currentUser?.clubId) { setLiveMembers(null); setLoading(false); return; }
      const { data, error } = await supabase.from("club_memberships")
        .select("id,display_name,email,member_since,status,membership_roles(role),team_members(function,teams(name))")
        .eq("club_id", currentUser.clubId).eq("status", "active");
      if (error) { setMessage("Die Mitgliederliste konnte nicht geladen werden."); setLoading(false); return; }
      /* team ist das eine Feld, wenn nur EINE Mannschaft gemeint sein kann.
         Vorher stand dort playerTeamNames[0] - also die Zeile, die Supabase
         zufaellig zuerst zurueckgab. Wer in Herren 1 und Herren 2 spielt,
         bekam mal die eine, mal die andere als Hauptmannschaft. Jetzt gilt
         immer die hoechste. */
      const roster = (data || []).map((record, index) => {
        const assignments = record.team_members || [];
        const teamNames = [...new Set(assignments.map((entry) => entry.teams?.name).filter(Boolean))];
        const funktionsTeams = (funktion) => [...new Set(assignments.filter((entry) => entry.function === funktion).map((entry) => entry.teams?.name).filter(Boolean))];
        const playerTeamNames = funktionsTeams("spieler");
        return {
          id: record.id, name: record.display_name, email: record.email || "",
          trainerTeams: funktionsTeams("trainer"), captainTeams: funktionsTeams("kapitaen"),
          managedTeams: funktionsTeams("teammanager"), managedTeam: funktionsTeams("teammanager")[0] || null,
          team: hoechsteMannschaft(playerTeamNames) || hoechsteMannschaft(teamNames) || "Mitglied", teams: teamNames, playerTeams: playerTeamNames,
          roles: (record.membership_roles || []).map((entry) => entry.role),
          color: AVATAR_FARBEN[index % 5],
        };
      });
      setLiveMembers(roster);
      setLoading(false);
    };
    load();
  }, [currentUser?.clubId]);
  const source = liveMembers || members;
  const filtered = source
    .filter((m) => m.name.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => a.name.localeCompare(b.name, "de"));
  return <div>
    <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Nur-Lese-Ansicht aller Vereinsmitglieder. Änderungen sind hier nicht möglich.</div>
    <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Mitglied suchen …" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-3" style={{ background: C.paperDim, color: C.ink }}/>
    {loading && !liveMembers && supabase && <div className="text-xs py-3" style={{ color: C.textDim }}>Wird geladen …</div>}
    {message && <div className="text-[11px] mb-2" style={{ color: C.red }}>{message}</div>}
    <div className="space-y-2">
      {filtered.map((m) => <div key={m.id} onClick={() => setSelectedMember(m)} role="button" tabIndex={0} className="rounded-2xl p-3 cursor-pointer" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
        <div className="flex items-center gap-3 mb-1.5">
          <div className="w-9 h-9 rounded-full flex items-center justify-center text-[10px] font-bold flex-shrink-0" style={{ background: m.color, color: C.white }}>{initialsOf(m.name)}</div>
          <div className="flex-1 min-w-0">
            <div className="text-xs font-bold truncate" style={{ color: C.ink }}>{m.name}</div>
            <div className="text-[10px] truncate" style={{ color: C.textDim }}>{m.email || "—"}</div>
          </div>
          <ChevronRight size={14} style={{ color: C.textDim }}/>
        </div>
        <div className="flex flex-wrap gap-1">
          {m.roles.map((r) => <Pill key={r} bg={ROLE_META[r]?.color || C.textDim}>{ROLE_META[r]?.label || r}</Pill>)}
        </div>
        {memberPlayerTeams(m).length > 0 && <div className="text-[10px] mt-1.5" style={{ color: C.textDim }}>{memberPlayerTeams(m).join(" · ")}</div>}
      </div>)}
      {filtered.length === 0 && <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Keine Mitglieder gefunden.</div>}
    </div>
    {selectedMember && <MemberDetailPanel member={selectedMember} onClose={() => setSelectedMember(null)} />}
  </div>;
}
function MemberDetailPanel({ member, onClose }) {
  const [loading, setLoading] = useState(true);
  const [penalties, setPenalties] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [carpoolsAsDriver, setCarpoolsAsDriver] = useState([]);
  const [carpoolsAsPassenger, setCarpoolsAsPassenger] = useState([]);
  const [message, setMessage] = useState("");
  useEffect(() => {
    const load = async () => {
      setLoading(true); setMessage("");
      if (!supabase) { setLoading(false); return; }
      const [penaltyRes, taskRes, driverRes, passengerRes] = await Promise.all([
        supabase.from("team_penalty_assignments")
          .select("id,assigned_at,paid_at,archived_season,team_penalty_rules(title,amount),teams(name)")
          .eq("membership_id", member.id).order("assigned_at", { ascending: false }),
        supabase.from("club_task_signups")
          .select("signed_up_at,club_tasks(title,due_date,teams(name))")
          .eq("membership_id", member.id).order("signed_up_at", { ascending: false }),
        supabase.from("carpools")
          .select("id,seats_available,note,departure,events(title,starts_at)")
          .eq("driver_membership_id", member.id).order("created_at", { ascending: false }),
        supabase.from("carpool_passengers")
          .select("joined_at,carpools(events(title,starts_at))")
          .eq("membership_id", member.id).order("joined_at", { ascending: false }),
      ]);
      if (penaltyRes.error || taskRes.error || driverRes.error || passengerRes.error) {
        setMessage("Einige Daten konnten nicht geladen werden.");
      }
      setPenalties((penaltyRes.data || []).map((row) => {
        const rule = Array.isArray(row.team_penalty_rules) ? row.team_penalty_rules[0] : row.team_penalty_rules;
        const team = Array.isArray(row.teams) ? row.teams[0] : row.teams;
        return { id: row.id, title: rule?.title || "—", amount: Number(rule?.amount || 0), teamName: team?.name, paidAt: row.paid_at, season: row.archived_season, assignedAt: row.assigned_at };
      }));
      setTasks((taskRes.data || []).map((row, i) => {
        const task = Array.isArray(row.club_tasks) ? row.club_tasks[0] : row.club_tasks;
        const team = task && (Array.isArray(task.teams) ? task.teams[0] : task.teams);
        return { id: i, title: task?.title || "—", dueDate: task?.due_date, teamName: team?.name, signedUpAt: row.signed_up_at };
      }));
      setCarpoolsAsDriver((driverRes.data || []).map((row) => {
        const event = Array.isArray(row.events) ? row.events[0] : row.events;
        return { id: row.id, seats: row.seats_available, departure: row.departure, note: row.note, eventTitle: event?.title, eventDate: event?.starts_at };
      }));
      setCarpoolsAsPassenger((passengerRes.data || []).map((row, i) => {
        const carpool = Array.isArray(row.carpools) ? row.carpools[0] : row.carpools;
        const event = carpool && (Array.isArray(carpool.events) ? carpool.events[0] : carpool.events);
        return { id: i, eventTitle: event?.title, eventDate: event?.starts_at, joinedAt: row.joined_at };
      }));
      setLoading(false);
    };
    load();
  }, [member.id]);
  const openPenalties = penalties.filter((p) => !p.season);
  const paidPenalties = openPenalties.filter((p) => p.paidAt);
  const unpaidPenalties = openPenalties.filter((p) => !p.paidAt);
  const historyPenalties = penalties.filter((p) => p.season);
  return (
    <div className="fixed inset-0 z-[60] flex items-end p-3" style={{ background: "rgba(20,21,26,.72)" }} onClick={onClose}>
      <div role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()} className="w-full rounded-3xl p-5 max-h-[85%] overflow-y-auto" style={{ background: C.glass }}>
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full flex items-center justify-center text-sm font-bold" style={{ background: member.color, color: C.white }}>{initialsOf(member.name)}</div>
            <div>
              <div className="text-lg font-bold" style={{ fontFamily: "Oswald", color: C.ink }}>{member.name}</div>
              <div className="text-xs" style={{ color: C.textDim }}>{member.email || "—"}</div>
            </div>
          </div>
          <button onClick={onClose} aria-label="Schließen" className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.paperDim }}><X size={15}/></button>
        </div>
        {message && <div className="text-[11px] mb-3" style={{ color: C.red }}>{message}</div>}
        {loading ? <div className="text-xs py-4" style={{ color: C.textDim }}>Wird geladen …</div> : <>
          <div className="text-[10px] uppercase tracking-widest font-bold mb-2" style={{ color: C.textDim }}>Strafen</div>
          {unpaidPenalties.length === 0 && paidPenalties.length === 0 ? <div className="text-[11px] rounded-xl p-3 mb-4" style={{ background: C.paperDim, color: C.textDim }}>Keine aktiven Strafen.</div> : (
            <div className="space-y-1.5 mb-4">
              {unpaidPenalties.map((p) => <div key={p.id} className="flex items-center justify-between px-3 py-2 rounded-xl" style={{ background: C.paperDim }}><span className="text-xs" style={{ color: C.ink }}>{p.title}{p.teamName ? ` · ${p.teamName}` : ""}</span><span className="text-xs font-bold" style={{ color: C.red, fontFamily: "JetBrains Mono" }}>{p.amount.toLocaleString("de-DE", { minimumFractionDigits: 2 })} € · offen</span></div>)}
              {paidPenalties.map((p) => <div key={p.id} className="flex items-center justify-between px-3 py-2 rounded-xl" style={{ background: C.paperDim }}><span className="text-xs" style={{ color: C.ink }}>{p.title}{p.teamName ? ` · ${p.teamName}` : ""}</span><span className="text-xs font-bold" style={{ color: C.secondary, fontFamily: "JetBrains Mono" }}>{p.amount.toLocaleString("de-DE", { minimumFractionDigits: 2 })} € · bezahlt</span></div>)}
            </div>
          )}
          {historyPenalties.length > 0 && (
            <div className="mb-4">
              <div className="text-[10px] uppercase tracking-widest font-bold mb-1.5" style={{ color: C.textDim }}>Strafen-Historie</div>
              <div className="space-y-1">
                {historyPenalties.map((p) => <div key={p.id} className="flex items-center justify-between px-3 py-1.5 rounded-lg text-[11px]" style={{ background: C.paperDim }}><span style={{ color: C.textDim }}>{p.title} · Saison {p.season}</span><span style={{ color: C.textDim, fontFamily: "JetBrains Mono" }}>{p.amount.toLocaleString("de-DE", { minimumFractionDigits: 2 })} €</span></div>)}
              </div>
            </div>
          )}
          <div className="text-[10px] uppercase tracking-widest font-bold mb-2" style={{ color: C.textDim }}>Aufgaben</div>
          {tasks.length === 0 ? <div className="text-[11px] rounded-xl p-3 mb-4" style={{ background: C.paperDim, color: C.textDim }}>Für keine Aufgabe eingetragen.</div> : (
            <div className="space-y-1.5 mb-4">
              {tasks.map((t) => <div key={t.id} className="px-3 py-2 rounded-xl" style={{ background: C.paperDim }}><div className="text-xs font-bold" style={{ color: C.ink }}>{t.title}</div><div className="text-[10px]" style={{ color: C.textDim }}>{t.teamName ? `${t.teamName} · ` : "Verein · "}{t.dueDate ? `Fällig bis ${new Date(t.dueDate).toLocaleDateString("de-DE")}` : "Kein Fälligkeitsdatum"}</div></div>)}
            </div>
          )}
          <div className="text-[10px] uppercase tracking-widest font-bold mb-2" style={{ color: C.textDim }}>Fahrgemeinschaften</div>
          {carpoolsAsDriver.length === 0 && carpoolsAsPassenger.length === 0 ? <div className="text-[11px] rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Keine Fahrgemeinschaften.</div> : (
            <div className="space-y-1.5">
              {carpoolsAsDriver.map((c) => <div key={`d-${c.id}`} className="px-3 py-2 rounded-xl" style={{ background: C.paperDim }}><div className="text-xs font-bold" style={{ color: C.ink }}>Fährt: {c.eventTitle || "—"}</div><div className="text-[10px]" style={{ color: C.textDim }}>{c.eventDate ? new Date(c.eventDate).toLocaleDateString("de-DE") : ""} · {c.seats} Plätze{c.note ? ` · ${c.note}` : ""}</div></div>)}
              {carpoolsAsPassenger.map((c) => <div key={`p-${c.id}`} className="px-3 py-2 rounded-xl" style={{ background: C.paperDim }}><div className="text-xs font-bold" style={{ color: C.ink }}>Mitfahrer: {c.eventTitle || "—"}</div><div className="text-[10px]" style={{ color: C.textDim }}>{c.eventDate ? new Date(c.eventDate).toLocaleDateString("de-DE") : ""}</div></div>)}
            </div>
          )}
        </>}
      </div>
    </div>
  );
}

function JoinRequestsManager({ currentUser }) {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [roleChoice, setRoleChoice] = useState({});
  const [busyId, setBusyId] = useState("");
  const ROLE_OPTIONS = ["mitglied", "spieler", "eltern", "trainer", "teammanager"];
  const loadRequests = async () => {
    setLoading(true); setMessage("");
    if (!supabase) { setLoading(false); return; }
    const { data, error } = await supabase.from("club_memberships")
      .select("id,display_name,email,requested_role,member_since,created_at")
      .eq("club_id", currentUser.clubId)
      .eq("status", "pending")
      .order("created_at", { ascending: true });
    if (error) { setMessage("Anfragen konnten nicht geladen werden."); setLoading(false); return; }
    setRequests(data || []);
    setLoading(false);
  };
  useEffect(() => { loadRequests(); }, [currentUser.clubId]);
  const respond = async (request, approve) => {
    setBusyId(request.id); setMessage("");
    const { error } = await supabase.rpc("respond_to_join_request", {
      target_membership: request.id,
      approve,
      granted_role: approve ? (roleChoice[request.id] || request.requested_role || "mitglied") : null,
    });
    if (error) { setMessage("Aktion konnte nicht ausgeführt werden."); setBusyId(""); return; }
    setRequests((current) => current.filter((r) => r.id !== request.id));
    setMessage(approve ? "Anfrage angenommen." : "Anfrage abgelehnt.");
    setBusyId("");
  };
  return <div>
    <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Neue Mitglieder, die deinem Verein beitreten möchten. Beim Annehmen legst du die finale Rolle fest.</div>
    {loading ? <div className="text-xs py-3" style={{ color: C.textDim }}>Wird geladen …</div> : requests.length === 0 ? <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Aktuell keine offenen Beitrittsanfragen.</div> : <div className="space-y-2">
      {requests.map((r) => <div key={r.id} className="rounded-2xl p-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
        <div className="text-xs font-bold mb-0.5" style={{ color: C.ink }}>{r.display_name}</div>
        <div className="text-[10px] mb-2" style={{ color: C.textDim }}>{r.email} · angefragte Rolle: {ROLE_META[r.requested_role]?.label || r.requested_role || "Mitglied"}</div>
        <select value={roleChoice[r.id] || r.requested_role || "mitglied"} onChange={(e) => setRoleChoice({ ...roleChoice, [r.id]: e.target.value })} className="w-full px-3 py-2 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim, color: C.ink }}>
          {ROLE_OPTIONS.map((role) => <option key={role} value={role}>{ROLE_META[role]?.label || role}</option>)}
        </select>
        <div className="flex gap-2">
          <button disabled={busyId === r.id} onClick={() => respond(r, false)} className="flex-1 py-2 rounded-xl text-xs font-bold" style={{ background: C.paperDim, color: C.red }}>Ablehnen</button>
          <button disabled={busyId === r.id} onClick={() => respond(r, true)} className="flex-1 py-2 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white }}>Annehmen</button>
        </div>
      </div>)}
    </div>}
    {message && <div role="status" className="text-[11px] mt-3" style={{ color: message.includes("angenommen") ? C.erfolg : C.fehler }}>{message}</div>}
  </div>;
}
function SysAdminUserManager({ members, setMembers }) {
  const [selectedId, setSelectedId] = useState("");
  const [section, setSection] = useState("overview");
  const [form, setForm] = useState({ name: "", email: "", birthdate: "", since: "", status: "active" });
  const [teams, setTeams] = useState([]);
  const [playerTeamIds, setPlayerTeamIds] = useState([]);
  const [savedPlayerTeamIds, setSavedPlayerTeamIds] = useState([]);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const selected = members.find((member) => member.id === selectedId);
  const databaseMembership = !!selected && !!supabase && isDbId(selected.id);

  useEffect(() => {
    if (!selected) return;
    setForm({ name: selected.name || "", email: selected.email || "", birthdate: selected.birthdate || "", since: String(selected.since || new Date().getFullYear()), status: selected.status || "active" });
    setSection("overview"); setMessage("");
  }, [selectedId]);

  useEffect(() => {
    if (!selected) { setTeams([]); return; }
    const load = async () => {
      let available = TEAMS.filter((name) => name !== "Eltern / Angehörige").map((name) => ({ id: name, name }));
      if (databaseMembership) {
        const { data, error } = await supabase.from("teams").select("id,name,category").eq("club_id", selected.clubId).eq("active", true).order("name");
        if (error) { setMessage("Die Mannschaften konnten nicht geladen werden."); return; }
        available = data || [];
      }
      const names = memberPlayerTeams(selected);
      const ids = available.filter((team) => names.includes(team.name)).map((team) => team.id);
      setTeams(available); setPlayerTeamIds(ids); setSavedPlayerTeamIds(ids);
    };
    load();
  }, [selectedId, databaseMembership]);

  const saveProfile = async () => {
    if (!selected || !form.name.trim()) { setMessage("Bitte einen Namen eingeben."); return; }
    setSaving(true); setMessage("");
    if (databaseMembership) {
      const { error } = await supabase.rpc("sysadmin_update_member_profile", {
        target_membership: selected.id,
        new_display_name: form.name.trim(),
        new_contact_email: form.email.trim() || null,
        new_birthdate: form.birthdate || null,
        new_member_since: Number(form.since),
        new_status: form.status,
      });
      if (error) { setMessage("Das Vereinsprofil konnte nicht gespeichert werden."); setSaving(false); return; }
    }
    setMembers((items) => items.map((member) => member.id === selected.id ? { ...member, name: form.name.trim(), email: form.email.trim(), birthdate: form.birthdate, since: Number(form.since), status: form.status } : member));
    setMessage("Vereinsprofil gespeichert."); setSaving(false);
  };
  const togglePlayerTeam = (teamId) => {
    setMessage("");
    setPlayerTeamIds((current) => current.includes(teamId) ? current.filter((id) => id !== teamId) : current.length < 3 ? [...current, teamId] : current);
  };
  const savePlayerTeams = async () => {
    if (!selected) return;
    setSaving(true); setMessage("");
    if (databaseMembership) {
      const { error } = await supabase.rpc("set_managed_player_teams", { target_club: selected.clubId, target_membership: selected.id, target_team_ids: playerTeamIds });
      if (error) { setMessage("Die Athleten-Mannschaften konnten nicht gespeichert werden."); setSaving(false); return; }
    }
    const names = teams.filter((team) => playerTeamIds.includes(team.id)).map((team) => team.name);
    setMembers((items) => items.map((member) => member.id === selected.id ? { ...member, playerTeams: names, team: hoechsteMannschaft(names) || "Mitglied", teams: [...new Set([...names, ...(member.trainerTeams || []), member.managedTeam].filter(Boolean))] } : member));
    setSavedPlayerTeamIds(playerTeamIds); setMessage("Athleten-Mannschaften gespeichert."); setSaving(false);
  };

  return <div>
    <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Als Sys-Admin kannst du die Vereinseinstellungen aller Nutzer bearbeiten. Login-E-Mail, Passwort und private Zahlungsdaten bleiben geschützt.</div>
    <select value={selectedId} onChange={(event) => setSelectedId(event.target.value)} className="w-full px-3 py-3 rounded-xl text-xs outline-none mb-4" style={{ background: C.glass, border: `1px solid ${C.line}`, color: C.ink }}><option value="">Nutzer auswählen …</option>{members.slice().sort((a, b) => a.name.localeCompare(b.name, "de")).map((member) => <option key={member.id} value={member.id}>{member.name} · {member.roles.map((role) => ROLE_META[role]?.label || role).join(", ")}</option>)}</select>
    {selected && <><div className="rounded-2xl p-4 mb-4 flex items-center gap-3" style={{ background: C.ink, color: C.white }}><div className="w-11 h-11 rounded-full flex items-center justify-center text-xs font-bold" style={{ background: selected.color }}>{initialsOf(selected.name)}</div><div className="min-w-0"><div className="text-base font-bold truncate" style={{ fontFamily: "Oswald" }}>{selected.name}</div><div className="text-[10px] truncate" style={{ color: C.textDim }}>{selected.email || "Profil ohne eigene E-Mail"}</div></div></div>
      <div className="grid grid-cols-2 gap-2 mb-4">{[["overview", "Stammdaten"], ["roles", "Rollen & Trainer"], ["teams", "Athleten-Teams"], ["family", "Familie"]].map(([id, label]) => <button key={id} onClick={() => { setSection(id); setMessage(""); }} className="py-2.5 rounded-xl text-[11px] font-bold" style={{ background: section === id ? C.ink : C.white, color: section === id ? C.white : C.textDim, border: `1px solid ${section === id ? C.ink : C.line}` }}>{label}</button>)}</div>
      {section === "overview" && <div className="rounded-2xl p-4 space-y-2" style={{ background: C.glass, border: `1px solid ${C.line}` }}><div className="text-sm font-bold mb-2" style={{ color: C.ink }}>Vereinsprofil bearbeiten</div><input value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} placeholder="Anzeigename" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}/><input type="email" value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} placeholder="Kontakt-E-Mail im Verein" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}/><div className="grid grid-cols-2 gap-2"><input type="date" value={form.birthdate} onChange={(event) => setForm({ ...form, birthdate: event.target.value })} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}/><input type="number" min="1800" max="2200" value={form.since} onChange={(event) => setForm({ ...form, since: event.target.value })} placeholder="Mitglied seit" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}/></div><select value={form.status} onChange={(event) => setForm({ ...form, status: event.target.value })} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}><option value="active">Aktiv</option><option value="pending">Ausstehend</option><option value="inactive">Inaktiv</option><option value="blocked">Gesperrt</option></select><button onClick={saveProfile} disabled={saving} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: C.red, color: C.white }}>{saving ? "Wird gespeichert …" : "Stammdaten speichern"}</button></div>}
      {section === "roles" && <RolesPanel members={[selected]} setMembers={setMembers}/>}
      {section === "teams" && <div className="rounded-2xl p-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>{!selected.roles.includes("spieler") ? <div className="text-xs" style={{ color: C.textDim }}>Vergib zuerst unter „Rollen & Trainer“ die Rolle Athlet/in.</div> : <><div className="flex items-center justify-between mb-2"><div className="text-sm font-bold">Athleten-Mannschaften</div><span className="text-[10px] font-bold" style={{ color: playerTeamIds.length === 3 ? C.red : C.textDim }}>{playerTeamIds.length}/3</span></div><div className="space-y-2 mb-3">{teams.map((team) => { const active = playerTeamIds.includes(team.id); return <button key={team.id} onClick={() => togglePlayerTeam(team.id)} className="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-left" style={{ background: active ? C.erfolgFlaeche : C.paperDim, border: active ? `1px solid ${C.secondary}` : "1px solid transparent" }}><span className="text-xs font-bold">{team.name}</span>{active && <Check size={14} style={{ color: C.erfolg }}/>}</button>; })}</div><button onClick={savePlayerTeams} disabled={saving || JSON.stringify([...playerTeamIds].sort()) === JSON.stringify([...savedPlayerTeamIds].sort())} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white, opacity: JSON.stringify([...playerTeamIds].sort()) === JSON.stringify([...savedPlayerTeamIds].sort()) ? .35 : 1 }}>{saving ? "Wird gespeichert …" : "Mannschaften speichern"}</button></>}</div>}
      {section === "family" && <><FamilyTree user={selected} members={members}/><div className="mt-3"><FamilyLinkManager user={selected} members={members} setMembers={setMembers} adminMode /></div></>}
      {message && <div role="status" className="text-[11px] mt-3 rounded-xl px-3 py-2" style={{ background: message.includes("gespeichert") ? C.erfolgFlaeche : C.fehlerFlaeche, color: message.includes("gespeichert") ? C.erfolg : C.fehler }}>{message}</div>}
    </>}
  </div>;
}

const inputStyle = { background: C.paperDim, color: C.ink };
function ProfileDataSettings({ user, setMembers, saveRef }) {
  const splitName = String(user.name || "").trim().split(/\s+/);
  const [form, setForm] = useState({
    membershipNumber: user.membershipNumber || "", academicTitle: user.academicTitle || "",
    firstName: user.firstName || splitName[0] || "", lastName: user.lastName || splitName.slice(1).join(" "),
    emails: user.contactEmails?.length ? user.contactEmails : [user.email || ""], phones: user.contactPhones?.length ? user.contactPhones : [user.phone || ""],
    birthdate: user.birthdate || "", gender: user.gender || "keine_angabe", nationality: user.nationality || "",
    showBirthday: user.showBirthday ?? true,
    street: user.street || "", postalCode: user.postalCode || "", city: user.city || "", countryCode: user.countryCode || "DE",
  });
  const [countryQuery, setCountryQuery] = useState("");
  const [message, setMessage] = useState("");
  const countryNames = React.useMemo(() => { const names = new Intl.DisplayNames(["de"], { type: "region" }); return COUNTRY_CODES.map((code) => ({ code, name: names.of(code) || code })).sort((a,b)=>a.name.localeCompare(b.name,"de")); }, []);
  const matches = countryNames.filter((item) => !countryQuery || item.name.toLowerCase().includes(countryQuery.toLowerCase()) || item.code.toLowerCase().startsWith(countryQuery.toLowerCase())).slice(0, 12);
  const save = async () => {
    if (!form.firstName.trim() || !form.lastName.trim()) { setMessage("Bitte Vor- und Nachname ausfüllen."); return; }
    const payload = { ...form, emails: form.emails.map((v)=>v.trim()).filter(Boolean), phones: form.phones.map((v)=>v.trim()).filter(Boolean) };
    if (supabase && user.authProfileId) {
      const { error } = await supabase.rpc("update_own_profile_settings", {
        target_membership:user.id, new_academic_title:payload.academicTitle||null, new_first_name:payload.firstName,
        new_last_name:payload.lastName, new_contact_emails:payload.emails, new_contact_phones:payload.phones,
        new_birthdate:payload.birthdate||null, new_gender:payload.gender, new_nationality:payload.nationality||null,
        new_street:payload.street||null, new_postal_code:payload.postalCode||null, new_city:payload.city||null,
        new_country_code:payload.countryCode||null, new_membership_number:payload.membershipNumber||null,
        new_notification_master:user.notificationMaster ?? true, new_notification_preferences:user.notificationPreferences || Object.fromEntries(NOTIFICATION_OPTIONS.map(([key])=>[key,true])),
        new_auto_logout_days:user.autoLogoutDays || null, new_calendar_sync_interval:user.calendarSyncInterval || "never",
        new_show_birthday: form.showBirthday,
      });
      if (error) { setMessage(error.message.includes("club_memberships_club_id_membership_number_key") ? "Diese Mitgliederausweisnummer wird bereits verwendet." : "Die Daten konnten nicht gespeichert werden."); return; }
    }
    const name = `${payload.firstName} ${payload.lastName}`.trim();
    setMembers((items)=>items.map((item)=>item.id===user.id?{...item,...payload,name,contactEmails:payload.emails,contactPhones:payload.phones}:item));
    setMessage("Persönliche Daten gespeichert.");
  };
  useEffect(() => { saveRef.current = save; });
  const updateList = (key,index,value) => setForm((old)=>({...old,[key]:old[key].map((v,i)=>i===index?value:v)}));
  const addList = (key) => setForm((old)=>({...old,[key]:[...old[key],""]}));
  const section = (title, children) => <div className="rounded-2xl p-4 mb-4 space-y-2" style={{background:C.glass,border:`1px solid ${C.line}`}}><div className="text-sm font-bold mb-2">{title}</div>{children}</div>;
  return <div>
    {message&&<div role="status" className="text-[11px] rounded-xl px-3 py-2 mb-4" style={{background:message.includes("gespeichert")?C.erfolgFlaeche:C.fehlerFlaeche,color:message.includes("gespeichert")?C.erfolg:C.fehler}}>{message}</div>}
    {section("Persönliche Daten", <><input value={form.membershipNumber} onChange={(e)=>setForm({...form,membershipNumber:e.target.value})} placeholder="Mitgliederausweisnummer" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/><input value={form.academicTitle} onChange={(e)=>setForm({...form,academicTitle:e.target.value})} placeholder="Akademischer Titel (optional)" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/><div className="grid grid-cols-2 gap-2"><input value={form.firstName} onChange={(e)=>setForm({...form,firstName:e.target.value})} placeholder="Vorname" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/><input value={form.lastName} onChange={(e)=>setForm({...form,lastName:e.target.value})} placeholder="Nachname" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/></div></>)}
    {section("Kontaktdaten", <><div className="text-[10px] font-bold" style={{color:C.textDim}}>E-Mail-Adressen</div>{form.emails.map((value,index)=><div key={`e-${index}`} className="flex gap-2"><input type="email" value={value} onChange={(e)=>updateList("emails",index,e.target.value)} placeholder="E-Mail-Adresse" className="flex-1 px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/>{index>0&&<button onClick={()=>setForm({...form,emails:form.emails.filter((_,i)=>i!==index)})}><X size={15}/></button>}</div>)}<button onClick={()=>addList("emails")} className="flex items-center gap-1 text-[11px] font-bold" style={{color:C.red}}><Plus size={13}/> Weitere E-Mail</button><div className="text-[10px] font-bold pt-2" style={{color:C.textDim}}>Telefonnummern</div>{form.phones.map((value,index)=><div key={`p-${index}`} className="flex gap-2"><input type="tel" value={value} onChange={(e)=>updateList("phones",index,e.target.value)} placeholder="Telefonnummer" className="flex-1 px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/>{index>0&&<button onClick={()=>setForm({...form,phones:form.phones.filter((_,i)=>i!==index)})}><X size={15}/></button>}</div>)}<button onClick={()=>addList("phones")} className="flex items-center gap-1 text-[11px] font-bold" style={{color:C.red}}><Plus size={13}/> Weitere Telefonnummer</button></>)}
    {section("Weitere Angaben", <><input type="date" value={form.birthdate} onChange={(e)=>setForm({...form,birthdate:e.target.value})} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/><label className="flex items-center justify-between gap-3 px-0.5 py-1"><span className="text-xs" style={{color:C.ink}}>Geburtstag im Verein anzeigen</span><button type="button" onClick={()=>setForm({...form,showBirthday:!form.showBirthday})} className="w-10 h-6 rounded-full flex items-center px-0.5" style={{background:form.showBirthday?C.secondary:C.line,justifyContent:form.showBirthday?"flex-end":"flex-start"}}><span className="w-5 h-5 rounded-full" style={{background:C.glass}}/></button></label><select value={form.gender} onChange={(e)=>setForm({...form,gender:e.target.value})} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}><option value="weiblich">Weiblich</option><option value="maennlich">Männlich</option><option value="divers">Divers</option><option value="keine_angabe">Keine Angabe</option></select><input value={form.nationality} onChange={(e)=>setForm({...form,nationality:e.target.value})} placeholder="Nationalität" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/></>)}
    {section("Adresse", <><input value={form.street} onChange={(e)=>setForm({...form,street:e.target.value})} placeholder="Straße und Hausnummer" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/><div className="grid grid-cols-2 gap-2"><input value={form.postalCode} onChange={(e)=>setForm({...form,postalCode:e.target.value})} placeholder="PLZ" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/><input value={form.city} onChange={(e)=>setForm({...form,city:e.target.value})} placeholder="Stadt" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/></div><div className="relative"><input value={countryQuery || countryNames.find((c)=>c.code===form.countryCode)?.name || form.countryCode} onChange={(e)=>setCountryQuery(e.target.value)} onFocus={()=>setCountryQuery("")} placeholder="Land suchen …" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={inputStyle}/>{countryQuery&&<div className="absolute z-10 left-0 right-0 top-full mt-1 rounded-xl overflow-hidden shadow-xl" style={{background:C.glass,border:`1px solid ${C.line}`}}>{matches.map((item)=><button key={item.code} onClick={()=>{setForm({...form,countryCode:item.code});setCountryQuery("");}} className="w-full px-3 py-2 text-left text-xs hover:bg-gray-50">{item.name} <span style={{color:C.textDim}}>({item.code})</span></button>)}</div>}</div></>)}
  </div>;
}

function NotificationSettings({ user, setMembers, saveRef }) {
  const defaults = Object.fromEntries(NOTIFICATION_OPTIONS.map(([key])=>[key,true]));
  const [master,setMaster] = useState(user.notificationMaster ?? true);
  const [prefs,setPrefs] = useState({...defaults,...(user.notificationPreferences||{})});
  const [message,setMessage]=useState("");
  const [pushStatus,setPushStatus]=useState("idle");
  const databaseMembership = !!supabase && isDbId(user.id);
  const activatePush = async () => {
    setPushStatus("working");
    const result = await enablePushNotifications(user.id);
    if (result.error) {
      const messages = { unsupported: "Push wird auf diesem Gerät/Browser nicht unterstützt.", denied: "Berechtigung wurde nicht erteilt.", save_failed: "Token konnte nicht gespeichert werden.", setup_failed: "Push konnte nicht eingerichtet werden.", no_token: "Kein Push-Token erhalten.", not_browser: "Nur im Browser verfügbar." };
      setPushStatus("error"); setMessage(messages[result.error] || "Push konnte nicht aktiviert werden."); return;
    }
    setPushStatus("active"); setMessage("Push-Benachrichtigungen sind jetzt aktiv.");
  };
  const deactivatePush = async () => {
    setPushStatus("working");
    const result = await disablePushNotifications(user.id);
    if (result.error) { setPushStatus("active"); setMessage("Push konnte nicht deaktiviert werden."); return; }
    setPushStatus("idle"); setMessage("Push-Benachrichtigungen wurden deaktiviert.");
  };
  const save = async()=>{ if(supabase&&user.authProfileId){const {error}=await supabase.from("profiles").update({notification_master:master,notification_preferences:prefs}).eq("id",user.authProfileId);if(error){setMessage("Benachrichtigungen konnten nicht gespeichert werden.");return;}} setMembers((items)=>items.map((item)=>item.id===user.id?{...item,notificationMaster:master,notificationPreferences:prefs}:item));setMessage("Benachrichtigungen gespeichert.");};
  useEffect(() => { saveRef.current = save; });
  return <div>{message&&<div className="mb-4 text-[11px] rounded-xl px-3 py-2" style={{background:C.erfolgFlaeche,color:C.erfolg}}>{message}</div>}{/* Die Push-Karte erscheint nur ausserhalb der nativen App. In der
      nativen Huelle laeuft die Oberflaeche in einem WKWebView, und dort gibt es
      weder Notification noch serviceWorker - enablePushNotifications kehrte
      sofort mit "unsupported" zurueck. Der Knopf oeffnete also nie einen
      Berechtigungsdialog, sondern zeigte zuverlaessig eine Fehlermeldung.
      Der erklaerende Satz verwies zudem auf "Zum Home-Bildschirm hinzufuegen",
      also auf eine Installation ausserhalb des App Store - mitten in der
      App-Store-App. Benachrichtigungen innerhalb der App sind davon unberuehrt,
      die laufen ueber die Datenbank. */}
    {databaseMembership && !Capacitor.isNativePlatform() && <div className="rounded-2xl p-4 mb-4" style={{background:C.glass,border:`1px solid ${C.line}`}}><div className="text-sm font-bold mb-1" style={{color:C.ink}}>Push-Benachrichtigungen auf diesem Gerät</div><div className="text-[11px] mb-3" style={{color:C.textDim}}>Aktiviere Push, um Benachrichtigungen auch außerhalb der App zu erhalten.</div><button onClick={pushStatus==="active"?deactivatePush:activatePush} disabled={pushStatus==="working"} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{background:pushStatus==="active"?C.fehlerFlaeche:C.ink,color:pushStatus==="active"?C.red:C.white}}>{pushStatus==="working"?"Wird bearbeitet …":pushStatus==="active"?"Push deaktivieren":"Push aktivieren"}</button></div>}<ToggleCard title="Benachrichtigungen auf diesem Gerät" desc="Master-Schalter für alle App-Benachrichtigungen" value={master} onChange={setMaster}/><div className="mt-4 rounded-2xl p-4space-y-3" style={{background:C.glass,border:`1px solid ${C.line}`}}>{NOTIFICATION_OPTIONS.filter(([key])=>BEITRAGSVERWALTUNG_SICHTBAR||key!=="payments").map(([key,label])=><label key={key} className="flex items-center justify-between gap-3"><span className="text-xsfont-bold">{label}</span><select disabled={!master} value={prefs[key]?"ja":"nein"} onChange={(e)=>setPrefs({...prefs,[key]:e.target.value==="ja"})} className="px-3 py-2 rounded-xl text-xs" style={{background:C.paperDim,opacity:master?1:.45}}><option value="ja">Ja</option><option value="nein">Nein</option></select></label>)}</div></div>;
}

function PasswordSettings({ user, onLogout, saveRef }) {
  const [form,setForm]=useState({old:"",next:"",repeat:"",logoutAll:false}); const [message,setMessage]=useState("");
  const save=async()=>{if(!supabase){setMessage("Passwortänderung ist nur mit einem echten Konto möglich.");return;}if(form.next.length<8||form.next!==form.repeat){setMessage("Das neue Passwort muss mindestens 8 Zeichen haben und übereinstimmen.");return;}const {error:loginError}=await supabase.auth.signInWithPassword({email:user.email,password:form.old});if(loginError){/* Nur der Fall "Passwort stimmt nicht" darf so heissen. Ein Netzfehler oder eine Bremse wegen zu vieler Versuche haben nichts mit dem alten Passwort zu tun; hier ist die Verwechslung besonders aergerlich, weil man dann das eine Passwort sucht, das man sicher kennt. Eine Preisgabe ist das nicht: Wer hier steht, ist bereits angemeldet und kennt seine eigene Adresse. */const falschesPasswort=loginError.code==="invalid_credentials"||/invalid login credentials/i.test(String(loginError.message||""));/* Hier darf die Sperre beim Namen genannt werden: Wer bis hierher kommt, ist angemeldet und kennt seine eigene Adresse - es gibt nichts zu verraten. */const gesperrt=loginError.code==="user_banned"||/user is banned/i.test(String(loginError.message||""));setMessage(gesperrt?"Dieses Konto ist gesperrt. Bitte wende dich an die Vereinsleitung.":falschesPasswort?"Das bisherige Passwort ist nicht korrekt.":anmeldeFehlerText(loginError));return;}const {error}=await supabase.auth.updateUser({password:form.next});if(error){const zuSchwach=error.code==="weak_password"||/password/i.test(String(error.message||""))&&/short|weak|least/i.test(String(error.message||""));setMessage(zuSchwach?"Das neue Passwort ist zu schwach. Nimm ein längeres oder ungewöhnlicheres.":"Das Passwort konnte nicht geändert werden. "+anmeldeFehlerText(error));return;}if(form.logoutAll){await supabase.auth.signOut({scope:"global"});await onLogout();return;}setForm({old:"",next:"",repeat:"",logoutAll:false});setMessage("Passwort erfolgreich geändert.");}; useEffect(() => { saveRef.current = save; });
  return <div className="rounded-2xl p-4 space-y-3" style={{background:C.glass,border:`1px solid ${C.line}`}}><input type="password" value={form.old} onChange={(e)=>setForm({...form,old:e.target.value})} placeholder="Altes Passwort" className="w-full px-3 py-3 rounded-xl text-xs" style={inputStyle}/><input type="password" value={form.next} onChange={(e)=>setForm({...form,next:e.target.value})} placeholder="Neues Passwort" className="w-full px-3 py-3 rounded-xl text-xs" style={inputStyle}/><input type="password" value={form.repeat} onChange={(e)=>setForm({...form,repeat:e.target.value})} placeholder="Neues Passwort wiederholen" className="w-full px-3 py-3 rounded-xl text-xs" style={inputStyle}/><ToggleCard title="Von allen Geräten ausloggen" desc="Nach der Änderung werden alle bestehenden Sitzungen beendet." value={form.logoutAll} onChange={(v)=>setForm((old)=>({...old,logoutAll:typeof v==="function"?v(old.logoutAll):v}))}/>{message&&<div className="text-[11px]" style={{color:message.includes("erfolgreich")?C.erfolg:C.fehler}}>{message}</div>}</div>;
}

function SecuritySettings({user,setMembers,saveRef}) { const [days,setDays]=useState(user.autoLogoutDays??"");const [message,setMessage]=useState("");const save=async()=>{const value=days===""?null:Number(days);if(supabase&&user.authProfileId){const {error}=await supabase.from("profiles").update({auto_logout_days:value}).eq("id",user.authProfileId);if(error){setMessage("Einstellung konnte nicht gespeichert werden.");return;}}setMembers((items)=>items.map((item)=>item.id===user.id?{...item,autoLogoutDays:value}:item));localStorage.setItem(`cmo-last-activity-${user.authProfileId||user.id}`,String(Date.now()));setMessage("Sicherheitseinstellung gespeichert.");};useEffect(() => { saveRef.current = save; });return <div className="rounded-2xl p-4" style={{background:C.glass,border:`1px solid ${C.line}`}}><div className="text-sm font-bold mb-1">Automatischer Logout</div><div className="text-[11px] mb-3" style={{color:C.textDim}}>Nach längerer Inaktivität wird dieses Konto automatisch abgemeldet.</div><select value={days} onChange={(e)=>setDays(e.target.value)} className="w-full px-3 py-3 rounded-xl text-xs" style={inputStyle}><option value="">Nie</option><option value="30">Nach 30 Tagen</option><option value="60">Nach 60 Tagen</option><option value="90">Nach 90 Tagen</option></select>{message&&<div className="text-[11px] mt-3" style={{color:C.secondary}}>{message}</div>}</div>; }

function ReferralSettings({user,club}) { const [code,setCode]=useState("");const [used,setUsed]=useState(false);const [loading,setLoading]=useState(false);useEffect(()=>{if(!supabase||!club?.id||!user.authProfileId)return;supabase.from("club_referral_codes").select("code,redeemed_at").eq("club_id",club.id).eq("profile_id",user.authProfileId).maybeSingle().then(({data})=>{setCode(data?.code||"");setUsed(Boolean(data?.redeemed_at));});},[club?.id,user.authProfileId]);const create=async()=>{setLoading(true);const {data,error}=await supabase.rpc("ensure_club_referral_code",{target_club:club.id});if(!error)setCode(data);setLoading(false);};if(used&&!user.roles.includes("sysadmin"))return <div className="rounded-2xl p-4 text-xs" style={{background:C.paperDim,color:C.textDim}}>Dein persönlicher Empfehlungscode wurde bereits einmal verwendet. Die drei kostenlosen Vereinsmonate werden automatisch berücksichtigt.</div>;return <div className="rounded-2xl p-4" style={{background:C.glass,border:`1px solid ${C.line}`}}><div className="text-sm font-bold mb-1">Vereine werben Vereine</div><div className="text-[11px] mb-4" style={{color:C.textDim}}>Wirbst du einmalig einen neuen Verein, erhält dein aktueller Verein drei kostenlose Monate. Der neue Verein gibt deinen persönlichen Code bei seiner Registrierung ein.</div>{code?<><div className="rounded-xl px-3 py-3 text-center font-bold tracking-wider" style={{background:C.paperDim}}>{code}</div><button onClick={()=>navigator.clipboard?.writeText(code)} className="w-full mt-2 py-2 text-xs font-bold" style={{color:C.red}}>Code kopieren</button></>:<button disabled={loading} onClick={create} className="w-full py-3 rounded-xl text-xs font-bold" style={{background:C.ink,color:C.white}}>{loading?"Wird erstellt …":"Persönlichen Code erstellen"}</button>}</div>; }

/* Die Store-Links koennen erst nach der Veroeffentlichung existieren. Vorher
   wurden beide Zeilen trotzdem angezeigt - als Kacheln mit Pfeilsymbol, die beim
   Antippen nichts taten (href="#" mit preventDefault). Ausgerechnet bei der
   ERSTEN Pruefung sind sie zwangslaeufig beide leer, der Pruefer trifft also
   garantiert auf zwei tote Bedienelemente.
   Jetzt erscheint nur, was auch wirklich irgendwohin fuehrt; fehlen beide,
   steht dort nur der erklaerende Satz. */
function FeedbackSettings() { const apple=process.env.NEXT_PUBLIC_APP_STORE_REVIEW_URL;const google=process.env.NEXT_PUBLIC_PLAY_STORE_REVIEW_URL;const stores=[[apple,"Im Apple App Store bewerten"],[google,"Im Google Play Store bewerten"]].filter(([url])=>!!url);return <div><div className="text-[11px] mb-4" style={{color:C.textDim}}>{stores.length?"Danke, dass du CMO bewertest. Wähle den Store deines Geräts.":"Danke, dass du CMO bewerten möchtest."}</div>{stores.length>0&&<div className="space-y-2">{stores.map(([url,label])=><a key={label} href={url} target="_blank" rel="noreferrer" className="flex items-center justify-between px-4 py-3 rounded-2xl text-xs font-bold" style={{background:C.glass,border:`1px solid ${C.line}`,color:C.ink}}>{label}<ExternalLink size={14}/></a>)}</div>}{stores.length===0&&<div className="text-[11px] rounded-2xl p-4" style={{background:C.paperDim,color:C.textDim}}>Die Bewertungslinks werden freigeschaltet, sobald die App im jeweiligen Store verfügbar ist.</div>}</div>; }

function BugReportSettings({user}) { const [busy,setBusy]=useState(false);const report=async()=>{setBusy(true);let number=`CMO-${new Date().getFullYear()}-${Date.now().toString().slice(-6)}`;if(supabase&&user.authProfileId){const {data}=await supabase.rpc("create_support_ticket",{target_club:user.clubId});if(data)number=data;}const subject=encodeURIComponent(`Fehlermeldung - CMO App #${number}`);const body=encodeURIComponent(`Hallo CMO-Team,\n\nfolgender Fehler ist aufgetreten:\n\n\nApp-Ticket: ${number}\nNutzer: ${user.name}\n`);window.location.href=`mailto:info@idbranding.de?subject=${subject}&body=${body}`;setBusy(false);};return <div className="rounded-2xl p-4" style={{background:C.glass,border:`1px solid ${C.line}`}}><div className="text-[11px] mb-4" style={{color:C.textDim}}>Wir erzeugen eine eindeutige Bearbeitungsnummer und öffnen anschließend die E-Mail-App deines Geräts.</div><button onClick={report} disabled={busy} className="w-full py-3 rounded-xl text-xs font-bold" style={{background:C.red,color:C.white}}>{busy?"Nummer wird erstellt …":"Fehler per E-Mail melden"}</button></div>; }

/* Kalender-Abo. Vor dem Abonnieren wird ausgewählt, welche Terminarten in den
   privaten Gerätekalender übertragen werden — jede Person plant anders, und ein
   Elternteil will selten jedes Training aller Mannschaften im eigenen Kalender.
   Die Auswahl wird am Abonnement gespeichert, nicht an die Adresse gehängt:
   Der Gerätekalender ruft dieselbe Adresse dauerhaft ab, eine Änderung wirkt
   deshalb beim nächsten Abruf ohne erneutes Einrichten im Gerät. */
const CALENDAR_EVENT_TYPES = [
  { key: "training", label: "Trainings", hint: "Deine Trainingseinheiten" },
  { key: "spiel", label: "Spiele", hint: "Spiele deiner Mannschaften" },
  { key: "event", label: "Events", hint: "Vereinstermine und Feiern" },
];

function CalendarSyncSettings({ user, saveRef }) {
  const [interval, setInterval] = useState(user.calendarSyncInterval || "never");
  const [types, setTypes] = useState(["training", "spiel", "event"]);
  /* Leere Auswahl heisst "meine Mannschaften" - genau das bisherige Verhalten.
     Wer ausdruecklich waehlt, bekommt die gewaehlten, auch solche, in denen er
     selbst nicht steht. */
  const [teams, setTeams] = useState([]);
  const [alleTeams, setAlleTeams] = useState([]);
  const [token, setToken] = useState("");
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);

  /* Zuletzt gespeicherte Auswahl laden, damit die Haken den tatsächlichen
     Stand zeigen und nicht bei jedem Öffnen auf „alles" zurückspringen. */
  useEffect(() => {
    if (!supabase || !isDbId(user.clubId)) return;
    supabase.rpc("my_calendar_subscription", { target_club: user.clubId }).then(({ data }) => {
      const row = data?.[0];
      if (!row) return;
      setToken(row.token || "");
      setInterval(row.sync_interval || "never");
      if (Array.isArray(row.event_types) && row.event_types.length) setTypes(row.event_types);
      if (Array.isArray(row.team_ids)) setTeams(row.team_ids);
    });
    supabase.from("teams").select("id,name").eq("club_id", user.clubId).order("name")
      .then(({ data }) => setAlleTeams(data || []))
      .catch(() => setAlleTeams([]));
  }, [user.clubId]);

  const toggleTeam = (id) => {
    setMessage("");
    setTeams((current) => current.includes(id) ? current.filter((entry) => entry !== id) : [...current, id]);
  };

  const toggleType = (key) => {
    setMessage("");
    setTypes((current) => current.includes(key) ? current.filter((entry) => entry !== key) : [...current, key]);
  };

  const sync = async () => {
    if (!supabase) { setMessage("Kalendersynchronisierung benötigt ein echtes Konto."); return; }
    if (!types.length) { setMessage("Bitte wähle mindestens eine Terminart aus."); return; }
    setSaving(true);
    const { data, error } = await supabase.rpc("configure_calendar_subscription", {
      target_club: user.clubId,
      requested_interval: interval,
      requested_types: types,
      requested_teams: teams,
    });
    setSaving(false);
    if (error) { setMessage("Kalender konnte nicht verbunden werden."); return; }
    const row = data?.[0];
    setToken(row?.token || "");
    setMessage("Kalenderverbindung aktualisiert.");
  };
  useEffect(() => { saveRef.current = sync; });

  const url = token && `${window.location.origin}/api/calendar/feed/${token}`;
  const selectedLabel = CALENDAR_EVENT_TYPES.filter((entry) => types.includes(entry.key)).map((entry) => entry.label).join(", ");

  return <div>
    <div className="rounded-2xl p-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
      <div className="text-sm font-bold mb-1" style={{ color: C.ink }}>Termine abonnieren</div>
      <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Wähle aus, was in deinem privaten Gerätekalender erscheinen soll. Übertragen wird nur, was du ohnehin sehen darfst.</div>

      <div className="space-y-2 mb-3">
        {CALENDAR_EVENT_TYPES.map((entry) => {
          const active = types.includes(entry.key);
          return (
            <button key={entry.key} onClick={() => toggleType(entry.key)} aria-pressed={active} className="w-full flex items-center gap-3 rounded-xl px-3 py-2.5 text-left" style={{ background: active ? C.erfolgFlaeche : C.paperDim, border: `1px solid ${active ? C.secondary : "transparent"}` }}>
              <span className="w-5 h-5 rounded-md flex items-center justify-center flex-shrink-0" style={{ background: active ? C.secondary : "transparent", border: `1px solid ${active ? C.secondary : C.line}` }}>
                {active && <Check size={13} style={{ color: C.white }} />}
              </span>
              <span className="flex-1 min-w-0">
                <span className="block text-xs font-bold" style={{ color: C.ink }}>{entry.label}</span>
                <span className="block text-[10px]" style={{ color: C.textDim }}>{entry.hint}</span>
              </span>
            </button>
          );
        })}
      </div>
      {!types.length && <div className="text-[11px] rounded-xl px-3 py-2 mb-3" style={{ background: C.sekundaerWeich, color: C.textDim }}>Ohne Auswahl bliebe der Kalender leer — wähle mindestens eine Art.</div>}

      {alleTeams.length > 0 && <>
        <div className="text-[10px] font-bold uppercase tracking-widest mb-1.5" style={{ color: C.textDim }}>Mannschaften</div>
        <div className="text-[10px] mb-2 leading-snug" style={{ color: C.textDim }}>
          {teams.length === 0
            ? "Ohne Auswahl kommen die Mannschaften, in denen du oder deine Kinder stehen — dazu alle vereinsweiten Termine."
            : "Nur die gewählten Mannschaften, dazu alle vereinsweiten Termine."}
        </div>
        <div className="space-y-1.5 mb-3">
          {alleTeams.map((mannschaft) => {
            const active = teams.includes(mannschaft.id);
            return (
              <button key={mannschaft.id} onClick={() => toggleTeam(mannschaft.id)} aria-pressed={active} className="w-full flex items-center gap-3 rounded-xl px-3 py-2.5 text-left" style={{ background: active ? C.erfolgFlaeche : C.paperDim, border: `1px solid ${active ? C.erfolgRand : "transparent"}` }}>
                <span className="w-5 h-5 rounded-md flex items-center justify-center flex-shrink-0" style={{ background: active ? C.secondary : "transparent", border: `1px solid ${active ? C.secondary : C.edge}` }}>
                  {active && <Check size={13} style={{ color: C.white }} />}
                </span>
                <span className="text-xs font-bold" style={{ color: C.ink }}>{mannschaft.name}</span>
              </button>
            );
          })}
          {teams.length > 0 && <button onClick={() => { setTeams([]); setMessage(""); }} className="w-full py-2 rounded-xl text-[11px] font-bold" style={{ background: C.glass, color: C.textDim }}>Auswahl aufheben — meine Mannschaften verwenden</button>}
        </div>
      </>}

      <div className="text-[10px] font-bold uppercase tracking-widest mb-1.5" style={{ color: C.textDim }}>Aktualisierung</div>
      <select value={interval} onChange={(e) => setInterval(e.target.value)} className="w-full px-3 py-3 rounded-xl text-xs mb-3" style={inputStyle}>
        <option value="never">Nie automatisch</option>
        <option value="daily">Täglich</option>
        <option value="weekly">Wöchentlich · Sonntagabend</option>
        <option value="monthly">Monatlich</option>
      </select>

      <button onClick={sync} disabled={saving || !types.length} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-xs font-bold" style={{ background: C.ink, color: C.white, opacity: saving || !types.length ? .5 : 1 }}><RefreshCw size={14}/> {saving ? "Wird gespeichert …" : token ? "Auswahl übernehmen" : "Abonnement erstellen"}</button>

      {url && <>
        <a href={url.replace(/^https?:/, "webcal:")} className="block w-full text-center mt-2 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.erfolgFlaeche, color: C.erfolg }}>Mit Gerätekalender verbinden</a>
        <div className="text-[10px] mt-2 leading-snug" style={{ color: C.textDim }}>Abonniert: {selectedLabel || "nichts"}. Änderst du die Auswahl, übernimmt dein Gerätekalender sie beim nächsten Abruf — ohne erneutes Einrichten.</div>
      </>}
    </div>
    {message && <div role="status" className="text-[11px] mt-3" style={{ color: message.includes("aktualisiert") ? C.erfolg : C.fehler }}>{message}</div>}
  </div>;
}

function ProfileView({ user, members, setMembers, currentClub, dutyPlan, punkteZiel, punktePraemie, werbeplaetze, onSponsorImpression, onSponsorClick, onLogout, clubFeatures, onClubFeaturesChanged, entitlement, goSubscribe, dashboardTileOrder, setDashboardTileOrder, ziel, onZielErreicht }) {
  const featureEnabled = (key) => clubFeatures[key] !== false;
  /* Ziel und Praemie legt der VEREIN fest, nicht die App. Ohne Eintrag steht
     kein Versprechen da - vorher verpflichtete die App jeden Verein zu einem
     kostenlosen Hoodie, von dem dort niemand wusste. */
  const goal = punkteZiel || 1000;
  const meinePunkte = user.points || 0;
  const meineBadges = verdienteBadges(user, dutyPlan);
  const eligible = isFormalMember(user) && age(user.birthdate) >= 16;
  const vorhandeneVideos = useVorhandeneHowToVideos();
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [profileUnderlay, setProfileUnderlay] = useState("");
  const [profileFolder, setProfileFolder] = useState("");
  const [referralAlreadyUsed, setReferralAlreadyUsed] = useState(false);
  const sectionSaveRef = useRef(null);
  /* Beim Wechsel des Bereichs wird die Referenz geleert.
     Sie zeigt auf die Speichern-Funktion des GERADE offenen Bereichs. Jeder
     Bereich setzt sie beim Einhaengen - aber niemand raeumte sie beim
     Verlassen auf. Wer also "Persoenliche Daten" oeffnete und dann
     "Kalender synchronisieren", konnte in dem kurzen Moment, bevor der neue
     Bereich stand, mit Speichern die Funktion des alten ausloesen: Ein Klick
     auf "Kalender speichern" schrieb die persoenlichen Daten.
     null heisst "noch keine Funktion da" - der Aufruf ist mit ?.() gesichert
     und tut dann schlicht nichts, statt das Falsche zu tun.
     Geraeumt wird in der AUFRAEUMFUNKTION, nicht im Effektkoerper: React
     fuehrt Effekte von innen nach aussen aus. Stuende die Zuweisung im
     Koerper, setzte der Bereich die Referenz und dieser Effekt loeschte sie
     unmittelbar danach wieder - sie waere dauerhaft leer. Aufraeumfunktionen
     laufen dagegen VOR den neuen Effekten. */
  useEffect(() => () => { sectionSaveRef.current = null; }, [profileUnderlay]);

  /* Kommt jemand ueber "Abo ansehen", steht das Ziel schon fest: Der
     Kaufbereich soll offen sein, nicht die Uebersicht. Der Wunsch wird
     eingeloest und sofort zurueckgesetzt - sonst spraenge das Profil bei jedem
     spaeteren Besuch wieder dorthin. */
  useEffect(() => {
    if (!ziel) return;
    setProfileFolder(ziel);
    onZielErreicht?.();
  }, [ziel]);
  useEffect(() => {
    if (!supabase || !currentClub?.id || !user.authProfileId) return;
    supabase.from("club_referral_codes").select("redeemed_at").eq("club_id", currentClub.id).eq("profile_id", user.authProfileId).maybeSingle()
      .then(({ data }) => setReferralAlreadyUsed(Boolean(data?.redeemed_at)));
  }, [currentClub?.id, user.authProfileId]);
  const deleteAccount = async () => {
    if (!supabase) { setDeleteError("Im Demo-Modus kann kein echtes Konto gelöscht werden."); return; }
    setDeleting(true); setDeleteError("");
    const { data } = await supabase.auth.getSession();
    const token = data.session?.access_token;
    if (!token) { setDeleteError("Bitte melde dich erneut an."); setDeleting(false); return; }
    const response = await fetch("/api/account/delete", { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
    if (!response.ok) { setDeleteError("Das Konto konnte nicht vollständig gelöscht werden. Bitte kontaktiere den Support."); setDeleting(false); return; }
    await onLogout();
  };
  return (
    <div className="px-4 pt-4 pb-24">
      <SectionTitle title="Profil" />
      <div className="rounded-2xl p-5 mb-5 flex items-center gap-4" style={{ background: `linear-gradient(150deg, ${C.ink}, ${C.asphalt})` }}>
        <div className="w-16 h-16 rounded-full flex items-center justify-center text-xl flex-shrink-0" style={{ background: user.color, color: "#fff", fontFamily: "Oswald", fontWeight: 700 }}>{initialsOf(user.name)}</div>
        <div>
          <div className="text-white text-lg" style={{ fontFamily: "Oswald", fontWeight: 700 }}>{user.name}</div>
          {/* Im eigenen Profil stand nur user.team - also eine von womoeglich
              mehreren Mannschaften. Wer in Herren 1 und Herren 2 spielt, sah
              seine zweite Mannschaft nirgends. Hier gehoeren alle hin, nach
              Rang geordnet. */}
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>{nachRangSortiert(memberAllTeams(user)).join(" · ") || user.team}{user.number ? ` · Rückennummer ${user.number}` : ""}</div>
          <div className="text-xs mt-0.5 mb-2" style={{ color: C.textDim, fontFamily: "Inter" }}>Dabei seit {user.since} · {age(user.birthdate)} Jahre</div>
          <div className="flex flex-wrap gap-1.5">
            {user.roles.map((r) => <Pill key={r} bg={ROLE_META[r].color}>{ROLE_META[r].label}</Pill>)}
          </div>
        </div>
      </div>

      {isAdmin(user) && (
        <>
          <SectionTitle eyebrow="Verein verwalten" title="Vereinseinstellungen" />
          <div className="space-y-2 mb-6">
            <ProfileSettingsCard icon={Settings} title="Vereinseinstellungen" description="Funktionen wie Fahrzeugbuchung, Tippspiel & Athlet/in der Saison ein- oder ausblenden" color={C.red} onClick={() => setProfileFolder("clubsettings")}/>
          </div>
        </>
      )}

      <SectionTitle eyebrow="Verwalten" title="Einstellungen" />
      <div className="space-y-2 mb-6">
        <ProfileSettingsCard icon={User} title="Persönliche Daten" description="Stammdaten, Kontakte, Familie" color={C.secondary} onClick={() => setProfileFolder("personal")}/>
        <ProfileSettingsCard icon={KeyRound} title="Konto & Sicherheit" description="Passwort, Sicherheit, Rechtliches, Account" color={AVATAR_FARBEN[2]} onClick={() => setProfileFolder("security")}/>
        <ProfileSettingsCard icon={Trophy} title="Verein & Mitgliedschaft" description="Athleten-, Trainer- und Vereinsrollen" color={C.red} onClick={() => setProfileFolder("club")}/>
        <ProfileSettingsCard icon={Bell} title="Benachrichtigungen & Kalender" description="Push-Einstellungen und Kalendersync" color={C.secondary} onClick={() => setProfileFolder("notify")}/>
        <ProfileSettingsCard icon={Euro} title="Zugang & Empfehlungen" description="Freischaltung des Vereins und Vereine werben Vereine" color={C.red} onClick={() => setProfileFolder("billing")}/>
        <ProfileSettingsCard icon={Star} title="Support & Feedback" description="Bewertung abgeben, Fehler melden" color={C.textDim} onClick={() => setProfileFolder("support")}/>
        {vorhandeneVideos.length > 0 && <ProfileSettingsCard icon={PlayCircle} title="App kennenlernen" description="Kurzvideos zu den Funktionen, die du nutzen kannst" color={C.secondary} onClick={() => setProfileFolder("howto")}/>}
        {/* Direkter Weg zur Kontolöschung. Vorher lag sie drei Overlay-Ebenen tief
            und keine der Zwischenkacheln trug das Wort „löschen" — ein Prüfer, der
            unserer eigenen Anleitung („Profil → Verwalten → Konto löschen") folgt,
            hätte die Funktion nicht gefunden und als fehlend gemeldet. */}
        <ProfileSettingsCard icon={Trash2} title="Konto löschen" description="Konto und persönliche Daten dauerhaft entfernen" color={C.red} onClick={() => setProfileUnderlay("account-delete")}/>
      </div>

      {profileFolder === "clubsettings" && isAdmin(user) && <ProfileUnderlay title="Vereinseinstellungen" eyebrow="Verein verwalten" onClose={() => setProfileFolder("")}>
        <ClubRoleOverviewPanel members={members} />
        <ClubFeatureSettingsPanel currentClub={currentClub} clubFeatures={clubFeatures} onFeaturesChanged={onClubFeaturesChanged} dashboardTileOrder={dashboardTileOrder} setDashboardTileOrder={setDashboardTileOrder} />
      </ProfileUnderlay>}

      {profileFolder === "personal" && <ProfileUnderlay title="Persönliche Daten" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={User} title="Persönliche Daten" description="Stammdaten, Kontakte, Adresse und Mitgliederausweis" color={C.secondary} onClick={() => setProfileUnderlay("personal")}/>
          <ProfileSettingsCard icon={Users} title="Familie" description="Familienprofile ansehen und Verknüpfungen verwalten" color={C.secondary} onClick={() => setProfileUnderlay("family")}/>
        </div>
      </ProfileUnderlay>}

      {profileFolder === "security" && <ProfileUnderlay title="Konto & Sicherheit" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={KeyRound} title="Passwort ändern" description="Passwort aktualisieren und Geräte abmelden" color={AVATAR_FARBEN[2]} onClick={() => setProfileUnderlay("password")}/>
          <ProfileSettingsCard icon={Settings} title="Sicherheit" description="Automatischen Logout einstellen" color={C.textDim} onClick={() => setProfileUnderlay("security")}/>
          <ProfileSettingsCard icon={ShieldCheck} title="Kontoeinstellungen" description="Sicherheit, Rechtliches und Accountverwaltung" color={C.textDim} onClick={() => setProfileUnderlay("account")}/>
        </div>
      </ProfileUnderlay>}

      {profileFolder === "club" && <ProfileUnderlay title="Verein & Mitgliedschaft" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          {user.roles.includes("sysadmin") && <ProfileSettingsCard icon={UserPlus} title="Benutzerverwaltung" description="Alle Vereinsnutzer auswählen und deren Einstellungen verwalten" color={AVATAR_FARBEN[2]} onClick={() => setProfileUnderlay("users")}/>}
          {user.roles.includes("vorstand") && <ProfileSettingsCard icon={Eye} title="Mitgliederübersicht" description="Alle Vereinsmitglieder ansehen (nur lesen)" color={C.textDim} onClick={() => setProfileUnderlay("board-overview")}/>}
          {user.roles.some((role) => ["sysadmin","vereinsadmin","vorstand"].includes(role)) && <ProfileSettingsCard icon={UserPlus} title="Beitrittsanfragen" description="Neue Mitglieder annehmen oder ablehnen" color={C.secondary} onClick={() => setProfileUnderlay("join-requests")}/>}
          {user.roles.includes("spieler") && <ProfileSettingsCard icon={Star} title="Athletenprofil" description="Mannschaften und Rückennummer verwalten" color={C.secondary} onClick={() => setProfileUnderlay("player")}/>}
          {user.roles.includes("trainer") && <ProfileSettingsCard icon={Trophy} title="Trainer & Rollen" description="Trainer-Mannschaften auswählen und Kapitänsrolle zuweisen" color={C.red} onClick={() => setProfileUnderlay("trainer")}/>}
          {user.roles.some((role) => ["spieler", "trainer", "teammanager", "kapitaen"].includes(role)) && <ProfileSettingsCard icon={ClipboardList} title="Strafenkatalog" description="Regeln und Kosten der Mannschaften verwalten" onClick={() => setProfileUnderlay("penalties")}/>}
        </div>
      </ProfileUnderlay>}

      {profileFolder === "notify" && <ProfileUnderlay title="Benachrichtigungen & Kalender" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={Bell} title="Benachrichtigungen" description="Festlegen, worüber du informiert werden möchtest" color={C.secondary} onClick={() => setProfileUnderlay("notifications")}/>
          <ProfileSettingsCard icon={Smartphone} title="Kalender synchronisieren" description="Spiele und Trainings mit dem Gerätekalender verbinden" color={AVATAR_FARBEN[2]} onClick={() => setProfileUnderlay("calendar")}/>
        </div>
      </ProfileUnderlay>}

      {profileFolder === "billing" && <ProfileUnderlay title="Zugang & Empfehlungen" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={Euro} title="Zugang des Vereins" description="Was freigeschaltet ist und wie viele Zugänge belegt sind" onClick={() => setProfileUnderlay("subscription")}/>
          {(!referralAlreadyUsed || user.roles.includes("sysadmin")) && <ProfileSettingsCard icon={Building2} title="Vereine werben Vereine" description="Einen Verein werben und drei Gratismonate erhalten" color={C.red} onClick={() => setProfileUnderlay("referral")}/>}
        </div>
      </ProfileUnderlay>}

      {profileFolder === "support" && <ProfileUnderlay title="Support & Feedback" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={Star} title="App bewerten" description="CMO im App Store oder Google Play bewerten" color={C.secondary} onClick={() => setProfileUnderlay("feedback")}/>
          <ProfileSettingsCard icon={Bug} title="Fehler melden" description="Eindeutiges Ticket erstellen und E-Mail-App öffnen" color={C.red} onClick={() => setProfileUnderlay("bug")}/>
        </div>
      </ProfileUnderlay>}

      {profileFolder === "howto" && <ProfileUnderlay title="App kennenlernen" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <HowToVideoLibrary user={user} vorhanden={vorhandeneVideos}/>
      </ProfileUnderlay>}

      <div className="rounded-2xl p-4 mb-5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2 text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}><Sparkles size={15} style={{ color: C.secondary }} /> Vereinspunkte</div>
          <span className="text-xs" style={{ color: C.textDim, fontFamily: "JetBrains Mono" }}>{meinePunkte} / {goal}</span>
        </div>
        <div className="h-2.5 rounded-full overflow-hidden" style={{ background: C.paperDim }}>
          <div className="h-full rounded-full" style={{ width: `${Math.min(100, (meinePunkte / goal) * 100)}%`, background: C.secondary, transition: "width .4s" }} />
        </div>
        <div className="text-xs mt-2" style={{ color: C.textDim, fontFamily: "Inter" }}>
          {punktePraemie
            ? (meinePunkte >= goal ? `${punktePraemie} — sprich den Vorstand an! 🎉` : `Noch ${goal - meinePunkte} Punkte bis: ${punktePraemie}`)
            : (meinePunkte >= goal ? "Ziel erreicht 🎉" : `Noch ${goal - meinePunkte} Punkte bis zum Ziel`)}
          <div className="text-[10px] mt-1.5" style={{ color: C.textDim }}>
            Punkte gibt es fürs Mitmachen: Helferdienste, übernommene Aufgaben, Umfragen, Tipps und Vereinstreue.
          </div>
        </div>
      </div>

      {(user.roles.includes("spieler") || user.roles.includes("trainer")) && <>
      <SectionTitle eyebrow="Auszeichnungen" title="Deine Badges" />
      {meineBadges.length === 0 ? (
        <div className="rounded-2xl p-4 mb-5 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>Noch keine Badges — sag bei Trainings zu, um deine erste Auszeichnung zu sammeln!</div>
      ) : (
        <div className="grid grid-cols-2 gap-3 mb-5">
          {meineBadges.map((bid) => {
            const b = BADGE_LIBRARY[bid];
            return (
              <div key={bid} className="rounded-2xl p-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
                <div className="w-8 h-8 rounded-full flex items-center justify-center mb-2" style={{ background: C.paper }}><b.icon size={15} style={{ color: C.red }} /></div>
                <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{b.label}</div>
                <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{b.descFor ? b.descFor(user) : b.desc}</div>
              </div>
            );
          })}
        </div>
      )}
      </>}

      {/* Hier stand "Mitglied wirbt Mitglied": "Lade Freunde ein - fuer jede
          Anmeldung gibt's 100 Vereinspunkte. Code: CMO-XY". Nichts davon gab
          es. Der Code war aus den Initialen gerechnet, wurde nirgends
          gespeichert und nirgends gelesen; die Registrierung hat kein Feld
          dafuer (das einzige Empfehlungscode-Feld gehoert zum Anlegen eines
          VEREINS und bringt dem Verein drei Gratismonate). punkte_je_mitglied
          zaehlt Helferdienste, Aufgaben, Umfragen, Saisonwahl, Tipps und
          Vereinstreue - keine Werbung. Zwei Bloecke darueber stand genau diese
          Liste als Erklaerung der Punkte, ohne Werbung: Die App widersprach
          sich selbst.

          Dasselbe Urteil ist hier schon zweimal gefallen - der Vereins-Hoodie
          und das Badge "Werber" sind aus demselben Grund verschwunden. */}

      {/* Hier standen zwei Zeilen, die wie Knoepfe aussahen und mit einem Pfeil
          nach rechts weiterzufuehren versprachen: "Fotogalerie · Sommerfest 2025"
          und "Anwesenheitsquote: 92%". Beide hatten keinen onClick - die einzigen
          zwei Knoepfe der ganzen Datei ohne Handler. Beim Antippen passierte
          nichts. Die 92% waren fest verdrahtet und standen auch bei einem Konto,
          das noch nie an einem Termin war; das Sommerfest 2025 gehoert dem
          Demo-Verein. Eine Fotogalerie gibt es nicht, eine Anwesenheitsstatistik
          auch nicht - deshalb beides entfernt statt verlinkt. */}

      <SponsorSlot slotKey="profile_bottom" bookings={werbeplaetze} onImpression={onSponsorImpression} onClick={onSponsorClick} visible={featureEnabled("sponsor_profile_bottom")} />

      <div className="grid grid-cols-3 gap-2 mb-4 text-center">
        <a href="/datenschutz" className="py-2 rounded-xl text-[10px] font-bold" style={{ background: C.glass, border: `1px solid ${C.line}`, color: C.textDim }}>Datenschutz</a>
        <a href="/impressum" className="py-2 rounded-xl text-[10px] font-bold" style={{ background: C.glass, border: `1px solid ${C.line}`, color: C.textDim }}>Impressum</a>
        <a href="/nutzungsbedingungen" className="py-2 rounded-xl text-[10px] font-bold" style={{ background: C.glass, border: `1px solid ${C.line}`, color: C.textDim }}>Bedingungen</a>
      </div>

      <button onClick={onLogout} className="w-full flex items-center justify-center gap-2 py-3 rounded-2xl text-sm" style={{ background: C.paperDim, color: C.red, fontFamily: "Inter", fontWeight: 700 }}>
        <LogOut size={15} /> Abmelden
      </button>

      {profileUnderlay === "subscription" && <ProfileUnderlay title="Zugang des Vereins" onClose={() => setProfileUnderlay("")}><SubscriptionPanel user={user}/></ProfileUnderlay>}
      {profileUnderlay === "personal" && <ProfileUnderlay title="Persönliche Daten" onClose={() => setProfileUnderlay("")} onSave={()=>sectionSaveRef.current?.()}><ProfileDataSettings user={user} setMembers={setMembers} saveRef={sectionSaveRef}/></ProfileUnderlay>}
      {profileUnderlay === "notifications" && <ProfileUnderlay title="Benachrichtigungen" onClose={() => setProfileUnderlay("")} onSave={()=>sectionSaveRef.current?.()}><NotificationSettings user={user} setMembers={setMembers} saveRef={sectionSaveRef}/></ProfileUnderlay>}
      {profileUnderlay === "password" && <ProfileUnderlay title="Passwort ändern" onClose={() => setProfileUnderlay("")} onSave={()=>sectionSaveRef.current?.()}><PasswordSettings user={user} onLogout={onLogout} saveRef={sectionSaveRef}/></ProfileUnderlay>}
      {profileUnderlay === "security" && <ProfileUnderlay title="Sicherheit" onClose={() => setProfileUnderlay("")} onSave={()=>sectionSaveRef.current?.()}><SecuritySettings user={user} setMembers={setMembers} saveRef={sectionSaveRef}/></ProfileUnderlay>}
      {profileUnderlay === "referral" && <ProfileUnderlay title="Vereine werben Vereine" onClose={() => setProfileUnderlay("")}><ReferralSettings user={user} club={currentClub}/></ProfileUnderlay>}
      {/* Ohne Premium gibt es hier nichts zu speichern — der Knopf entfällt, sonst
          stünde er wirkungslos über der Sperrmeldung. */}
      {profileUnderlay === "calendar" && <ProfileUnderlay title="Kalender synchronisieren" onClose={() => setProfileUnderlay("")} onSave={entitlement.tier !== "none" ? ()=>sectionSaveRef.current?.() : undefined}><LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Kalender-Abo"><CalendarSyncSettings user={user} saveRef={sectionSaveRef}/></LockedFeature></ProfileUnderlay>}
      {profileUnderlay === "feedback" && <ProfileUnderlay title="App bewerten" onClose={() => setProfileUnderlay("")}><FeedbackSettings/></ProfileUnderlay>}
      {profileUnderlay === "bug" && <ProfileUnderlay title="Fehler melden" onClose={() => setProfileUnderlay("")}><BugReportSettings user={user}/></ProfileUnderlay>}
      {profileUnderlay === "player" && <ProfileUnderlay title="Athletenprofil" onClose={() => setProfileUnderlay("")}><PlayerTeamSettings user={user} setMembers={setMembers}/><PlayerDataCard user={user} setMembers={setMembers}/></ProfileUnderlay>}
      {profileUnderlay === "trainer" && <ProfileUnderlay title="Trainer & Rollen" eyebrow="Mannschaftsverwaltung" onClose={() => setProfileUnderlay("")}><TrainerTeamSettings user={user} members={members} setMembers={setMembers}/></ProfileUnderlay>}
      {profileUnderlay === "penalties" && <ProfileUnderlay title="Strafenkatalog" eyebrow="Mannschaftsverwaltung" onClose={() => setProfileUnderlay("")}><TeamPenaltyCatalog user={user}/></ProfileUnderlay>}
      {profileUnderlay === "family" && <ProfileUnderlay title="Familie & Verknüpfungen" onClose={() => setProfileUnderlay("")}><SectionTitle eyebrow="Familie" title="Stammbaum"/><div className="mb-2"><FamilyTree user={user} members={members}/></div><div className="text-[11px] mb-5" style={{ color: C.textDim }}>{eligible ? "Helferdienst-berechtigt ✓ (16+)" : "Für Heimspiel-Helferdienste noch nicht 16 Jahre alt."}</div><FamilyLinkManager user={user} members={members} setMembers={setMembers}/></ProfileUnderlay>}
      {profileUnderlay === "users" && user.roles.includes("sysadmin") && <ProfileUnderlay title="Benutzerverwaltung" eyebrow="Sys-Administration" onClose={() => setProfileUnderlay("")}><SysAdminUserManager members={members} setMembers={setMembers}/></ProfileUnderlay>}
      {profileUnderlay === "board-overview" && user.roles.includes("vorstand") && <ProfileUnderlay title="Mitgliederübersicht" eyebrow="Vorstand" onClose={() => setProfileUnderlay("")}><BoardMemberOverview members={members} currentUser={user}/></ProfileUnderlay>}
      {profileUnderlay === "join-requests" && user.roles.some((role) => ["sysadmin","vereinsadmin","vorstand"].includes(role)) && <ProfileUnderlay title="Beitrittsanfragen" eyebrow="Verwalten" onClose={() => setProfileUnderlay("")}><JoinRequestsManager currentUser={user}/></ProfileUnderlay>}
      {profileUnderlay === "account" && <ProfileUnderlay title="Kontoeinstellungen" onClose={() => setProfileUnderlay("")}>
        <div className="rounded-2xl p-4 mb-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}><div className="flex items-center gap-2 text-sm font-bold mb-1" style={{ color: C.ink }}><ShieldCheck size={16} style={{ color: C.secondary }}/> Sicherheit</div><div className="text-[11px]" style={{ color: C.textDim }}>Dein Konto ist über Supabase geschützt. Passwortänderungen und Wiederherstellung erfolgen über deine hinterlegte E-Mail-Adresse.</div></div>
        <div className="space-y-2 mb-6"><a href="/datenschutz" className="w-full flex items-center justify-between rounded-2xl px-3.5 py-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}><span className="text-xs font-bold" style={{ color: C.ink }}>Datenschutz</span><ChevronRight size={14} style={{ color: C.textDim }}/></a><a href="/nutzungsbedingungen" className="w-full flex items-center justify-between rounded-2xl px-3.5 py-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}><span className="text-xs font-bold" style={{ color: C.ink }}>Nutzungsbedingungen</span><ChevronRight size={14} style={{ color: C.textDim }}/></a></div>
        <SectionTitle eyebrow="Weitere Optionen" title="Accountverwaltung"/>
        <ProfileSettingsCard icon={User} title="Account verwalten" description="Persönliche Kontodaten und weitere Kontoaktionen" color={C.textDim} onClick={() => setProfileUnderlay("account-delete")}/>
      </ProfileUnderlay>}
      {/* Schließt zurück ins Profil statt in die Kontoeinstellungen: Die Ansicht ist
          jetzt auch direkt aus der Einstellungsliste erreichbar, und ein Zurück in
          eine Ebene, die man nie geöffnet hat, wäre verwirrend. */}
      {profileUnderlay === "account-delete" && <ProfileUnderlay title="Konto löschen" eyebrow="Kontoeinstellungen" onClose={() => { setProfileUnderlay(""); setDeleteConfirm(false); setDeleteError(""); }}>
        <div className="rounded-2xl p-4 mb-6" style={{ background: C.glass, border: `1px solid ${C.line}` }}><div className="flex items-center gap-2 text-sm font-bold mb-1" style={{ color: C.ink }}><Mail size={15}/> Hinterlegte E-Mail</div><div className="text-xs" style={{ color: C.textDim }}>{user.email}</div></div>
        <SectionTitle eyebrow="Gefahrenbereich" title="Account-Löschung"/>
        <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Die Löschung entfernt dein Konto und alle personenbezogenen Daten dauerhaft.</div>
        {!deleteConfirm ? <button onClick={() => setDeleteConfirm(true)} className="w-full py-2.5 rounded-2xl text-xs" style={{ background: C.glass, border: `1px solid ${C.fehlerRand}`, color: C.red, fontWeight: 700 }}>Konto und persönliche Daten löschen</button> :
          <div className="rounded-2xl p-3" style={{ background: C.fehlerFlaeche, border: `1px solid ${C.fehlerRand}` }}><div className="flex items-center gap-2 text-xs font-bold mb-2" style={{ color: C.fehler }}><AlertCircle size={15}/> Endgültige Löschung bestätigen</div><div className="text-xs mb-3" style={{ color: C.ink }}>Das Konto, Vereinsprofile und persönliche Inhalte werden dauerhaft gelöscht. Dieser Schritt kann nicht rückgängig gemacht werden.</div>{deleteError && <div className="text-xs mb-2" style={{ color: C.fehler }}>{deleteError}</div>}<div className="flex gap-2"><button disabled={deleting} onClick={deleteAccount} className="flex-1 py-2 rounded-lg text-xs font-bold" style={{ background: C.red, color: C.white }}>{deleting ? "Wird gelöscht …" : "Endgültig löschen"}</button><button onClick={() => { setDeleteConfirm(false); setDeleteError(""); }} className="px-3 py-2 rounded-lg text-xs font-bold" style={{ background: C.glass, color: C.textDim }}>Abbrechen</button></div></div>}
      </ProfileUnderlay>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Athlet/in der Saison — Wahl                                            */
/* ------------------------------------------------------------------ */
function SeasonVoteView({ currentUser, members, seasonVotes, setSeasonVotes, onVote }) {
  const closed = new Date() > new Date(SEASON_VOTE_DEADLINE);
  const { d, h, m } = useCountdown(SEASON_VOTE_DEADLINE);
  const myVote = seasonVotes[currentUser.id];
  const { counts, total, sorted } = seasonResults(seasonVotes, saisonKandidaten(members));
  const [fehler, setFehler] = useState("");
  /* Die Stimme geht in die Datenbank. Vorher lag sie im Zustandsblock, den nur
     Administratoren speichern - die Wahl zaehlte also nur die Stimmen der
     Vereinsleitung, und auch die nur bis zum naechsten Neuladen. */
  const vote = async (id) => {
    if (closed) return;
    const vorher = seasonVotes[currentUser.id];
    setSeasonVotes((v) => ({ ...v, [currentUser.id]: id }));
    const ergebnis = await onVote?.(id);
    if (ergebnis?.error) {
      setFehler(ergebnis.error);
      setSeasonVotes((v) => ({ ...v, [currentUser.id]: vorher }));
    } else setFehler("");
  };

  return (
    <div className="px-4 pt-4 pb-10">
      <div className="rounded-2xl p-4 mb-5" style={{ background: `linear-gradient(160deg, ${C.ink}, ${C.asphalt})` }}>
        <div className="flex items-center gap-2 mb-2"><Trophy size={16} style={{ color: C.secondary }} /><span className="text-white text-sm" style={{ fontFamily: "Inter", fontWeight: 700 }}>Athlet/in der Saison {SAISON_KENNUNG}</span></div>
        {!closed ? (
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Abstimmung endet am 31.08.2026 · noch {d}T {h}Std {m}Min</div>
        ) : (
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Abstimmung beendet — Ergebnis final</div>
        )}
      </div>

      {!closed && <div className="text-xs mb-3" style={{ color: C.textDim, fontFamily: "Inter" }}>{total} Stimmen bisher abgegeben. Ergebnisse werden erst nach dem Stichtag veröffentlicht.</div>}

      {closed && sorted[0] && (
        <div className="rounded-2xl p-4 mb-5 flex items-center gap-3" style={{ background: C.sekundaerWeich, border: `1px solid ${C.edge}` }}>
          <Trophy size={22} style={{ color: C.secondary }} />
          <div>
            <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>🏆 {sorted[0].name}</div>
            <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Athlet/in der Saison — Ehrung beim Sommerfest</div>
          </div>
        </div>
      )}

      {sorted.length === 0 && (
        <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>
          Für diese Wahl sind noch keine Kandidat/innen hinterlegt.
        </div>
      )}

      <div className="space-y-2">
        {sorted.map((c, i) => {
          const pct = total ? Math.round((counts[c.id] / total) * 100) : 0;
          const mine = myVote === c.id;
          return (
            <button key={c.id} onClick={() => vote(c.id)} disabled={closed} className="w-full text-left relative overflow-hidden rounded-xl" style={{ border: `1px solid ${mine ? C.red : C.line}`, cursor: closed ? "default" : "pointer" }}>
              {closed && <div className="absolute inset-y-0 left-0" style={{ width: `${pct}%`, background: i === 0 ? C.fehlerFlaeche : C.paperDim }} />}
              <div className="relative flex items-center justify-between px-3.5 py-3">
                <div className="flex items-center gap-2">
                  {mine && <CheckCircle2 size={14} style={{ color: C.red }} />}
                  <div>
                    <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{c.name}</div>
                    <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{c.team} · #{c.number}</div>
                  </div>
                </div>
                {closed && <span className="text-xs" style={{ color: C.textDim, fontFamily: "JetBrains Mono" }}>{pct}%</span>}
              </div>
            </button>
          );
        })}
      </div>
      {!closed && myVote && <div className="text-xs mt-3 text-center" style={{ color: C.textDim, fontFamily: "Inter" }}>Du kannst deine Stimme bis zum Stichtag noch ändern.</div>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Tippspiel                                                            */
/* ------------------------------------------------------------------ */
function TippView({ members, currentUser, events, tippPredictions, setTippPredictions, tippResults, onTippSpeichern }) {
  const begegnungen = tippBegegnungen(events);
  const mine = tippPredictions[currentUser.id] || {};
  /* Der Tipp geht in die Datenbank, sobald beide Zahlen dastehen. Vorher lag er
     ausschliesslich im Arbeitsspeicher und war beim naechsten Oeffnen weg -
     samt der Punkte, die die Rangliste daraus rechnet. */
  const setPred = (matchId, side, val) => {
    setTippPredictions((tp) => {
      const userPreds = tp[currentUser.id] || {};
      const cur = userPreds[matchId] || { home: "", away: "" };
      const neu = { ...cur, [side]: val };
      onTippSpeichern?.(matchId, neu.home, neu.away);
      return { ...tp, [currentUser.id]: { ...userPreds, [matchId]: neu } };
    });
  };
  const leaderboard = members.map((member) => ({ ...member, calculatedTippPoints: totalTippPoints(member.id, tippPredictions, tippResults, begegnungen) }))
    .sort((a, b) => b.calculatedTippPoints - a.calculatedTippPoints);

  return (
    <div className="px-4 pt-4 pb-10">
      <div className="rounded-2xl p-4 mb-5 flex items-center gap-3" style={{ background: C.sekundaerWeich, border: `1px solid ${C.edge}` }}>
        <Gift size={20} style={{ color: C.secondary }} />
        <div className="text-xs" style={{ color: C.ink, fontFamily: "Inter" }}><b>Platz 1</b> am Saisonende gewinnt einen CMO-Artikel nach Wahl — Schal, Trikot oder mehr.</div>
      </div>

      <SectionTitle eyebrow="Rangliste" title="Tippspiel-Tabelle" />
      <div className="rounded-2xl overflow-hidden mb-6" style={{ border: `1px solid ${C.line}` }}>
        {leaderboard.map((m, i) => (
          <div key={m.id} className="flex items-center gap-3 px-4 py-2.5" style={{ background: m.id === currentUser.id ? C.fehlerFlaeche : C.white, borderBottom: i < leaderboard.length - 1 ? `1px solid ${C.line}` : "none" }}>
            <div className="w-6 text-center text-sm" style={{ fontFamily: "JetBrains Mono", fontWeight: 700, color: i === 0 ? C.secondary : C.textDim }}>{i === 0 ? "🥇" : i === 1 ? "🥈" : i === 2 ? "🥉" : i + 1}</div>
            <div className="w-7 h-7 rounded-full flex items-center justify-center text-[10px] font-bold" style={{ background: m.color, color: "#fff" }}>{initialsOf(m.name)}</div>
            <div className="flex-1 text-sm" style={{ fontFamily: "Inter", fontWeight: 600, color: C.ink }}>{m.name}{m.id === currentUser.id ? " (Du)" : ""}</div>
            <div className="text-sm" style={{ fontFamily: "JetBrains Mono", fontWeight: 700, color: C.ink }}>{m.calculatedTippPoints} P</div>
          </div>
        ))}
      </div>

      <SectionTitle eyebrow="Punkteregeln" title="So funktioniert's" />
      <div className="rounded-2xl p-4 mb-6 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>
        Genaues Ergebnis = 3 Punkte · richtige Tendenz = 1 Punkt. Nach Eintragung des Endergebnisses durch den Vereins-Administrator berechnet das System alle Punkte automatisch.
      </div>

      <SectionTitle eyebrow="Nächste Spiele" title="Jetzt tippen" />
      {begegnungen.length === 0 && (
        <div className="rounded-2xl p-4 mb-3 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>
          Noch keine Spiele im Terminplan. Sobald der Verein welche einträgt, könnt ihr hier tippen.
        </div>
      )}
      {begegnungen.map((match) => {
        const result = tippResults[match.id];
        const locked = new Date(match.date) < new Date() || !!result;
        const pred = mine[match.id] || { home: "", away: "" };
        const earned = predictionPoints(pred, result);
        return (
          <div key={match.id} className="rounded-2xl p-4 mb-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <div className="flex items-center justify-between mb-3">
              <div><div className="text-sm font-bold" style={{ color: C.ink, fontFamily: "Inter" }}>{match.titel}</div><div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>{formatDate(match.date)} · {formatTime(match.date)}{match.team ? ` · ${match.team}` : ""}</div></div>
              {result ? <Pill bg={C.secondary}>Endstand {result.home}:{result.away} · +{earned} P</Pill> : locked ? <Pill bg={C.textDim}>Wartet auf Ergebnis</Pill> : null}
            </div>
            <div className="flex items-center justify-center gap-3">
              <span className="text-sm flex-1 text-right" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Wir</span>
              <input type="number" min="0" disabled={locked} value={pred.home} onChange={(e) => setPred(match.id, "home", e.target.value)}
                className="w-12 text-center py-1.5 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", fontWeight: 700 }} />
              <span style={{ color: C.textDim }}>:</span>
              <input type="number" min="0" disabled={locked} value={pred.away} onChange={(e) => setPred(match.id, "away", e.target.value)}
                className="w-12 text-center py-1.5 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", fontWeight: 700 }} />
              <span className="text-sm flex-1" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Gegner</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Helferplanung — eigene Ansicht                                       */
/* ------------------------------------------------------------------ */
function DutyView({ members, currentUser, events, dutyPlan, setDutyPlan, onDienstSetzen }) {
  const helperEvents = (events || []).filter((e) => e.helperSlots && e.helperSlots.length);
  const formalMember = isFormalMember(currentUser);
  const oldEnough = age(currentUser.birthdate) >= 16;
  const familyHelpers = (!formalMember || !oldEnough) ? members.filter((m) => m.familyId && m.familyId === currentUser.familyId && m.id !== currentUser.id && isFormalMember(m) && age(m.birthdate) >= 16) : [];

  return (
    <div className="px-4 pt-4 pb-10">
      <div className="text-xs mb-4" style={{ color: C.textDim, fontFamily: "Inter" }}>Von der Theke beim Heimspiel bis zum Kuchenbuffet auf dem Sommerfest — hier findest du alle offenen Helferstellen. Trag dich direkt ein!</div>

      {!oldEnough && (
        <div className="rounded-2xl p-4 mb-5 text-xs" style={{ background: C.sekundaerWeich, border: `1px solid ${C.edge}`, color: C.ink, fontFamily: "Inter" }}>
          An Theke, Zeitnahme, Grill und Kasse bei Heimspielen helfen erst ab 16 Jahren mit — beim Sommerfest kannst du trotzdem schon zupacken.
          {familyHelpers.length > 0 && <> Für Heimspiele kann deine Familie einspringen: {familyHelpers.map((f) => f.name).join(", ")}.</>}
        </div>
      )}

      {helperEvents.length === 0 && (
        /* Ohne Leerfassung blieb hier eine weisse Flaeche: helperEvents filtert
           das Demo-Feld EVENTS nach helperSlots, und echte Termine aus der
           Datenbank tragen diese Eigenschaft nicht. Ein Pruefer sieht sonst
           eine Ansicht, die nichts tut. */
        <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>
          Für die kommenden Termine sind noch keine Helferdienste eingeplant.
          Sobald der Verein welche anlegt, erscheinen sie hier.
        </div>
      )}
      {helperEvents.map((ev) => {
        const eligible = formalMember && (ev.type !== "spiel" || oldEnough);
        return (
          <div key={ev.id} className="rounded-2xl mb-4 p-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <div className="flex items-center justify-between mb-3">
              <div>
                <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{ev.title}</div>
                <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>{formatDate(ev.date)} · {formatTime(ev.date)}</div>
              </div>
              <Pill bg={ev.home ? C.red : typeMeta[ev.type].color}>{ev.home ? "Heimspiel" : typeMeta[ev.type].label}</Pill>
            </div>
            <HelperSlots ev={ev} members={members} currentUser={currentUser} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} eligible={eligible} onSetzen={onDienstSetzen} />
          </div>
        );
      })}
    </div>
  );
}
function AdminDutyPanel({ members, events, dutyPlan, setDutyPlan, onSetzen }) {
  const helperEvents = (events || []).filter((e) => e.helperSlots && e.helperSlots.length);
  const formalMembers = members.filter((m) => isFormalMember(m));
  const add = (eventId, station, memberId) => {
    if (!memberId) return;
    setDutyPlan((dp) => {
      const plan = dp[eventId] || {};
      const list = plan[station] || [];
      if (list.includes(memberId) || list.length >= STATION_CAP) return dp;
      Promise.resolve(onSetzen?.(eventId, station, memberId, true)).then((r) => {
        if (r?.error) setDutyPlan((jetzt) => ({ ...jetzt, [eventId]: { ...(jetzt[eventId] || {}), [station]: list } }));
      });
      return { ...dp, [eventId]: { ...plan, [station]: [...list, memberId] } };
    });
  };
  const remove = (eventId, station, memberId) => {
    setDutyPlan((dp) => {
      const plan = dp[eventId] || {};
      onSetzen?.(eventId, station, memberId, false);
      return { ...dp, [eventId]: { ...plan, [station]: (plan[station] || []).filter((id) => id !== memberId) } };
    });
  };
  return (
    <div>
      <div className="text-xs mb-4" style={{ color: C.textDim, fontFamily: "Inter" }}>{formalMembers.length} Vereinsmitglieder sind hinterlegt und einteilbar (Heimspiel-Stationen zusätzlich ab 16 Jahren).</div>
      {helperEvents.length === 0 && (
        <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>
          Noch keine Termine mit Helferdiensten. Lege einen Termin an und weise ihm Dienste zu.
        </div>
      )}
      {helperEvents.map((ev) => {
        const plan = dutyPlan[ev.id] || {};
        const pool = ev.type === "spiel" ? formalMembers.filter((m) => age(m.birthdate) >= 16) : formalMembers;
        return (
          <div key={ev.id} className="rounded-2xl mb-4 p-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <div className="text-sm mb-3" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{ev.title} · {formatDate(ev.date)}</div>
            <div className="space-y-3">
              {ev.helperSlots.map((station) => {
                const list = plan[station] || [];
                return (
                  <div key={station}>
                    <div className="text-xs mb-1" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{station} ({list.length}/{STATION_CAP})</div>
                    <div className="flex flex-wrap gap-1.5 mb-1.5">
                      {list.map((id) => {
                        const m = members.find((x) => x.id === id);
                        return (
                          <span key={id} className="flex items-center gap-1 px-2 py-1 rounded-full text-[11px]" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }}>
                            {m?.name} <button onClick={() => remove(ev.id, station, id)}><X size={11} /></button>
                          </span>
                        );
                      })}
                    </div>
                    {list.length < STATION_CAP && (
                      <select onChange={(e) => { add(ev.id, station, e.target.value); e.target.value = ""; }} defaultValue=""
                        className="text-xs px-2 py-1.5 rounded-lg outline-none" style={{ background: C.paper, fontFamily: "Inter", border: `1px solid ${C.line}` }}>
                        <option value="">+ Mitglied zuteilen</option>
                        {pool.filter((m) => !list.includes(m.id)).map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
                      </select>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Vorstandsprotokolle mit Aufgabenextraktion                           */
/* ------------------------------------------------------------------ */
function ProtocolCard({ protocol, members, onToggleTask }) {
  const [open, setOpen] = useState(false);
  const openCount = protocol.tasks.filter((t) => !t.done).length;
  return (
    <div className="rounded-2xl overflow-hidden" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
      <button onClick={() => setOpen((o) => !o)} className="w-full text-left p-3 flex items-center justify-between">
        <div>
          <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{protocol.title}</div>
          <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{protocol.date} · {protocol.attendees.length} Teilnehmer:innen · {openCount} offen</div>
        </div>
        <ChevronDown size={15} style={{ color: C.textDim, transform: open ? "rotate(180deg)" : "none", transition: "transform .2s", flexShrink: 0 }} />
      </button>
      {open && (
        <div className="px-3 pb-3">
          <p className="text-xs mb-2.5" style={{ color: C.textDim, fontFamily: "Inter", whiteSpace: "pre-wrap" }}>{protocol.rawText}</p>
          <div className="space-y-1.5">
            {protocol.tasks.map((t) => {
              const person = members.find((m) => m.id === t.assignee);
              return (
                <div key={t.id} className="flex items-center gap-2 px-2.5 py-2 rounded-lg" style={{ background: C.paper }}>
                  <button onClick={() => onToggleTask(protocol.id, t.id)} className="w-4 h-4 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: t.done ? C.secondary : "transparent", border: `1.5px solid ${t.done ? C.secondary : C.line}` }}>
                    {t.done && <Check size={10} color="#fff" />}
                  </button>
                  <div className="flex-1 text-[11px]" style={{ fontFamily: "Inter", color: t.done ? C.textDim : C.ink, textDecoration: t.done ? "line-through" : "none" }}>{t.text}</div>
                  <span className="text-[10px] flex-shrink-0" style={{ color: C.textDim, fontFamily: "Inter" }}>{person ? person.name.split(" ")[0] : "–"}{t.due ? ` · ${t.due}` : ""}</span>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
function ProtokollePanel({ members, protocols, setProtocols, clubId, onSpeichern, onAufgabe }) {
  const [title, setTitle] = useState("");
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [attendees, setAttendees] = useState([]);
  const [rawText, setRawText] = useState("");
  const [draftTasks, setDraftTasks] = useState([]);
  const [newTaskText, setNewTaskText] = useState("");
  const [newTaskAssignee, setNewTaskAssignee] = useState("");
  const [newTaskDue, setNewTaskDue] = useState("");

  const toggleAttendee = (id) => setAttendees((a) => (a.includes(id) ? a.filter((x) => x !== id) : [...a, id]));
  const openTasks = protocols.flatMap((p) => p.tasks.filter((t) => !t.done).map((t) => ({ ...t, protocolTitle: p.title, protocolId: p.id })));

  const toggleTaskDone = (protocolId, taskId) => {
    const jetztErledigt = !(protocols.find((p) => p.id === protocolId)?.tasks || []).find((t) => t.id === taskId)?.done;
    onAufgabe?.(taskId, jetztErledigt);
    setProtocols((ps) => ps.map((p) => (p.id !== protocolId ? p : { ...p, tasks: p.tasks.map((t) => (t.id === taskId ? { ...t, done: !t.done } : t)) })));
  };

  const addDraftTask = () => {
    if (!newTaskText.trim()) return;
    setDraftTasks((ts) => [...ts, { id: "d" + Date.now(), text: newTaskText.trim(), assignee: newTaskAssignee, due: newTaskDue, done: false }]);
    setNewTaskText(""); setNewTaskAssignee(""); setNewTaskDue("");
  };
  const updateDraftTask = (id, patch) => setDraftTasks((ts) => ts.map((t) => (t.id === id ? { ...t, ...patch } : t)));
  const removeDraftTask = (id) => setDraftTasks((ts) => ts.filter((t) => t.id !== id));

  const [speicherFehler, setSpeicherFehler] = useState("");
  const saveProtocol = async () => {
    if (!title.trim() || !rawText.trim()) return;
    const entwurf = { title: title.trim(), date, attendees, rawText, tasks: draftTasks.filter((t) => t.text.trim()) };
    /* Erst schreiben, dann anzeigen - die Kennungen der Aufgaben kommen aus der
       Datenbank, und ohne sie liesse sich hinterher kein Haken setzen. */
    const ergebnis = await onSpeichern?.(entwurf);
    if (ergebnis?.error) { setSpeicherFehler(ergebnis.error); return; }
    /* Teilerfolg: Das Protokoll steht, die Aufgaben fehlen. Die Meldung bleibt
       stehen, das Protokoll wird trotzdem aufgenommen - sonst legt jemand aus
       Versehen ein zweites an. */
    setSpeicherFehler(ergebnis?.warnung || "");
    setProtocols((ps) => [{ ...entwurf, id: ergebnis?.id || "p" + Date.now() }, ...ps]);
    if (supabase && clubId) supabase.rpc("notify_club", { target_club: clubId, p_notif_type: "protocols", p_title: "Neues Vorstandsprotokoll", p_body: title.trim() });
    setTitle(""); setAttendees([]); setRawText(""); setDraftTasks([]);
  };

  return (
    <div className="space-y-6">
      <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Offene Aufgaben ({openTasks.length})</div>
        {openTasks.length === 0 ? (
          <div className="rounded-2xl p-3 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>Keine offenen Aufgaben — sehr gut! 🎉</div>
        ) : (
          <div className="space-y-1.5">
            {openTasks.map((t) => {
              const person = members.find((m) => m.id === t.assignee);
              return (
                <div key={t.id} className="flex items-center gap-2.5 px-3 py-2.5 rounded-xl" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
                  <button onClick={() => toggleTaskDone(t.protocolId, t.id)} className="w-5 h-5 rounded-full flex-shrink-0" style={{ border: `1.5px solid ${C.line}` }} />
                  <div className="flex-1 min-w-0">
                    <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 600, color: C.ink }}>{t.text}</div>
                    <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{person ? person.name : "nicht zugewiesen"}{t.due ? ` · fällig ${t.due}` : ""} · {t.protocolTitle}</div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Neues Protokoll erfassen</div>
        <div className="rounded-2xl p-3 space-y-2.5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Titel, z. B. Vorstandssitzung August"
            className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)}
            className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
          <div>
            <div className="text-[11px] mb-1.5" style={{ color: C.textDim, fontFamily: "Inter" }}>Teilnehmer:innen</div>
            <div className="flex flex-wrap gap-1.5">
              {members.map((m) => {
                const active = attendees.includes(m.id);
                return (
                  <button type="button" key={m.id} onClick={() => toggleAttendee(m.id)} className="px-2.5 py-1 rounded-full text-[11px]"
                    style={{ fontFamily: "Inter", fontWeight: 700, background: active ? C.ink : C.paperDim, color: active ? "#fff" : C.textDim }}>
                    {m.name}
                  </button>
                );
              })}
            </div>
          </div>
          <textarea value={rawText} onChange={(e) => setRawText(e.target.value)} placeholder="Protokolltext / Notizen der Sitzung…" rows={5}
            className="w-full px-3 py-2.5 rounded-lg text-sm outline-none resize-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
        </div>
      </div>

      <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Aufgaben für dieses Protokoll ({draftTasks.length})</div>
        <div className="rounded-2xl p-3 mb-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          <input value={newTaskText} onChange={(e) => setNewTaskText(e.target.value)} placeholder="Neue Aufgabe eintippen…"
            className="w-full px-3 py-2 rounded-lg text-sm outline-none mb-2" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
          <div className="flex gap-2 mb-2">
            <select value={newTaskAssignee} onChange={(e) => setNewTaskAssignee(e.target.value)} className="flex-1 text-xs px-2 py-1.5 rounded-lg outline-none" style={{ background: C.paperDim, fontFamily: "Inter", border: `1px solid ${C.line}` }}>
              <option value="">nicht zugewiesen</option>
              {members.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
            </select>
            <input type="date" value={newTaskDue} onChange={(e) => setNewTaskDue(e.target.value)} className="text-xs px-2 py-1.5 rounded-lg outline-none" style={{ background: C.paperDim, fontFamily: "Inter", border: `1px solid ${C.line}` }} />
          </div>
          <button onClick={addDraftTask} disabled={!newTaskText.trim()} className="w-full py-2 rounded-lg text-xs" style={{ background: C.ink, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: !newTaskText.trim() ? 0.5 : 1 }}>+ Aufgabe hinzufügen</button>
        </div>

        {draftTasks.length > 0 && (
          <div className="space-y-2 mb-3">
            {draftTasks.map((t) => (
              <div key={t.id} className="rounded-xl p-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
                <div className="flex items-start justify-between gap-2 mb-2">
                  <input value={t.text} onChange={(e) => updateDraftTask(t.id, { text: e.target.value })} className="flex-1 text-xs outline-none bg-transparent" style={{ fontFamily: "Inter", fontWeight: 600, color: C.ink }} />
                  <button onClick={() => removeDraftTask(t.id)}><X size={13} style={{ color: C.textDim }} /></button>
                </div>
                <div className="flex gap-2">
                  <select value={t.assignee} onChange={(e) => updateDraftTask(t.id, { assignee: e.target.value })} className="flex-1 text-[11px] px-2 py-1.5 rounded-lg outline-none" style={{ background: C.paperDim, fontFamily: "Inter", border: `1px solid ${C.line}` }}>
                    <option value="">nicht zugewiesen</option>
                    {members.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
                  </select>
                  <input type="date" value={t.due} onChange={(e) => updateDraftTask(t.id, { due: e.target.value })} className="text-[11px] px-2 py-1.5 rounded-lg outline-none" style={{ background: C.paperDim, fontFamily: "Inter", border: `1px solid ${C.line}` }} />
                </div>
              </div>
            ))}
          </div>
        )}

        <button onClick={saveProtocol} disabled={!title.trim() || !rawText.trim()} className="w-full py-2.5 rounded-lg text-xs" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: (!title.trim() || !rawText.trim()) ? 0.5 : 1 }}>Protokoll & Aufgaben speichern</button>
        {/* Diese Meldung wurde gesetzt und nirgends angezeigt: Scheiterte das
            Speichern, passierte fuer den Nutzer sichtbar gar nichts - das
            Formular blieb stehen, das Protokoll fehlte, und niemand sagte
            warum. */}
        {speicherFehler && <div role="alert" className="text-[11px] mt-2 rounded-xl px-3 py-2" style={{ background: C.fehlerFlaeche, color: C.fehler, fontFamily: "Inter" }}>{speicherFehler}</div>}
        {(!title.trim() || !rawText.trim()) && <div className="text-[11px] mt-1.5 text-center" style={{ color: C.textDim, fontFamily: "Inter" }}>Bitte Titel und Protokolltext ausfüllen.</div>}
      </div>

      <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Vergangene Protokolle</div>
        <div className="space-y-2">
          {protocols.map((p) => <ProtocolCard key={p.id} protocol={p} members={members} onToggleTask={toggleTaskDone} />)}
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Automatisierungen                                                    */
/* ------------------------------------------------------------------ */
function AutomationsPanel({ members, feePaid, remindersSent, setRemindersSent, welcomeAutomation, setWelcomeAutomation, billingAutomation, setBillingAutomation, onEinstellung, onErinnerung }) {
  const openMembers = members.filter((m) => isFormalMember(m) && !feePaid[m.id]);
  /* Der Vermerk gehoert in die Datenbank: Vorher stand er im Zustandsblock und
     ging verloren, sobald ein anderer Administrator speicherte - dann wurde
     dieselbe Person ein zweites Mal erinnert. */
  const sendReminder = (id) => { onErinnerung?.(id); setRemindersSent((r) => ({ ...r, [id]: new Date().toISOString() })); };

  return (
    <div className="space-y-6">
      {BEITRAGSVERWALTUNG_SICHTBAR && <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Automatische Zahlungserinnerungen</div>
        <div className="text-[11px] mb-2" style={{ color: C.textDim, fontFamily: "Inter" }}>Stufe 1 ab 3 Tagen · Stufe 2 (Mahnung) ab 10 Tagen · Stufe 3 (Vorstand informiert) ab 20 Tagen überfällig.</div>
        {openMembers.length === 0 ? (
          <div className="rounded-2xl p-3 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>Aktuell keine offenen Beiträge. 🎉</div>
        ) : (
          <div className="space-y-1.5">
            {openMembers.map((m) => {
              const days = OVERDUE_DAYS[m.id] || 0;
              const stage = reminderStage(days);
              const sent = remindersSent[m.id];
              return (
                <div key={m.id} className="flex items-center justify-between px-3 py-2.5 rounded-xl" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
                  <div>
                    <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{m.name}</div>
                    <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{days} Tage überfällig · <span style={{ color: stage.color, fontWeight: 700 }}>{stage.label}</span></div>
                  </div>
                  <button onClick={() => sendReminder(m.id)} disabled={!!sent} className="px-2.5 py-1.5 rounded-full text-[11px] flex-shrink-0" style={{ fontFamily: "Inter", fontWeight: 700, background: sent ? C.paperDim : C.ink, color: sent ? C.textDim : "#fff" }}>
                    {sent ? "Gesendet ✓" : "Erinnerung senden"}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>}

      {BEITRAGSVERWALTUNG_SICHTBAR && <ToggleCard title="Automatische Beitragsperioden" desc="Am 1. jedes Monats werden neue Beitragsposten für alle aktiven Mitglieder erzeugt. Nächster Lauf: 01.09.2026." value={billingAutomation} onChange={(w)=>{onEinstellung?.("billing_automation",w);setBillingAutomation(w);}} />}
      <ToggleCard title="Willkommens-Automatik" desc="Neue Mitglieder erhalten automatisch eine Begrüßung im Kanal „Vereins-News“." value={welcomeAutomation} onChange={(w)=>{onEinstellung?.("welcome_automation",w);setWelcomeAutomation(w);}} />
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Übersicht (Vorstands-Dashboard)                                      */
/* ------------------------------------------------------------------ */
function OverviewPanel({ members, events, feePaid, protocols, dutyPlan, seasonVotes, goPanel, showFees }) {
  const paidCount = members.filter((m) => feePaid[m.id]).length;
  const feeRate = members.length ? Math.round((paidCount / members.length) * 100) : 100;
  const openTasks = protocols.flatMap((p) => p.tasks.filter((t) => !t.done)).length;

  const helperEvents = (events || []).filter((e) => e.helperSlots && e.helperSlots.length);
  let openSlots = 0, totalSlots = 0;
  helperEvents.forEach((ev) => {
    const plan = dutyPlan[ev.id] || {};
    ev.helperSlots.forEach((s) => { totalSlots += STATION_CAP; openSlots += STATION_CAP - (plan[s]?.length || 0); });
  });
  const { total: seasonTotal } = seasonResults(seasonVotes, saisonKandidaten(members));
  /* Zeigte bislang den ersten Eintrag des Demo-Feldes - in einem echten Verein
     also einen Termin, den es dort nie gab. Jetzt der naechste echte. */
  const nextEvent = [...(events || [])]
    .filter((e) => !e.cancelled && new Date(e.date) > new Date())
    .sort((a, b) => new Date(a.date) - new Date(b.date))[0];

  return (
    <div className="grid grid-cols-2 gap-3">
      <StatCard icon={Users} label="Mitglieder" value={members.length} sub="alle formale Mitglieder" accent={C.ink} />
      {showFees && <StatCard icon={Euro} label="Beitragsquote" value={`${feeRate}%`} sub={`${members.length - paidCount} offen`} accent={C.secondary} />}
      <StatCard icon={ClipboardList} label="Offene Aufgaben" value={openTasks} sub="aus Protokollen" accent={C.red} onClick={() => goPanel("protokolle")} />
      <StatCard icon={AlertCircle} label="Helfer-Lücken" value={openSlots} sub={`von ${totalSlots} Plätzen offen`} accent={C.secondary} onClick={() => goPanel("duty")} />
      <StatCard icon={Trophy} label="Saison-Stimmen" value={seasonTotal} sub="Athlet/in der Saison" accent={C.secondary} onClick={() => goPanel("season")} />
      <StatCard icon={CalendarDays} label="Nächstes Event" value={nextEvent ? formatDate(nextEvent.date) : "—"} sub={nextEvent ? nextEvent.title : "Kein Termin geplant"} accent={C.red} />
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Sponsoring                                                            */
/* ------------------------------------------------------------------ */
/* Der Arbeitsplatz des Sponsorenmanagers.
 *
 * Vier Plaetze, je einer pro Ort in der App. Auf jedem steht entweder ein
 * eigener Sponsor des Vereins oder - wenn keiner da ist - die Werbung des
 * Betreibers. Was gerade zu sehen ist, sagt die Liste oben an jedem Platz;
 * darunter wird der eigene Sponsor gepflegt.
 *
 * Die Aktion ist der Grund fuer die Laufzeit: Ein Sponsorenlogo darf stehen
 * bleiben, eine Rabattaktion nicht. Wer eine Aktion eintraegt, muss deshalb
 * sagen, bis wann sie laeuft - die Datenbank besteht darauf, und dieses
 * Formular fragt vorher danach, statt den Fehler durchzureichen. */
function SponsoringPanel({ bookings, currentClub, clubFeatures, onFeaturesChanged, onChanged }) {
  const [eigene, setEigene] = useState([]);
  const [laden, setLaden] = useState(true);
  const [offen, setOffen] = useState("");
  const [entwurf, setEntwurf] = useState(null);
  const [speichert, setSpeichert] = useState(false);
  const [fehler, setFehler] = useState("");
  const [savingSlot, setSavingSlot] = useState("");
  const frei = currentClub?.sponsoringFrei === true;

  const ladeEigene = useCallback(async () => {
    if (!supabase || !currentClub?.id) { setEigene([]); setLaden(false); return; }
    const { data } = await supabase.from("anzeigen").select("*").eq("club_id", currentClub.id).order("created_at", { ascending: false });
    setEigene(data || []);
    setLaden(false);
  }, [currentClub?.id]);
  useEffect(() => { ladeEigene(); }, [ladeEigene]);

  const tag = (wert) => (wert ? new Date(wert).toISOString().slice(0, 10) : "");
  const leer = (platz) => ({
    id: null, platz, titel: "", text: "", bild_pfad: "", ziel_url: "",
    aktion_titel: "", aktion_text: "", aktion_url: "",
    laeuft_von: tag(new Date().toISOString()), laeuft_bis: "",
    aktion_von: tag(new Date().toISOString()), aktion_bis: "", aktiv: true,
  });
  const bearbeiten = (platz) => {
    const vorhanden = eigene.find((a) => a.platz === platz);
    setOffen(platz);
    setFehler("");
    setEntwurf(vorhanden
      ? { ...vorhanden, text: vorhanden.text || "", bild_pfad: vorhanden.bild_pfad || "", ziel_url: vorhanden.ziel_url || "",
          aktion_titel: vorhanden.aktion_titel || "", aktion_text: vorhanden.aktion_text || "", aktion_url: vorhanden.aktion_url || "",
          laeuft_von: tag(vorhanden.laeuft_von), laeuft_bis: tag(vorhanden.laeuft_bis),
          aktion_von: tag(vorhanden.aktion_von) || tag(new Date().toISOString()), aktion_bis: tag(vorhanden.aktion_bis) }
      : leer(platz));
  };
  const setzen = (feld, wert) => setEntwurf((e) => ({ ...e, [feld]: wert }));

  const bildHochladen = async (datei) => {
    if (!datei || !supabase || !currentClub?.id) return;
    if (!datei.type.startsWith("image/")) { setFehler("Bitte ein Bild auswählen."); return; }
    if (datei.size > 2 * 1024 * 1024) { setFehler("Das Bild darf höchstens 2 MB groß sein."); return; }
    setFehler("");
    const pfad = `${currentClub.id}/${entwurf.platz}-${Date.now()}.${(datei.name.split(".").pop() || "jpg").toLowerCase()}`;
    const { error } = await supabase.storage.from("sponsor-bilder").upload(pfad, datei, { contentType: datei.type, upsert: false });
    if (error) { setFehler("Das Bild konnte nicht hochgeladen werden."); return; }
    setzen("bild_pfad", pfad);
  };

  const speichern = async () => {
    if (!supabase || !currentClub?.id || !entwurf) return;
    if (!entwurf.titel.trim()) { setFehler("Ohne Namen des Sponsors geht es nicht."); return; }
    /* Vor dem Speichern pruefen, was die Datenbank ohnehin verlangt - der
       Hinweis hier ist verstaendlich, die Fehlermeldung von dort nicht. */
    if (entwurf.aktion_titel.trim() && !entwurf.aktion_bis) { setFehler("Eine Aktion braucht ein Enddatum. Bis wann läuft sie?"); return; }
    if (entwurf.laeuft_bis && entwurf.laeuft_von && new Date(entwurf.laeuft_bis) <= new Date(entwurf.laeuft_von)) { setFehler("Der Sponsor kann nicht enden, bevor er beginnt."); return; }
    if (entwurf.aktion_bis && entwurf.aktion_von && new Date(entwurf.aktion_bis) <= new Date(entwurf.aktion_von)) { setFehler("Die Aktion kann nicht enden, bevor sie beginnt."); return; }
    setSpeichert(true); setFehler("");
    const satz = {
      club_id: currentClub.id, platz: entwurf.platz,
      titel: entwurf.titel.trim(), text: entwurf.text.trim() || null,
      bild_pfad: entwurf.bild_pfad || null, ziel_url: entwurf.ziel_url.trim() || null,
      aktion_titel: entwurf.aktion_titel.trim() || null,
      aktion_text: entwurf.aktion_text.trim() || null,
      aktion_url: entwurf.aktion_url.trim() || null,
      laeuft_von: entwurf.laeuft_von ? new Date(entwurf.laeuft_von).toISOString() : new Date().toISOString(),
      /* Bis zum Ende des gewaehlten Tages, nicht bis zu seinem Beginn: Wer
         "bis 30.09." eintraegt, meint den 30. mit. */
      laeuft_bis: entwurf.laeuft_bis ? new Date(`${entwurf.laeuft_bis}T23:59:59`).toISOString() : null,
      aktion_von: entwurf.aktion_titel.trim() && entwurf.aktion_von ? new Date(entwurf.aktion_von).toISOString() : null,
      aktion_bis: entwurf.aktion_titel.trim() && entwurf.aktion_bis ? new Date(`${entwurf.aktion_bis}T23:59:59`).toISOString() : null,
      aktiv: entwurf.aktiv !== false,
    };
    const { error } = entwurf.id
      ? await supabase.from("anzeigen").update(satz).eq("id", entwurf.id)
      : await supabase.from("anzeigen").insert(satz);
    setSpeichert(false);
    if (error) { setFehler("Konnte nicht gespeichert werden."); return; }
    setOffen(""); setEntwurf(null);
    await ladeEigene(); onChanged?.();
  };

  const entfernen = async (id) => {
    if (!supabase || !id) return;
    setSpeichert(true);
    const { error } = await supabase.from("anzeigen").delete().eq("id", id);
    setSpeichert(false);
    if (error) { setFehler("Konnte nicht entfernt werden."); return; }
    setOffen(""); setEntwurf(null);
    await ladeEigene(); onChanged?.();
  };

  const toggleVisible = async (slotKey, value) => {
    if (!supabase || !currentClub?.id) return;
    setSavingSlot(slotKey); setFehler("");
    const { error } = await supabase.from("club_feature_toggles").upsert({ club_id: currentClub.id, feature_key: `sponsor_${slotKey}`, enabled: value });
    setSavingSlot("");
    if (error) { setFehler("Konnte nicht gespeichert werden."); return; }
    onFeaturesChanged?.();
  };

  if (laden) return <div className="text-xs py-6 text-center" style={{ color: C.textDim }}>Wird geladen …</div>;

  return (
    <div className="space-y-3">
      <div className="text-xs leading-relaxed" style={{ color: C.textDim, fontFamily: "Inter" }}>
        Vier Werbeplätze in der App. Wo Ihr Verein einen eigenen Sponsor einträgt, tritt die Werbung des Betreibers zurück. Eine Aktion — Rabatt, Gutschein, Sonderangebot — erscheint nur, solange sie läuft; danach bleibt der Sponsor stehen und der Aktionsknopf verschwindet von selbst.
      </div>

      {/* Ohne Freischaltung laesst sich alles eintragen, aber nichts wird
          gezeigt. Das gehoert an den Anfang und nicht in eine Fussnote. */}
      {!frei && (
        <div className="rounded-2xl p-3.5" style={{ background: C.sekundaerWeich, border: `1px solid ${C.edge}` }}>
          <div className="text-xs font-bold mb-1" style={{ color: C.ink }}>Eigene Sponsoren sind noch nicht freigeschaltet</div>
          <div className="text-[11px] leading-relaxed" style={{ color: C.textDim }}>
            Sie können hier alles vorbereiten — angezeigt wird es erst, wenn der Verein dafür freigeschaltet ist. Die Vereinsleitung kann den Zusatz zusammen mit dem Vollzugang anfragen.
          </div>
        </div>
      )}

      {fehler && <div role="status" className="text-[11px] rounded-xl px-3 py-2" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{fehler}</div>}

      {SPONSOR_SLOT_DEFS.map((slot) => {
        const sichtbar = bookings?.[slot.key];
        const meiner = eigene.find((a) => a.platz === slot.key);
        const on = (clubFeatures?.[`sponsor_${slot.key}`]) !== false;
        const laeuftAktion = meiner?.aktion_titel && meiner?.aktion_bis && new Date(meiner.aktion_bis) > new Date();
        const abgelaufen = meiner?.laeuft_bis && new Date(meiner.laeuft_bis) <= new Date();
        const imBearbeiten = offen === slot.key && entwurf;

        return (
          <div key={slot.key} className="rounded-2xl p-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <div className="flex items-center justify-between mb-2">
              <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{slot.label}</div>
              {sichtbar && <span className="text-[9px] uppercase tracking-widest font-bold px-2 py-0.5 rounded-full" style={{ background: sichtbar.herkunft === "verein" ? C.sekundaerWeich : C.paperDim, color: sichtbar.herkunft === "verein" ? C.secondary : C.textDim }}>{sichtbar.herkunft === "verein" ? "Ihr Sponsor" : "Betreiber"}</span>}
            </div>

            <div className="text-[11px] mb-2.5" style={{ color: C.textDim }}>
              {!on ? "Der Platz ist ausgeblendet — hier sieht niemand etwas."
                : sichtbar ? <>Zu sehen: <span style={{ color: C.ink, fontWeight: 600 }}>{sichtbar.titel}</span></>
                : "Der Platz ist gerade leer."}
            </div>

            <button onClick={() => savingSlot !== slot.key && toggleVisible(slot.key, !on)} className="w-full flex items-center justify-between gap-3 px-3 py-2.5 rounded-xl mb-2.5" style={{ background: C.paperDim, border: `1px solid ${C.line}`, opacity: savingSlot === slot.key ? .6 : 1 }}>
              <span className="text-xs text-left" style={{ fontFamily: "Inter", fontWeight: 600, color: C.ink }}>{on ? "Werbefläche eingeblendet" : "Werbefläche ausgeblendet"}</span>
              <span className="w-10 h-6 rounded-full relative flex-shrink-0" style={{ background: on ? C.secondary : C.line }}>
                <span className="absolute top-0.5 w-5 h-5 rounded-full" style={{ background: "#fff", left: on ? 18 : 2, transition: "left .2s" }} />
              </span>
            </button>

            {meiner && !imBearbeiten && (
              <div className="rounded-xl p-2.5 mb-2" style={{ background: C.paperDim, border: `1px solid ${C.line}` }}>
                <div className="text-xs" style={{ fontWeight: 700, color: C.ink }}>{meiner.titel}</div>
                {meiner.aktion_titel && <div className="text-[11px] mt-0.5" style={{ color: laeuftAktion ? C.red : C.textDim, fontWeight: 600 }}>
                  {meiner.aktion_titel} · {laeuftAktion ? `läuft bis ${new Date(meiner.aktion_bis).toLocaleDateString("de-DE")}` : "beendet"}
                </div>}
                {abgelaufen && <div className="text-[11px] mt-0.5" style={{ color: C.textDim }}>Der Sponsor wird nicht mehr angezeigt — die Laufzeit ist beendet.</div>}
                <div className="text-[10px] mt-1.5" style={{ color: C.textDim, fontFamily: "JetBrains Mono" }}>{meiner.impressionen ?? 0} Einblendungen · {meiner.klicks ?? 0} Klicks</div>
              </div>
            )}

            {!imBearbeiten && (
              <button onClick={() => bearbeiten(slot.key)} className="w-full px-3 py-2.5 rounded-xl text-xs" style={{ background: meiner ? C.paperDim : C.ink, color: meiner ? C.ink : C.white, fontWeight: 700, border: `1px solid ${C.line}` }}>
                {meiner ? "Sponsor bearbeiten" : "Eigenen Sponsor eintragen"}
              </button>
            )}

            {imBearbeiten && (
              <div className="space-y-2 pt-1">
                <div className="text-[10px] uppercase tracking-widest font-bold" style={{ color: C.textDim }}>Der Sponsor</div>
                <input value={entwurf.titel} onChange={(e) => setzen("titel", e.target.value)} placeholder="Name des Sponsors" maxLength={120} className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} />
                <textarea value={entwurf.text} onChange={(e) => setzen("text", e.target.value)} placeholder="Kurzer Text (optional)" rows={2} maxLength={400} className="w-full px-3 py-2 rounded-lg text-xs outline-none resize-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} />
                <input type="url" inputMode="url" value={entwurf.ziel_url} onChange={(e) => setzen("ziel_url", e.target.value)} placeholder="https://website-des-sponsors.de" className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} />
                <label className="flex items-center gap-2 px-3 py-2 rounded-lg text-xs cursor-pointer" style={{ background: C.paperDim, color: C.ink, border: `1px solid ${C.line}` }}>
                  <ImageIcon size={14} /><span className="flex-1">{entwurf.bild_pfad ? "Bild ersetzen" : "Bild hochladen (max. 2 MB)"}</span>
                  <input type="file" accept="image/*" className="hidden" onChange={(e) => bildHochladen(e.target.files?.[0])} />
                </label>
                {entwurf.bild_pfad && <div className="relative">
                  <img src={supabase?.storage.from("sponsor-bilder").getPublicUrl(entwurf.bild_pfad).data.publicUrl} alt="Vorschau" className="w-full h-24 object-cover rounded-lg" />
                  <button onClick={() => setzen("bild_pfad", "")} aria-label="Bild entfernen" className="absolute top-1 right-1 w-7 h-7 rounded-full flex items-center justify-center" style={{ background: "rgba(20,21,26,.8)", color: "white" }}><X size={13} /></button>
                </div>}

                <div className="text-[10px] uppercase tracking-widest font-bold pt-1" style={{ color: C.textDim }}>Die Aktion (optional)</div>
                <input value={entwurf.aktion_titel} onChange={(e) => setzen("aktion_titel", e.target.value)} placeholder="z. B. 10 % für alle Mitglieder" maxLength={120} className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} />
                <textarea value={entwurf.aktion_text} onChange={(e) => setzen("aktion_text", e.target.value)} placeholder="Was genau bekommt man, und wie?" rows={3} maxLength={600} className="w-full px-3 py-2 rounded-lg text-xs outline-none resize-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} />
                <input type="url" inputMode="url" value={entwurf.aktion_url} onChange={(e) => setzen("aktion_url", e.target.value)} placeholder="https://link-zur-aktion.de (optional)" className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} />

                {/* Der Aktionszeitraum erscheint erst, wenn es eine Aktion
                    gibt - vier Datumsfelder auf einmal fragt niemand gern aus. */}
                {entwurf.aktion_titel.trim() ? <>
                  <div className="flex gap-2">
                    <label className="flex-1"><span className="text-[10px] block mb-1" style={{ color: C.textDim }}>Aktion von</span>
                      <input type="date" value={entwurf.aktion_von} onChange={(e) => setzen("aktion_von", e.target.value)} className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} /></label>
                    <label className="flex-1"><span className="text-[10px] block mb-1" style={{ color: C.textDim }}>Aktion bis *</span>
                      <input type="date" value={entwurf.aktion_bis} onChange={(e) => setzen("aktion_bis", e.target.value)} className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} /></label>
                  </div>
                  <div className="text-[10px]" style={{ color: C.textDim }}>Der Aktionsknopf erscheint nur in diesem Zeitraum. Danach bleibt der Sponsor stehen, die Aktion verschwindet von selbst.</div>
                </> : null}

                <div className="text-[10px] uppercase tracking-widest font-bold pt-1" style={{ color: C.textDim }}>Der Sponsor steht auf dem Platz</div>
                <div className="flex gap-2">
                  <label className="flex-1"><span className="text-[10px] block mb-1" style={{ color: C.textDim }}>Von</span>
                    <input type="date" value={entwurf.laeuft_von} onChange={(e) => setzen("laeuft_von", e.target.value)} className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} /></label>
                  <label className="flex-1"><span className="text-[10px] block mb-1" style={{ color: C.textDim }}>Bis (optional)</span>
                    <input type="date" value={entwurf.laeuft_bis} onChange={(e) => setzen("laeuft_bis", e.target.value)} className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{ background: C.paperDim, border: `1px solid ${C.line}` }} /></label>
                </div>
                <div className="text-[10px]" style={{ color: C.textDim }}>Ohne Enddatum bleibt der Sponsor stehen, bis Sie ihn entfernen.</div>

                <div className="flex gap-2 pt-1">
                  <button onClick={() => { setOffen(""); setEntwurf(null); setFehler(""); }} className="flex-1 px-3 py-2.5 rounded-xl text-xs" style={{ background: C.paperDim, color: C.ink, fontWeight: 600, border: `1px solid ${C.line}` }}>Abbrechen</button>
                  <button onClick={speichern} disabled={speichert} className="flex-1 px-3 py-2.5 rounded-xl text-xs" style={{ background: C.ink, color: C.white, fontWeight: 700, opacity: speichert ? .6 : 1 }}>{speichert ? "…" : "Speichern"}</button>
                </div>
                {entwurf.id && <button onClick={() => entfernen(entwurf.id)} disabled={speichert} className="w-full text-[11px] pt-1" style={{ color: C.red, fontWeight: 600 }}>Sponsor von diesem Platz entfernen</button>}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function PollManagerPanel({ polls, setPolls, clubId, onAnlegen, onUmschalten }) {
  const [title, setTitle] = useState("");
  const [options, setOptions] = useState(["", ""]);
  const [fehler, setFehler] = useState("");
  const create = async () => {
    const clean = options.map((o)=>o.trim()).filter(Boolean);
    if (!title.trim() || clean.length < 2) return;
    /* Erst anlegen lassen, dann anzeigen: Die Kennung kommt aus der Datenbank,
       und ohne sie liesse sich fuer die Umfrage gar nicht abstimmen. */
    const ergebnis = await onAnlegen?.(title.trim(), clean);
    if (ergebnis?.error) { setFehler(ergebnis.error); return; }
    setFehler("");
    setPolls((ps)=>[{ id: ergebnis?.id || `poll-${Date.now()}`, title:title.trim(), active:true, options:clean.map((label)=>({label,votes:0})), voterIds:[], meineAntwortId:null },...ps]);
    if (supabase && clubId) supabase.rpc("notify_club", { target_club: clubId, p_notif_type: "polls", p_title: "Neue Umfrage", p_body: title.trim() });
    setTitle(""); setOptions(["",""]);
  };
  return <div className="space-y-4"><div className="rounded-2xl p-4" style={{background:C.glass,border:`1px solid ${C.line}`}}><div className="text-sm font-bold mb-1">Neue Mitmach-Umfrage</div><div className="text-[11px] mb-3" style={{color:C.textDim}}>Mindestens zwei Antwortmöglichkeiten eintragen.</div><input value={title} onChange={(e)=>setTitle(e.target.value)} placeholder="Frage oder Titel" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{background:C.paperDim}}/>{options.map((o,i)=><input key={i} value={o} onChange={(e)=>setOptions((all)=>all.map((x,idx)=>idx===i?e.target.value:x))} placeholder={`Antwort ${i+1}`} className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-2" style={{background:C.paperDim}}/>)}<div className="flex gap-2"><button onClick={()=>setOptions((o)=>[...o,""])} className="px-3 py-2 rounded-lg text-xs font-bold" style={{background:C.paperDim,color:C.ink}}>＋ Antwort</button><button onClick={create} className="flex-1 py-2 rounded-lg text-xs font-bold" style={{background:C.red,color:C.white}}>Veröffentlichen</button></div>{fehler&&<div role="status" className="text-[11px] rounded-xl px-3 py-2 mt-2" style={{background:C.fehlerFlaeche,color:C.fehler}}>{fehler}</div>}</div><div className="space-y-2">{polls.map((poll)=><div key={poll.id} className="rounded-xl p-3 flex items-center gap-3" style={{background:C.glass,border:`1px solid ${C.line}`}}><div className="flex-1"><div className="text-xs font-bold">{poll.title}</div><div className="text-[10px] mt-1" style={{color:C.textDim}}>{poll.options.length} Antworten · {poll.options.reduce((n,o)=>n+o.votes,0)} Stimmen</div></div><button onClick={()=>{onUmschalten?.(poll.id,!poll.active);setPolls((ps)=>ps.map((p)=>p.id===poll.id?{...p,active:!p.active}:p));}} className="px-2.5 py-1.5 rounded-full text-[10px] font-bold" style={{background:poll.active?C.erfolgFlaeche:C.paperDim,color:poll.active?C.secondary:C.textDim}}>{poll.active?"Aktiv":"Inaktiv"}</button></div>)}</div></div>;
}

function MatchResultsPanel({ results, onSave, events }) {
  const begegnungen = tippBegegnungen(events);
  const [drafts, setDrafts] = useState({});
  const [savedId, setSavedId] = useState(null);
  const update = (matchId, side, value) => setDrafts((current) => ({
    ...current,
    [matchId]: { home: current[matchId]?.home ?? "", away: current[matchId]?.away ?? "", [side]: value },
  }));
  const save = (match) => {
    const draft = drafts[match.id] || results[match.id];
    if (!draft || draft.home === "" || draft.away === "") return;
    onSave(match.id, { home: Number(draft.home), away: Number(draft.away), enteredAt: new Date().toISOString() });
    setSavedId(match.id);
    setTimeout(() => setSavedId(null), 1800);
  };
  return (
    <div>
      <div className="rounded-2xl p-4 mb-4" style={{ background: C.erfolgFlaeche, border: `1px solid ${C.erfolgRand}` }}>
        <div className="text-sm font-bold mb-1" style={{ color: C.ink }}>Ergebnisse & Punkte</div>
        <div className="text-xs" style={{ color: C.textDim }}>Endstand nach dem Spiel eintragen. Das System wertet danach alle Tipps aus: exakt 3 Punkte, richtige Tendenz 1 Punkt.</div>
      </div>
      {begegnungen.length === 0 && (
        <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>
          Noch keine Spiele im Terminplan, für die sich ein Ergebnis eintragen ließe.
        </div>
      )}
      <div className="space-y-3">
        {begegnungen.map((match) => {
          const values = drafts[match.id] || results[match.id] || { home: "", away: "" };
          return (
            <div key={match.id} className="rounded-2xl p-4" style={{ background: C.glass, border: `1px solid ${results[match.id] ? C.erfolgRand : C.line}` }}>
              <div className="flex items-center justify-between mb-3">
                <div><div className="text-xs font-bold" style={{ color: C.ink }}>{match.titel}</div><span className="text-[11px]" style={{ color: C.textDim }}>{formatDate(match.date)} · {formatTime(match.date)}</span></div>
                {results[match.id] && <Pill bg={C.secondary}>ausgewertet</Pill>}
              </div>
              <div className="flex items-center gap-2 mb-3">
                <span className="text-xs font-bold flex-1 text-right" style={{ color: C.ink }}>{match.home}</span>
                <input aria-label={`Tore ${match.home}`} type="number" min="0" value={values.home} onChange={(event) => update(match.id, "home", event.target.value)} className="w-12 text-center py-2 rounded-lg outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", fontWeight: 700 }} />
                <span style={{ color: C.textDim }}>:</span>
                <input aria-label={`Tore ${match.away}`} type="number" min="0" value={values.away} onChange={(event) => update(match.id, "away", event.target.value)} className="w-12 text-center py-2 rounded-lg outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", fontWeight: 700 }} />
                <span className="text-xs font-bold flex-1" style={{ color: C.ink }}>{match.away}</span>
              </div>
              <button onClick={() => save(match)} className="w-full py-2 rounded-lg text-xs font-bold" style={{ background: savedId === match.id ? C.secondary : C.ink, color: C.white }}>
                {savedId === match.id ? "Punkte wurden berechnet ✓" : results[match.id] ? "Ergebnis korrigieren & neu berechnen" : "Ergebnis speichern & Punkte berechnen"}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Rollenverwaltung                                                     */
/* ------------------------------------------------------------------ */
function RolesPanel({ members, setMembers }) {
  /* Die Mannschaften kommen aus dem Verein, nicht aus der Demo-Konstante.
     YOUTH_CLASSES ist eine feste Liste - Herren 1, Herren 2, Damen 1, U15, U11 -,
     und genau die wurde jedem Verein zur Auswahl gestellt: Ein Vorstand konnte
     seine Trainer nur Mannschaften zuweisen, die es bei ihm nicht gibt, waehrend
     die eigenen fehlten.
     Hier ist der Nutzer angemeldet und Mitglied, die teams-Tabelle also lesbar.
     Ohne Datenbank bleibt es bei der Konstante - dort IST der Demo-Verein der
     Verein. */
  const [vereinsTeams, setVereinsTeams] = useState(null);
  useEffect(() => {
    const clubId = members.find((m) => m.clubId)?.clubId;
    if (!supabase || !isDbId(clubId)) { setVereinsTeams(null); return; }
    supabase.from("teams").select("name").eq("club_id", clubId).eq("active", true).order("name")
      .then(({ data }) => setVereinsTeams([...new Set((data || []).map((t) => t.name).filter(Boolean))].map((name) => ({ id: name, name }))));
  }, [members]);
  const waehlbareMannschaften = vereinsTeams === null ? YOUTH_CLASSES : vereinsTeams;

  const [message, setMessage] = useState("");
  const [expandedId, setExpandedId] = useState(null);
  const [draftRoles, setDraftRoles] = useState([]);
  const [saving, setSaving] = useState(false);

  const openMember = (memberId, currentRoles) => {
    setMessage("");
    setExpandedId(memberId);
    setDraftRoles([...currentRoles]);
  };
  const closeMember = () => { setExpandedId(null); setDraftRoles([]); };

  const toggleDraftRole = (role) => {
    if (ROLE_META[role]?.alwaysOn) return; // "Mitglied" ist Basisrolle für alle
    setDraftRoles((roles) => {
      const has = roles.includes(role);
      if (has && roles.length === 1) return roles; // mindestens eine Rolle behalten
      return has ? roles.filter((r) => r !== role) : [...roles, role];
    });
  };

  const saveMemberRoles = async (memberId) => {
    const member = members.find((item) => item.id === memberId);
    if (!member) return;
    setSaving(true);
    setMessage("");
    if (supabase && isDbId(memberId)) {
      const toAdd = draftRoles.filter((r) => !member.roles.includes(r));
      const toRemove = member.roles.filter((r) => !draftRoles.includes(r));
      const grantedBy = (await supabase.auth.getUser()).data.user?.id || null;
      for (const role of toAdd) {
        const { error } = await supabase.from("membership_roles").insert({ membership_id: memberId, role, granted_by: grantedBy });
        if (error) { setMessage("Die Rollenänderung konnte nicht gespeichert werden."); setSaving(false); return; }
      }
      for (const role of toRemove) {
        const { error } = await supabase.from("membership_roles").delete().eq("membership_id", memberId).eq("role", role);
        if (error) { setMessage("Die Rollenänderung konnte nicht gespeichert werden."); setSaving(false); return; }
      }
    }
    setMembers((ms) => ms.map((m) => (m.id === memberId
      ? { ...m, roles: draftRoles, ...(!draftRoles.includes("teammanager") ? { managedTeam: null } : {}) }
      : m)));
    setSaving(false);
    closeMember();
  };

  const assignManagedTeam = async (memberId, team) => {
    const member = members.find((item) => item.id === memberId);
    if (!member) return;
    let displacedMemberId = null;
    if (supabase && isDbId(memberId)) {
      setMessage("");
      let teamId = null;
      if (team) {
        const { data: teamRow, error: teamError } = await supabase.from("teams").select("id").eq("club_id", member.clubId).eq("name", team).maybeSingle();
        if (teamError || !teamRow) { setMessage("Die Mannschaft des Teammanagers konnte nicht gespeichert werden."); return; }
        teamId = teamRow.id;
        const { data: existingManager } = await supabase.from("team_members").select("membership_id").eq("team_id", teamId).eq("function", "teammanager").neq("membership_id", memberId).maybeSingle();
        displacedMemberId = existingManager?.membership_id || null;
      }
      const { error: clearError } = await supabase.from("team_members").delete().eq("membership_id", memberId).eq("function", "teammanager");
      if (clearError) { setMessage("Die Mannschaft des Teammanagers konnte nicht gespeichert werden."); return; }
      if (displacedMemberId) {
        await supabase.from("team_members").delete().eq("membership_id", displacedMemberId).eq("function", "teammanager");
        await supabase.from("membership_roles").delete().eq("membership_id", displacedMemberId).eq("role", "teammanager");
      }
      if (teamId) {
        const { error: insertError } = await supabase.from("team_members").insert({ team_id: teamId, membership_id: memberId, function: "teammanager" });
        if (insertError) { setMessage("Die Mannschaft des Teammanagers konnte nicht gespeichert werden."); return; }
      }
    }
    setMembers((all) => all.map((m) => {
      if (m.id === memberId) return { ...m, managedTeam: team };
      if (displacedMemberId && m.id === displacedMemberId) return { ...m, managedTeam: null, roles: m.roles.filter((role) => role !== "teammanager") };
      return m;
    }));
  };
  const toggleTrainerTeam = async (memberId, teamName) => {
    const member = members.find((item) => item.id === memberId);
    const currentTeams = member?.trainerTeams || [];
    const nextTeams = currentTeams.includes(teamName) ? currentTeams.filter((name) => name !== teamName) : [...currentTeams, teamName];
    if (supabase && isDbId(memberId)) {
      setMessage("");
      const { error } = await supabase.rpc("set_trainer_teams", { target_membership: memberId, target_team_names: nextTeams });
      if (error) { setMessage("Die Trainer-Mannschaften konnten nicht gespeichert werden."); return; }
    }
    setMembers((all) => all.map((item) => item.id === memberId ? { ...item, trainerTeams: nextTeams } : item));
  };
  return (
    <div className="space-y-3">
      <div className="text-xs mb-1" style={{ color: C.textDim, fontFamily: "Inter" }}>Tippe auf ein Mitglied, um die Rollen zu bearbeiten. Vereins-Administrator, Vorstand & Geschäftsführung können nur hier zugewiesen werden.</div>
      {message&&<div className="rounded-xl px-3 py-2 text-[11px] font-semibold" style={{background:C.fehlerFlaeche,color:C.fehler}}>{message}</div>}
      {members.map((m) => {
        const expanded = expandedId === m.id;
        return (
          <div key={m.id} className="rounded-2xl overflow-hidden" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <button type="button" onClick={() => (expanded ? closeMember() : openMember(m.id, m.roles))} className="w-full flex items-center gap-2 p-3 text-left">
              <div className="w-7 h-7 rounded-full flex items-center justify-center text-[10px] font-bold flex-shrink-0" style={{ background: m.color, color: "#fff", fontFamily: "Inter" }}>{initialsOf(m.name)}</div>
              <div className="flex-1 min-w-0">
                <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{m.name}</div>
                {!expanded && (
                  <div className="flex flex-wrap gap-1 mt-1">
                    {m.roles.filter((r) => ASSIGNABLE_ROLES.includes(r)).map((r) => (
                      <span key={r} className="px-2 py-0.5 rounded-full text-[10px]" style={{ fontFamily: "Inter", fontWeight: 700, background: C.paperDim, color: C.textDim }}>{ROLE_META[r].label}</span>
                    ))}
                  </div>
                )}
              </div>
              <ChevronDown size={16} style={{ color: C.textDim, transform: expanded ? "rotate(180deg)" : "none", transition: "transform .15s ease", flexShrink: 0 }} />
            </button>
            {expanded && (
              <div className="px-3 pb-3">
                <div className="flex flex-wrap gap-1.5">
                  {ASSIGNABLE_ROLES.map((r) => {
                    const active = draftRoles.includes(r);
                    return (
                      <button key={r} type="button" onClick={() => toggleDraftRole(r)} className="px-2.5 py-1 rounded-full text-[11px]"
                        style={{ fontFamily: "Inter", fontWeight: 700, background: active ? ROLE_META[r].color : C.paperDim, color: active ? "#fff" : C.textDim }}>
                        {ROLE_META[r].label}
                      </button>
                    );
                  })}
                </div>
                {m.roles.includes("trainer")&&<div className="mt-2.5 pt-2.5" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[10px] mb-2 font-bold" style={{color:C.textDim}}>TRAINER FÜR · MEHRERE MANNSCHAFTEN MÖGLICH</div><div className="flex flex-wrap gap-1.5">{waehlbareMannschaften.length===0&&<span className="text-[11px]" style={{color:C.textDim}}>Noch keine Mannschaften angelegt — das geht im Reiter „Mannschaften“.</span>}{waehlbareMannschaften.map((team)=>{const active=(m.trainerTeams||[]).includes(team.name);return <button type="button" key={team.name} onClick={()=>toggleTrainerTeam(m.id,team.name)} className="px-2.5 py-1.5 rounded-full text-[11px] font-bold" style={{background:active?ROLE_META.trainer.color:C.paperDim,color:active?C.white:C.textDim}}>{active?"✓ ":""}{team.name}</button>})}</div></div>}
                {m.roles.includes("teammanager")&&<div className="mt-2.5 pt-2.5" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[10px] mb-1 font-bold" style={{color:C.textDim}}>Betreute Mannschaft · maximal ein Teammanager je Mannschaft</div><select value={m.managedTeam||""} onChange={(e)=>assignManagedTeam(m.id,e.target.value)} className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{background:C.paperDim}}><option value="">Mannschaft auswählen …</option>{waehlbareMannschaften.map((team)=><option key={team.name} value={team.name}>{team.name}</option>)}</select></div>}
                <div className="flex gap-2 mt-3 pt-3" style={{ borderTop: `1px solid ${C.line}` }}>
                  <button type="button" onClick={closeMember} disabled={saving} className="flex-1 py-2 rounded-lg text-xs" style={{ background: C.paperDim, color: C.ink, fontFamily: "Inter", fontWeight: 700 }}>Abbrechen</button>
                  <button type="button" onClick={() => saveMemberRoles(m.id)} disabled={saving} className="flex-1 py-2 rounded-lg text-xs" style={{ background: C.ink, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: saving ? 0.6 : 1 }}>{saving ? "Speichert …" : "Speichern"}</button>
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* System (Sys-Admin)                                                   */
/* ------------------------------------------------------------------ */
function SystemPanel({ members, channels, setChannels, maintenanceMode, setMaintenanceMode, onResetDemo, onEinstellung }) {
  /* Die Sicherheitsabfrage vor dem Zuruecksetzen. Der Zustand war beim Umbau der
     Kanalverwaltung verschwunden, die beiden Verwendungen weiter unten blieben
     stehen - damit riss Verwaltung > System mit einem ReferenceError ab, sobald
     man den Reiter oeffnete. */
  const [confirmReset, setConfirmReset] = useState(false);

  return (
    <div className="space-y-6">
      <ToggleCard title="Wartungsmodus" desc="Hinweis-Banner für alle Nutzer:innen einblenden." value={maintenanceMode} onChange={(w)=>{onEinstellung?.("maintenance_mode",w);setMaintenanceMode(w);}} />

        <div className="rounded-2xl p-3 mb-3" style={{ background: C.paperDim }}>
          <div className="text-sm mb-1" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Chat-Kanäle</div>
          <div className="text-[11px] leading-snug" style={{ color: C.textDim }}>
            Kanäle entstehen automatisch: Jede Mannschaft hat genau einen. Sichtbar ist er
            für ihre Mitglieder und deren Eltern, schreiben dürfen Trainer, Kapitäne,
            Teammanager sowie Vorstand und Vereinsverwaltung. Von Hand angelegt wird nichts —
            so kann kein Kanal entstehen, den niemand pflegt, und keiner fehlen.
          </div>
        </div>

      <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Konten-Übersicht</div>
        <div className="rounded-2xl overflow-hidden" style={{ border: `1px solid ${C.line}` }}>
          {members.map((m, i) => (
            <div key={m.id} className="px-4 py-2.5" style={{ background: C.glass, borderBottom: i < members.length - 1 ? `1px solid ${C.line}` : "none" }}>
              <div className="flex items-center justify-between">
                <span className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{m.name}</span>
                <span className="text-[10px]" style={{ fontFamily: "JetBrains Mono", color: C.textDim }}>{m.id}</span>
              </div>
              <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.email} · {m.roles.map((r) => ROLE_META[r].label).join(", ")}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Nur ohne Datenbank. Fuer einen echten Verein war dieser Knopf eine
          Falle: Er versprach ein Zuruecksetzen und schob stattdessen die
          Demo-Inhalte eines fremden Vereins unter - zehn erfundene Spiele in
          der Hemberghalle Iserlohn, vier Kanaele mit erfundenen Nachrichten.
          Geschrieben wurde dabei nichts; nach dem Neuladen war alles wieder
          da. */}
      {!supabase && <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Demo-Daten</div>
        {!confirmReset ? (
          <button onClick={() => setConfirmReset(true)} className="w-full py-3 rounded-2xl text-sm" style={{ background: C.paperDim, color: C.red, fontFamily: "Inter", fontWeight: 700 }}>
            Tipps, Beiträge & Helfer zurücksetzen
          </button>
        ) : (
          <div className="rounded-2xl p-3" style={{ background: C.fehlerFlaeche, border: `1px solid ${C.fehlerRand}` }}>
            <div className="text-xs mb-2" style={{ color: C.ink, fontFamily: "Inter" }}>Wirklich alle Aktivitätsdaten zurücksetzen? Konten, Rollen und Protokolle bleiben erhalten.</div>
            <div className="flex gap-2">
              <button onClick={() => { onResetDemo(); setConfirmReset(false); }} className="flex-1 py-2 rounded-lg text-xs" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700 }}>Ja, zurücksetzen</button>
              <button onClick={() => setConfirmReset(false)} className="flex-1 py-2 rounded-lg text-xs" style={{ background: C.glass, color: C.textDim, fontFamily: "Inter", fontWeight: 700, border: `1px solid ${C.line}` }}>Abbrechen</button>
            </div>
          </div>
        )}
      </div>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Verwaltung (Vorstand / Geschäftsführung / Sys-Admin)                 */
/* ------------------------------------------------------------------ */
function ClubLogoPanel({ club, onLogoUpdated }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  const uploadLogo = async (event) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      setMessage("Bitte JPG, PNG oder WebP auswählen."); return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setMessage("Das Vereinslogo darf höchstens 2 MB groß sein."); return;
    }
    setBusy(true); setMessage("");
    if (!supabase) {
      const reader = new FileReader();
      reader.onload = () => { onLogoUpdated(String(reader.result)); setMessage("Vereinslogo gespeichert."); setBusy(false); };
      reader.onerror = () => { setMessage("Das Bild konnte nicht gelesen werden."); setBusy(false); };
      reader.readAsDataURL(file);
      return;
    }
    const extension = file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : "jpg";
    const folder = String(club.id);
    const path = `${folder}/logo-${Date.now()}.${extension}`;
    const { data: existing } = await supabase.storage.from("club-logos").list(folder);
    const oldPaths = (existing || []).map((item) => `${folder}/${item.name}`);
    const { error: uploadError } = await supabase.storage.from("club-logos").upload(path, file, { contentType: file.type, upsert: false });
    if (uploadError) { setMessage("Das Vereinslogo konnte nicht hochgeladen werden."); setBusy(false); return; }
    const { data: publicFile } = supabase.storage.from("club-logos").getPublicUrl(path);
    const logoUrl = publicFile.publicUrl;
    const { error: updateError } = await supabase.from("clubs").update({ logo_url: logoUrl }).eq("id", club.id);
    if (updateError) {
      await supabase.storage.from("club-logos").remove([path]);
      setMessage("Das Vereinsprofil konnte nicht aktualisiert werden."); setBusy(false); return;
    }
    if (oldPaths.length) await supabase.storage.from("club-logos").remove(oldPaths);
    onLogoUpdated(logoUrl); setMessage("Vereinslogo gespeichert."); setBusy(false);
  };

  return <div className="rounded-2xl p-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
    <div className="flex items-center gap-3 mb-3">
      <ClubLogo club={club} size={58} rounded={15} />
      <div><div className="text-sm font-bold" style={{ color: C.ink }}>Profilbild des Vereins</div><div className="text-[11px]" style={{ color: C.textDim }}>JPG, PNG oder WebP · maximal 2 MB</div></div>
    </div>
    <label className="w-full py-2.5 rounded-xl text-xs font-bold flex items-center justify-center gap-2 cursor-pointer" style={{ background: C.ink, color: C.white, opacity: busy ? .6 : 1 }}>
      <ImageIcon size={15} /> {busy ? "Wird gespeichert …" : "Vereinslogo auswählen"}
      <input type="file" accept="image/jpeg,image/png,image/webp" onChange={uploadLogo} disabled={busy} className="hidden" />
    </label>
    {message && <div className="text-[11px] mt-2" role="status" style={{ color: message.includes("gespeichert") ? C.erfolg : C.fehler }}>{message}</div>}
  </div>;
}

function ClubColorPanel({ club, onColorsUpdated }) {
  const [primary, setPrimary] = useState(club.primaryColor || DEFAULT_CLUB_COLORS.primary);
  const [secondary, setSecondary] = useState(club.secondaryColor || DEFAULT_CLUB_COLORS.secondary);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const dirty = primary !== (club.primaryColor || DEFAULT_CLUB_COLORS.primary) || secondary !== (club.secondaryColor || DEFAULT_CLUB_COLORS.secondary);

  const save = async () => {
    setSaving(true); setMessage("");
    if (!supabase) { onColorsUpdated(primary, secondary); setMessage("Vereinsfarben gespeichert."); setSaving(false); return; }
    const { error } = await supabase.from("clubs").update({ primary_color: primary, secondary_color: secondary }).eq("id", club.id);
    setSaving(false);
    if (error) { setMessage("Die Vereinsfarben konnten nicht gespeichert werden."); return; }
    onColorsUpdated(primary, secondary);
    setMessage("Vereinsfarben gespeichert.");
  };

  return <div className="rounded-2xl p-4 mt-3" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
    <div className="text-sm font-bold mb-3" style={{ color: C.ink }}>Vereinsfarben</div>
    <ClubColorPicker primary={primary} secondary={secondary} onChange={(p, s) => { setPrimary(p); setSecondary(s); setMessage(""); }} />
    <button onClick={save} disabled={saving || !dirty} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: dirty ? C.ink : C.paperDim, color: dirty ? C.white : C.textDim, opacity: saving ? .6 : 1 }}>{saving ? "Wird gespeichert …" : "Farben speichern"}</button>
    {message && <div className="text-[11px] mt-2" role="status" style={{ color: message.includes("gespeichert") ? C.erfolg : C.fehler }}>{message}</div>}
  </div>;
}

function MembershipApprovalsPanel({ club, members, setMembers }) {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [workingId, setWorkingId] = useState(null);
  const [message, setMessage] = useState("");
  const [activeMembers, setActiveMembers] = useState([]);
  const [loadingActive, setLoadingActive] = useState(true);
  const [showActive, setShowActive] = useState(false);

  const loadActiveMembers = async () => {
    setLoadingActive(true);
    if (!supabase) { setActiveMembers([]); setLoadingActive(false); return; }
    const { data, error } = await supabase.from("club_memberships")
      .select("id,display_name,email,status")
      .eq("club_id", club.id).in("status", ["active", "inactive", "blocked"]).order("display_name");
    if (!error) setActiveMembers(data || []);
    setLoadingActive(false);
  };
  useEffect(() => { loadActiveMembers(); }, [club?.id]);

  /* Die Sperrliste ist eine Sicht auf dieselben Daten, kein zweiter Bestand.
     Gesperrte stehen deshalb NICHT zusaetzlich in der Mitgliederliste darueber -
     sonst stuende jede Person zweimal da, mit unterschiedlichen Knoepfen. */
  const gesperrte = activeMembers.filter((m) => m.status === "blocked");
  const nichtGesperrte = activeMembers.filter((m) => m.status !== "blocked");

  /* Sperren und Entsperren.

     Die Sperre ist der einzige Weg, jemanden dauerhaft draussen zu halten:
     register_for_club weist eine Anfrage ab, solange die Mitgliedschaft auf
     'blocked' steht. Ablehnen tut das bewusst NICHT mehr - wer abgelehnt wird,
     darf sofort wieder anfragen. Nur diese Aktion hier hat Bestand.

     Die Mitgliedschaftszeile bleibt erhalten; sie IST die Sperrliste. Wird sie
     ueber "Entfernen" geloescht, faellt die Sperre mit ihr weg - dann darf die
     Person sich neu bewerben. Das ist Absicht: Entfernen heisst weg, nicht
     verbannt. */
  const blockMember = async (member) => {
    if (!window.confirm(`${member.display_name} für den Verein sperren?\n\nDie Person verliert den Zugang und kann keine neue Beitrittsanfrage stellen, bis du sie wieder entsperrst. Sie erscheint so lange in der Sperrliste.`)) return;
    setWorkingId(member.id); setMessage("");
    const { error } = await supabase.from("club_memberships").update({ status: "blocked" }).eq("id", member.id).eq("club_id", club.id);
    if (error) { setMessage("Die Sperre konnte nicht gesetzt werden."); setWorkingId(null); return; }
    setActiveMembers((items) => items.map((item) => item.id === member.id ? { ...item, status: "blocked" } : item));
    setMembers((items) => items.map((item) => item.id === member.id ? { ...item, status: "blocked", accountPending: false } : item));
    setMessage(`${member.display_name} ist jetzt gesperrt.`);
    setWorkingId(null);
    notifyClubAdmins(club.id, "membership", "Mitglied gesperrt", `${member.display_name} wurde für den Verein gesperrt.`, member.id);
  };

  const unblockMember = async (member) => {
    setWorkingId(member.id); setMessage("");
    /* Zurueck auf 'inactive', nicht auf 'active': Entsperren heisst "darf sich
       wieder bewerben", nicht "ist wieder dabei". Ueber die Aufnahme entscheidet
       die Vereinsleitung erneut. blocked_until wird mitgeleert, damit keine alte
       Frist nachwirkt. */
    const { error } = await supabase.from("club_memberships").update({ status: "inactive", blocked_until: null }).eq("id", member.id).eq("club_id", club.id);
    if (error) { setMessage("Die Sperre konnte nicht aufgehoben werden."); setWorkingId(null); return; }
    setActiveMembers((items) => items.map((item) => item.id === member.id ? { ...item, status: "inactive" } : item));
    setMembers((items) => items.map((item) => item.id === member.id ? { ...item, status: "inactive" } : item));
    setMessage(`${member.display_name} ist entsperrt und kann sich wieder bewerben.`);
    setWorkingId(null);
  };

  const toggleMemberActive = async (member) => {
    const nextStatus = member.status === "active" ? "inactive" : "active";
    if (nextStatus === "inactive" && !window.confirm(`Mitgliedschaft von ${member.display_name} wirklich beenden? Das Mitglied kann sich danach nicht mehr anmelden, bleibt aber in der Historie erhalten.`)) return;
    setWorkingId(member.id); setMessage("");
    const { error } = await supabase.from("club_memberships").update({ status: nextStatus }).eq("id", member.id).eq("club_id", club.id);
    if (error) { setMessage("Der Status konnte nicht geändert werden."); setWorkingId(null); return; }
    setActiveMembers((items) => items.map((item) => item.id === member.id ? { ...item, status: nextStatus } : item));
    setMembers((items) => items.map((item) => item.id === member.id ? { ...item, status: nextStatus, accountPending: false } : item));
    setMessage(nextStatus === "inactive" ? "Mitgliedschaft wurde beendet." : "Mitgliedschaft wurde reaktiviert.");
    setWorkingId(null);
    if (nextStatus === "inactive") {
      notifyClubAdmins(club.id, "membership", "Mitgliedschaft beendet", `${member.display_name} ist nicht mehr aktives Mitglied.`, member.id);
    }
  };

  /* Endgueltig aus dem Verein entfernen - im Unterschied zum Beenden, das die
     Mitgliedschaft nur stilllegt und in der Historie belaesst.

     Was mitgeht, regeln die Fremdschluessel: Rollen, Mannschaftszuordnung,
     Fahrgemeinschaften, Helfereinteilung, Beitraege und Benachrichtigungen
     haengen mit CASCADE daran und verschwinden. Angelegte Aufgaben, Fahrzeuge
     und Vorlagen bleiben dem Verein erhalten und verlieren nur den Vermerk, wer
     sie angelegt hat - sie gehoeren dem Verein, nicht der Person.

     Das Benutzerkonto selbst bleibt bestehen. Wer entfernt wurde, kann sich
     erneut um Aufnahme bewerben; loeschen kann das Konto nur die Person selbst
     (Profil > Konto loeschen). */
  const removeMember = async (member) => {
    if (!window.confirm(`${member.display_name} endgültig aus dem Verein entfernen?\n\nRollen, Mannschaftszuordnung, Helfereinteilungen und Beiträge gehen dabei verloren. Das Benutzerkonto selbst bleibt bestehen.\n\nSoll die Person nur nicht mehr teilnehmen, ist „Beenden“ der schonendere Weg.`)) return;
    setWorkingId(member.id); setMessage("");
    const { error } = await supabase.from("club_memberships").delete().eq("id", member.id).eq("club_id", club.id);
    if (error) {
      /* Ein Fremdschluessel kann die Loeschung weiterhin sperren, wenn spaeter
         eine neue Tabelle ohne cascade hinzukommt. Dann soll dastehen, was los
         ist, statt nur "ging nicht". */
      setMessage(/foreign key|violates|constraint/i.test(error.message || "")
        ? "Die Person kann nicht entfernt werden, weil noch Einträge an ihr hängen. Beende die Mitgliedschaft stattdessen."
        : "Die Person konnte nicht entfernt werden.");
      setWorkingId(null); return;
    }
    setActiveMembers((items) => items.filter((item) => item.id !== member.id));
    setMembers((items) => items.filter((item) => item.id !== member.id));
    setMessage(`${member.display_name} wurde aus dem Verein entfernt.`);
    setWorkingId(null);
    notifyClubAdmins(club.id, "membership", "Mitglied entfernt", `${member.display_name} wurde aus dem Verein entfernt.`);
  };

  const loadRequests = async () => {
    setLoading(true); setMessage("");
    if (!supabase) {
      setRequests(members.filter((member) => member.accountPending).map((member) => ({
        id: member.id, display_name: member.name, email: member.email, requested_team: member.team,
        created_at: new Date().toISOString(), membership_roles: member.roles.map((role) => ({ role })),
      })));
      setLoading(false); return;
    }
    const { data, error } = await supabase.from("club_memberships")
      .select("id,display_name,email,member_since,requested_team,created_at,rejection_count,membership_roles(role)")
      .eq("club_id", club.id).eq("status", "pending").order("created_at", { ascending: true });
    if (error) setMessage("Die offenen Mitgliedsanträge konnten nicht geladen werden.");
    setRequests(data || []); setLoading(false);
  };

  useEffect(() => { loadRequests(); }, [club?.id]);

  const decide = async (request, nextStatus) => {
    setWorkingId(request.id); setMessage("");
    if (!supabase) {
      setMembers((items) => items.map((member) => member.id === request.id ? { ...member, accountPending: nextStatus !== "active", accountRejected: nextStatus === "blocked" } : member));
      setRequests((items) => items.filter((item) => item.id !== request.id));
      setMessage(nextStatus === "active" ? "Mitgliedschaft wurde freigegeben." : "Mitgliedschaft wurde abgelehnt.");
      setWorkingId(null); return;
    }
    /* Ablehnen heisst "diesmal nicht" - und stellt sich keiner neuen Anfrage in
       den Weg.

       Vorher setzte es den Status auf 'blocked'. register_for_club weist damit
       jede weitere Anfrage dauerhaft ab: Wer einmal abgelehnt wurde, kam nie
       wieder herein, auch nach Jahren nicht und ohne dass es jemandem auffiel.

       Jetzt geht die Mitgliedschaft auf 'inactive', blocked_until wird
       ausdruecklich geleert, und die Person kann sich sofort erneut bewerben -
       so oft sie moechte. Entschieden wird jedes Mal neu von der
       Vereinsleitung.

       rejection_count zaehlt weiter mit. Er sperrt nichts, er sagt der
       Vereinsleitung nur, dass hier schon einmal abgelehnt wurde.

       Wer wirklich draussen bleiben soll, laesst sich weiterhin auf 'blocked'
       setzen - dann aber als bewusste Entscheidung, nicht als Nebenwirkung
       eines Ablehnens. */
    const abgelehnt = nextStatus !== "active";
    const aenderung = abgelehnt
      ? {
          status: "inactive",
          rejection_count: (request.rejection_count || 0) + 1,
          blocked_until: null,
        }
      : { status: nextStatus, blocked_until: null };
    const { error: statusError } = await supabase.from("club_memberships").update(aenderung).eq("id", request.id).eq("club_id", club.id);
    /* Die Zugangsgrenze setzt ein Trigger in der Datenbank durch, damit sie auf
       jedem Weg greift. Er meldet sich mit "club_account_limit_reached" - ohne
       diese Uebersetzung stuende hier eine rohe Postgres-Meldung. */
    if (statusError) {
      const grenzeErreicht = `${statusError.message}${statusError.details || ""}`.includes("club_account_limit_reached");
      setMessage(grenzeErreicht
        /* Dieser Satz erscheint genau dann, wenn ein Verein an seine
           Zugangsgrenze stoesst - also im wichtigsten Moment. Er schickte den
           Vereinsadmin bisher zu "Abo & Empfehlungen", einem Bereich, den es
           seit dem Umbau nicht mehr gibt, und versprach dort eine Tarifliste,
           die dort bewusst nicht steht. Das kaufmaennische Und stand
           ausserdem als "&amp;" im Klartext auf dem Bildschirm. */
        ? "Die Zahl der Zugänge deines Vereins ist ausgeschöpft. Unter Profil → Einstellungen → Zugang & Empfehlungen kann die Vereinsleitung mehr Zugänge anfragen."
        : "Die Entscheidung konnte nicht gespeichert werden.");
      setWorkingId(null); return;
    }

    const requestedRoles = (request.membership_roles || []).map((entry) => entry.role);
    if (nextStatus === "active" && requestedRoles.includes("spieler") && request.requested_team) {
      const { data: team } = await supabase.from("teams").select("id").eq("club_id", club.id).eq("name", request.requested_team).maybeSingle();
      if (team) await supabase.from("team_members").upsert({ team_id: team.id, membership_id: request.id, function: "spieler" }, { onConflict: "team_id,membership_id,function" });
    }
    setRequests((items) => items.filter((item) => item.id !== request.id));
    setMessage(nextStatus === "active"
      ? "Mitgliedschaft wurde freigegeben."
      : "Mitgliedschaft wurde abgelehnt. Eine neue Anfrage ist jederzeit möglich.");
    setWorkingId(null);
  };

  return <div>
    <div className="rounded-2xl p-4 mb-4" style={{ background: C.primaerWeich, border: `1px solid ${C.edge}` }}>
      <div className="flex items-center justify-between gap-3">
        <div><div className="text-sm font-bold" style={{ color: C.ink }}>Offene Mitgliedsanträge</div><div className="text-[11px] mt-1" style={{ color: C.textDim }}>Nach der Freigabe kann sich das Mitglied sofort anmelden.</div></div>
        <span className="min-w-8 h-8 px-2 rounded-full flex items-center justify-center text-xs font-bold" style={{ background: C.glass, color: C.red }}>{requests.length}</span>
      </div>
    </div>
    {message && <div role="status" className="text-xs rounded-xl px-3 py-2.5 mb-3" style={{ background: message.includes("wurde") ? C.erfolgFlaeche : C.fehlerFlaeche, color: message.includes("wurde") ? C.erfolg : C.fehler }}>{message}</div>}
    {loading ? <div className="text-xs py-5 text-center" style={{ color: C.textDim }}>Mitgliedsanträge werden geladen …</div> : requests.length === 0 ?
      <div className="rounded-2xl p-5 text-center" style={{ background: C.glass, border: `1px solid ${C.line}` }}><CheckCircle2 size={24} className="mx-auto mb-2" style={{ color: C.secondary }}/><div className="text-sm font-bold">Keine offenen Anträge</div><div className="text-[11px] mt-1" style={{ color: C.textDim }}>Neue Registrierungen erscheinen automatisch hier.</div></div> :
      <div className="space-y-3">{requests.map((request) => {
        const roles = (request.membership_roles || []).map((entry) => ROLE_META[entry.role]?.label || entry.role);
        return <div key={request.id} className="rounded-2xl p-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          <div className="flex items-start gap-3 mb-3"><div className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-bold" style={{ background: C.red, color: C.white }}>{initialsOf(request.display_name)}</div><div className="min-w-0"><div className="text-sm font-bold truncate" style={{ color: C.ink }}>{request.display_name}</div><div className="text-[11px] truncate" style={{ color: C.textDim }}>{request.email || "Keine E-Mail hinterlegt"}</div></div></div>
          <div className="grid grid-cols-2 gap-2 mb-3"><div className="rounded-xl px-3 py-2" style={{ background: C.paperDim }}><div className="text-[9px] uppercase tracking-wider" style={{ color: C.textDim }}>Registrierung</div><div className="text-xs font-bold mt-0.5">{roles.filter((role) => role !== "Mitglied").join(", ") || "Mitglied"}</div></div><div className="rounded-xl px-3 py-2" style={{ background: C.paperDim }}><div className="text-[9px] uppercase tracking-wider" style={{ color: C.textDim }}>Mannschaft</div><div className="text-xs font-bold mt-0.5">{request.requested_team || "Noch offen"}</div></div></div>
          <div className="flex gap-2"><button disabled={workingId === request.id} onClick={() => decide(request, "active")} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.secondary, color: C.white, opacity: workingId === request.id ? .6 : 1 }}>Freigeben</button><button disabled={workingId === request.id} onClick={() => decide(request, "blocked")} className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.fehlerFlaeche, color: C.fehler, opacity: workingId === request.id ? .6 : 1 }}>Ablehnen</button></div>
        </div>;
      })}</div>}
    <button onClick={loadRequests} disabled={loading} className="w-full mt-3 py-2.5 rounded-xl text-xs font-bold" style={{ background: C.paperDim, color: C.textDim }}>Liste aktualisieren</button>

    <button onClick={() => setShowActive((v) => !v)} className="w-full flex items-center justify-between mt-6 mb-3">
      <div className="text-sm font-bold" style={{ color: C.ink }}>Mitgliedschaften verwalten</div>
      <ChevronRight size={15} style={{ color: C.textDim, transform: showActive ? "rotate(90deg)" : "none", transition: "transform .15s" }}/>
    </button>
    {showActive && (loadingActive ? <div className="text-xs py-4 text-center" style={{ color: C.textDim }}>Mitglieder werden geladen …</div> : (
      <div className="space-y-2">
        {nichtGesperrte.map((member) => (
          <div key={member.id} className="flex items-center gap-2 flex-wrap rounded-xl px-3 py-2.5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
            <div className="flex-1 min-w-0" style={{ minWidth: 140 }}>
              <div className="text-xs font-bold truncate" style={{ color: C.ink }}>{member.display_name}</div>
              <div className="text-[10px] truncate" style={{ color: C.textDim }}>{member.email || "Keine E-Mail hinterlegt"}</div>
            </div>
            <span className="text-[9px] font-bold px-2 py-1 rounded-full flex-shrink-0" style={{ background: member.status === "active" ? C.erfolgFlaeche : C.fehlerFlaeche, color: member.status === "active" ? C.erfolg : C.fehler }}>{member.status === "active" ? "Aktiv" : member.status === "blocked" ? "Gesperrt" : "Inaktiv"}</span>
            {/* Gesperrte bekommen nur den Weg zurueck. Fuer alle anderen steht
                neben dem Beenden das Sperren - der einzige Weg, jemanden
                dauerhaft draussen zu halten. */}
            {member.status === "blocked"
              ? <button disabled={workingId === member.id} onClick={() => unblockMember(member)} className="px-3 py-1.5 rounded-lg text-[10px] font-bold flex-shrink-0" style={{ background: C.erfolgFlaeche, color: C.erfolg, opacity: workingId === member.id ? .6 : 1 }}>Entsperren</button>
              : <>
                  <button disabled={workingId === member.id} onClick={() => toggleMemberActive(member)} className="px-3 py-1.5 rounded-lg text-[10px] font-bold flex-shrink-0" style={{ background: member.status === "active" ? C.fehlerFlaeche : C.erfolgFlaeche, color: member.status === "active" ? C.fehler : C.erfolg, opacity: workingId === member.id ? .6 : 1 }}>{member.status === "active" ? "Beenden" : "Reaktivieren"}</button>
                  <button disabled={workingId === member.id} onClick={() => blockMember(member)} title="Sperren — kann sich nicht mehr bewerben" className="px-2.5 py-1.5 rounded-lg text-[10px] font-bold flex-shrink-0" style={{ background: C.fehlerFlaeche, color: C.fehler, opacity: workingId === member.id ? .6 : 1 }}>Sperren</button>
                </>}
            {/* Zwei getrennte Wege, bewusst unterschiedlich gewichtet:
                "Beenden" legt die Mitgliedschaft still und laesst sie in der
                Historie - das ist der Regelfall. "Entfernen" loescht sie
                endgueltig und steht deshalb unauffaelliger daneben. */}
            <button disabled={workingId === member.id} onClick={() => removeMember(member)} title="Endgültig aus dem Verein entfernen" className="px-2.5 py-1.5 rounded-lg text-[10px] font-bold flex-shrink-0" style={{ background: C.paperDim, color: C.textDim, opacity: workingId === member.id ? .6 : 1 }}>Entfernen</button>
          </div>
        ))}
        {nichtGesperrte.length === 0 && <div className="text-xs rounded-xl p-3" style={{ background: C.paperDim, color: C.textDim }}>Keine Mitgliedschaften vorhanden.</div>}
      </div>
    ))}

    {/* Die Sperrliste des Vereins. Sie ist kein eigener Datenbestand, sondern
        die Mitgliedschaften mit Status 'blocked' - genau die, an denen
        register_for_club eine neue Beitrittsanfrage abweist.

        Der Abschnitt erscheint nur, wenn wirklich jemand gesperrt ist. Eine
        dauerhaft sichtbare leere Liste waere eine Uebersicht ueber nichts. */}
    {gesperrte.length > 0 && (
      <div className="mt-6">
        <div className="flex items-center gap-2 mb-1">
          <Lock size={14} style={{ color: C.red }} />
          <div className="text-sm font-bold" style={{ color: C.ink }}>Sperrliste</div>
          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{gesperrte.length}</span>
        </div>
        <div className="text-[11px] mb-3" style={{ color: C.textDim }}>
          Diese Personen haben keinen Zugang und können auch keine neue Beitrittsanfrage stellen. Beim Entsperren gilt die Mitgliedschaft wieder als beendet — über eine erneute Aufnahme entscheidet ihr neu.
        </div>
        <div className="space-y-2">
          {gesperrte.map((member) => (
            <div key={member.id} className="flex items-center gap-2 flex-wrap rounded-xl px-3 py-2.5" style={{ background: C.fehlerFlaeche, border: `1px solid ${C.line}` }}>
              <div className="flex-1 min-w-0" style={{ minWidth: 140 }}>
                <div className="text-xs font-bold truncate" style={{ color: C.ink }}>{member.display_name}</div>
                <div className="text-[10px] truncate" style={{ color: C.textDim }}>{member.email || "Keine E-Mail hinterlegt"}</div>
              </div>
              <button disabled={workingId === member.id} onClick={() => unblockMember(member)} className="px-3 py-1.5 rounded-lg text-[10px] font-bold flex-shrink-0" style={{ background: C.erfolgFlaeche, color: C.erfolg, opacity: workingId === member.id ? .6 : 1 }}>Entsperren</button>
              <button disabled={workingId === member.id} onClick={() => removeMember(member)} title="Endgültig aus dem Verein entfernen" className="px-2.5 py-1.5 rounded-lg text-[10px] font-bold flex-shrink-0" style={{ background: C.paperDim, color: C.textDim, opacity: workingId === member.id ? .6 : 1 }}>Entfernen</button>
            </div>
          ))}
        </div>
      </div>
    )}
  </div>;
}

function ClubFeatureOnboarding({ club, onDone }) {
  const [step, setStep] = useState(0);
  const [saving, setSaving] = useState(false);
  const [fehler, setFehler] = useState("");
  const sport = club?.sport || "rollhockey";
  const cfg = sportConfig(sport);
  const feature = CLUB_FEATURES[step];
  const answersRef = useRef({});
  const finish = async (finalAnswers) => {
    setSaving(true); setFehler("");
    if (supabase && club?.id) {
      /* Das Ergebnis wurde verworfen und onDone() lief in jedem Fall. Schlug
         das Speichern fehl, war der Assistent durch, der Verein glaubte seine
         Auswahl sei hinterlegt - und beim naechsten Oeffnen stand wieder
         alles auf Vorgabe. Hier bleibt das Fenster jetzt offen. */
      const { error } = await supabase.from("club_feature_toggles").upsert(
        CLUB_FEATURES.map((f) => ({ club_id: club.id, feature_key: f.key, enabled: finalAnswers[f.key] !== false }))
      );
      if (error) {
        setSaving(false);
        setFehler("Die Auswahl konnte nicht gespeichert werden. Prüfe deine Verbindung und versuche es noch einmal.");
        return;
      }
    }
    setSaving(false);
    onDone();
  };
  const answer = (value) => {
    answersRef.current = { ...answersRef.current, [feature.key]: value };
    if (step + 1 < CLUB_FEATURES.length) { setStep(step + 1); return; }
    finish(answersRef.current);
  };
  return (
    <div className="flex flex-col h-full items-center justify-center p-5" style={{ background: C.paper }}>
      <div className="w-full max-w-sm">
        <div className="text-[10px] uppercase tracking-widest font-bold mb-1" style={{ color: C.red, fontFamily: "Inter" }}>Verein einrichten · {cfg.label}</div>
        <div className="text-xl mb-1" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>Welche Funktionen braucht ihr?</div>
        {fehler && <div role="alert" className="text-[11px] rounded-xl px-3 py-2 mb-3" style={{ background: C.fehlerFlaeche, color: C.fehler, fontFamily: "Inter" }}>{fehler}</div>}
        <div className="text-xs mb-6" style={{ color: C.textDim, fontFamily: "Inter" }}>Frage {step + 1} von {CLUB_FEATURES.length} — lässt sich jederzeit in den Vereinseinstellungen unter „Funktionen“ ändern.</div>
        <div className="rounded-2xl p-5 mb-5" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
          <div className="text-sm font-bold mb-2" style={{ color: C.ink, fontFamily: "Inter" }}>{feature.label(sport)}</div>
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>{feature.question(sport)}</div>
        </div>
        <div className="flex gap-2">
          <button onClick={() => answer(false)} disabled={saving} className="flex-1 py-3 rounded-xl text-sm font-bold" style={{ background: C.paperDim, color: C.textDim, opacity: saving ? .6 : 1 }}>Nein</button>
          <button onClick={() => answer(true)} disabled={saving} className="flex-1 py-3 rounded-xl text-sm font-bold" style={{ background: C.ink, color: C.white, opacity: saving ? .6 : 1 }}>{saving ? "…" : "Ja"}</button>
        </div>
        <div className="flex gap-1.5 justify-center mt-5">
          {CLUB_FEATURES.map((f, i) => <span key={f.key} className="h-1.5 rounded-full" style={{ width: i === step ? 20 : 8, background: i <= step ? C.red : C.line, transition: "width .2s" }}/>)}
        </div>
      </div>
    </div>
  );
}

function ClubRoleOverviewPanel({ members }) {
  const [expandedRole, setExpandedRole] = useState(null);
  const [selectedMember, setSelectedMember] = useState(null);
  return (
    <div className="mb-6">
      <SectionTitle eyebrow="Überblick" title="Rollen im Verein" />
      <div className="text-xs mb-3 -mt-2" style={{ color: C.textDim }}>Nur-Lese-Übersicht, wer welche Rolle in diesem Verein hat. Auf ein Mitglied tippen öffnet das Profil.</div>
      <div className="space-y-2">
        {ROLE_OVERVIEW_KEYS.map((roleKey) => {
          const holders = members.filter((m) => m.roles.includes(roleKey)).sort((a, b) => a.name.localeCompare(b.name, "de"));
          const open = expandedRole === roleKey;
          return (
            <div key={roleKey} className="rounded-2xl overflow-hidden" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
              <button className="w-full text-left px-3.5 py-3 flex items-center justify-between" onClick={() => setExpandedRole(open ? null : roleKey)}>
                <div className="flex items-center gap-2">
                  <Pill bg={ROLE_META[roleKey]?.color}>{ROLE_META[roleKey]?.label}</Pill>
                  <span className="text-[11px] font-bold" style={{ color: C.textDim }}>{holders.length}</span>
                </div>
                <ChevronDown size={15} style={{ color: C.textDim, transform: open ? "rotate(180deg)" : "none", transition: "transform .2s" }} />
              </button>
              {open && (
                <div className="px-3.5 pb-3.5">
                  {holders.length === 0 ? (
                    <div className="text-[11px]" style={{ color: C.textDim }}>Niemand hat aktuell diese Rolle.</div>
                  ) : (
                    <div className="space-y-1.5">
                      {holders.map((m) => (
                        <button key={m.id} onClick={() => setSelectedMember(m)} className="w-full flex items-center gap-2.5 rounded-xl px-2.5 py-2 text-left" style={{ background: C.paperDim }}>
                          <div className="w-7 h-7 rounded-full flex items-center justify-center text-[9px] font-bold flex-shrink-0" style={{ background: m.color, color: C.white }}>{initialsOf(m.name)}</div>
                          <span className="text-xs font-bold flex-1 truncate" style={{ color: C.ink }}>{m.name}</span>
                          <ChevronRight size={13} style={{ color: C.textDim }} />
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
      {selectedMember && <MemberDetailPanel member={selectedMember} onClose={() => setSelectedMember(null)} />}
    </div>
  );
}

function ClubFeatureSettingsPanel({ currentClub, clubFeatures, onFeaturesChanged, dashboardTileOrder, setDashboardTileOrder }) {
  const sport = currentClub?.sport || "rollhockey";
  const [saving, setSaving] = useState("");
  const [message, setMessage] = useState("");
  const toggle = async (key, value) => {
    if (!supabase || !currentClub?.id) return;
    setSaving(key); setMessage("");
    const { error } = await supabase.from("club_feature_toggles").upsert({ club_id: currentClub.id, feature_key: key, enabled: value });
    setSaving("");
    if (error) { setMessage("Konnte nicht gespeichert werden."); return; }
    onFeaturesChanged();
  };
  const order = resolveDashboardTileOrder(dashboardTileOrder);
  const moveTile = (index, dir) => {
    const target = index + dir;
    if (target < 0 || target >= order.length || !setDashboardTileOrder) return;
    const next = [...order];
    [next[index], next[target]] = [next[target], next[index]];
    setDashboardTileOrder(next);
  };
  /* Ein Eintrag je Dashboard-Kachel: an/aus und Position in einer Karte. Die Liste
     folgt der Dashboard-Reihenfolge, damit die Nummer auch das ist, was der Nutzer
     später sieht. "Aufgaben" hat bewusst keinen Schalter — die Funktion lässt sich
     nicht abschalten, deshalb steht dort ein Hinweis statt eines toten Schalters. */
  const featureByKey = Object.fromEntries(CLUB_FEATURES.map((f) => [f.key, f]));

  return (
    <div>
      <SectionTitle eyebrow={sportConfig(sport).label} title="Funktionen & Reihenfolge" />
      <div className="text-xs mb-4 -mt-2" style={{ color: C.textDim }}>Lege je Funktion fest, ob ihr sie nutzt und an welcher Stelle sie unter „Aktionen &amp; Abstimmungen“ auf dem Dashboard erscheint. Abgeschaltete Funktionen sind für alle Mitglieder ausgeblendet.</div>
      {message && <div role="status" className="text-[11px] rounded-xl px-3 py-2 mb-4" style={{ background: C.fehlerFlaeche, color: C.fehler }}>{message}</div>}

      <div className="space-y-2.5">
        {order.map((key, index) => {
          const feature = featureByKey[key];
          const abschaltbar = !!feature;
          const an = abschaltbar ? clubFeatures[key] !== false : true;
          const beschreibung = abschaltbar ? feature.settingsDesc(sport) : "Aufgaben für den Verein verteilen und abhaken.";
          return (
            <div key={key} className="rounded-2xl px-3.5 py-3" style={{ background: C.glass, border: `1px solid ${C.edge}`, boxShadow: "0 10px 26px rgba(60,30,45,0.06)", opacity: an ? 1 : 0.66 }}>
              <div className="flex items-center gap-3">
                <span className="w-7 h-7 rounded-lg flex items-center justify-center text-[11px] flex-shrink-0" style={{ fontFamily: "JetBrains Mono", fontWeight: 700, background: an ? `color-mix(in srgb, ${C.red} 14%, transparent)` : C.paperDim, color: an ? C.red : C.textDim }}>{index + 1}</span>
                <span className="flex-1 min-w-0 text-sm font-bold truncate" style={{ color: C.ink }}>{dashboardTileLabel(key, sport)}</span>
                {abschaltbar ? (
                  <button onClick={() => saving !== key && toggle(key, !an)} aria-label={`${dashboardTileLabel(key, sport)} ${an ? "abschalten" : "einschalten"}`} className="w-10 h-6 rounded-full relative flex-shrink-0" style={{ background: an ? C.secondary : C.paperDim, opacity: saving === key ? 0.5 : 1 }}>
                    <span className="absolute top-0.5 w-5 h-5 rounded-full" style={{ background: "#fff", left: an ? 18 : 2, transition: "left .2s" }} />
                  </button>
                ) : (
                  <span className="text-[9px] font-bold px-2 py-1 rounded-full flex-shrink-0" style={{ background: C.paperDim, color: C.textDim }}>IMMER AKTIV</span>
                )}
              </div>
              <div className="flex items-end gap-2 mt-2">
                <span className="flex-1 text-[11px] leading-snug" style={{ color: C.textDim }}>{beschreibung}</span>
                <button aria-label="Nach oben verschieben" onClick={() => moveTile(index, -1)} disabled={index === 0} className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: C.paperDim, opacity: index === 0 ? .35 : 1 }}><ChevronUp size={15} style={{ color: C.ink }}/></button>
                <button aria-label="Nach unten verschieben" onClick={() => moveTile(index, 1)} disabled={index === order.length - 1} className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: C.paperDim, opacity: index === order.length - 1 ? .35 : 1 }}><ChevronDown size={15} style={{ color: C.ink }}/></button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* Platzhalter-Spieler (ohne Konto, z. B. Kindermannschaften) später mit ihrem
   eigenen echten Konto zusammenführen. Rollen/Mannschaften/Familienverknüpfungen
   wandern über, das Platzhalter-Profil wird danach entfernt. Siehe
   claim_managed_membership() in Supabase. */
function ClaimManagedPlayerPanel({ members, setMembers, currentUser }) {
  const [managedId, setManagedId] = useState("");
  const [realId, setRealId] = useState("");
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const managedCandidates = members.filter((m) => m.accountPending);
  const realCandidates = members.filter((m) => !m.accountPending);
  const managed = members.find((m) => m.id === managedId);
  const suggestions = managed ? realCandidates.filter((m) => m.name.trim().toLowerCase() === managed.name.trim().toLowerCase()) : [];

  const merge = async () => {
    if (!managedId || !realId || managedId === realId) return;
    setSaving(true); setMessage("");
    if (supabase && isDbId(managedId) && isDbId(realId)) {
      const { error } = await supabase.rpc("claim_managed_membership", {
        target_club: currentUser.clubId, managed_membership_id: managedId, new_membership_id: realId,
      });
      if (error) { setMessage("Die Profile konnten nicht zusammengeführt werden."); setSaving(false); return; }
    }
    setMembers((ms) => {
      const src = ms.find((m) => m.id === managedId);
      if (!src) return ms.filter((m) => m.id !== managedId);
      return ms.filter((m) => m.id !== managedId).map((m) => m.id === realId ? {
        ...m,
        roles: [...new Set([...m.roles, ...src.roles])],
        playerTeams: [...new Set([...(m.playerTeams || []), ...(src.playerTeams || [])])],
        teams: [...new Set([...(m.teams || []), ...(src.teams || [])])],
      } : m);
    });
    setManagedId(""); setRealId(""); setMessage("Profile wurden zusammengeführt."); setSaving(false);
  };

  if (!managedCandidates.length) return null;

  return (
    <div className="rounded-2xl p-3.5 mt-4" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
      <div className="text-sm mb-1" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Profile ohne Konto zusammenführen</div>
      <div className="text-[11px] mb-3" style={{ color: C.textDim }}>Wenn ein ohne Konto angelegter Spieler (z. B. aus einer Kindermannschaft) später sein eigenes Konto registriert, hier das Platzhalter-Profil mit dem neuen echten Konto verknüpfen.</div>
      {message && <div className="rounded-xl px-3 py-2 text-[11px] font-semibold mb-2" style={{ background: message.includes("nicht") ? C.fehlerFlaeche : C.erfolgFlaeche, color: message.includes("nicht") ? C.fehler : C.erfolg }}>{message}</div>}
      <select value={managedId} onChange={(e) => { setManagedId(e.target.value); setRealId(""); setMessage(""); }} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim }}>
        <option value="">Platzhalter-Profil (ohne Konto) …</option>
        {managedCandidates.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
      </select>
      {managed && (
        <select value={realId} onChange={(e) => setRealId(e.target.value)} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{ background: C.paperDim }}>
          <option value="">Echtes Konto auswählen …</option>
          {suggestions.length > 0 && <optgroup label="Vorschlag · Name stimmt überein">{suggestions.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}</optgroup>}
          <optgroup label="Alle Mitglieder">{realCandidates.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}</optgroup>
        </select>
      )}
      <button type="button" disabled={!managedId || !realId || saving} onClick={merge} className="w-full py-2.5 rounded-xl text-xs font-bold" style={{ background: (managedId && realId) ? C.ink : C.line, color: C.white }}>{saving ? "Wird zusammengeführt …" : "Zusammenführen"}</button>
    </div>
  );
}

function AdminView({
  members, setMembers, events, feePaid, setFeePaid, dutyPlan, setDutyPlan, seasonVotes, currentUser,
  channels, setChannels, maintenanceMode, setMaintenanceMode, onResetDemo,
  protocols, setProtocols, remindersSent, setRemindersSent,
  welcomeAutomation, setWelcomeAutomation, billingAutomation, setBillingAutomation,
  werbeplaetze, onWerbeplaetzeGeaendert, polls, setPolls, tippResults, onSaveTippResult,
  dashboardTileOrder, setDashboardTileOrder,
  onUmfrageAnlegen, onUmfrageUmschalten, onDienstSetzen, onProtokollSpeichern, onAufgabeUmschalten,
  onEinstellung, onErinnerung,
  currentClub, onClubLogoUpdated, onClubColorsUpdated, clubFeatures, onClubFeaturesChanged,
}) {
  const canManageClubFeatures = currentUser.roles.some((role) => ["vereinsadmin", "vorstand", "sysadmin"].includes(role));
  const dutyFeatureOn = clubFeatures?.duty_roster !== false;
  const dutyCfg = sportConfig(currentClub?.sport);
  const canSponsor = canManageSponsors(currentUser);
  const canDutyTemplates = dutyFeatureOn && !isAdmin(currentUser) && currentUser.roles.includes("organisator");
  const sponsorOnly = !isAdmin(currentUser) && canSponsor && !canDutyTemplates;
  const restrictedOnly = !isAdmin(currentUser) && (canSponsor || canDutyTemplates);
  const canSeeFees = canManageFees(currentUser);
  const restrictedPanels = [
    ...(canSponsor ? [["sponsoring", "Sponsoring"]] : []),
    ...(canDutyTemplates ? [["duty-templates", `${dutyCfg.dutyTabLabel}-Sätze`]] : []),
    ["polls", "Umfragen"],
  ];
  const [panel, setPanel] = useState(restrictedOnly ? restrictedPanels[0][0] : "overview");
  const openCount = members.filter((m) => !feePaid[m.id]).length;
  const panels = restrictedOnly ? restrictedPanels : [["overview", "Übersicht"], ["automation", "Automatisierung"], ...(dutyFeatureOn ? [["duty", "Helferplanung"], ["duty-templates", `${dutyCfg.dutyTabLabel}-Sätze`]] : []), ["protokolle", "Protokolle"], ["polls", "Umfragen"], ...(SPONSOREN_VERWALTUNG_SICHTBAR ? [["sponsoring", "Sponsoring"]] : []), ["season", "Athlet/in der Saison"]];
  if (currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role))) panels.push(["roles", "Rollen"]);
  if (currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role))) panels.splice(1, 0, ["memberships", "Mitgliedsanträge"]);
  if (currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role))) panels.splice(1, 0, ["clubprofile", "Vereinsprofil"]);
  if (canManageClubFeatures) panels.splice(1, 0, ["functions", "Funktionen"]);
  if (currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role))) panels.splice(1, 0, ["results", "Spielergebnisse"]);
  if (isSysAdmin(currentUser)) panels.push(["families", "Familienprofile"], ["system", "System"]);

  return (
    <div className="px-4 pt-4 pb-24">
      <SectionTitle title={restrictedOnly ? (sponsorOnly ? "Sponsorenmanager" : `${dutyCfg.dutyTabLabel}-Organisator`) : "Verwaltung"} eyebrow={restrictedOnly ? (sponsorOnly ? "Anzeigen & Kampagnen" : "Sätze & Stationen") : "Vorstand"} />
      {!restrictedOnly && <div className="rounded-2xl p-4 mb-5 flex items-center gap-3" style={{ background: C.ink }}>
        <ShieldCheck size={22} style={{ color: C.secondary }} />
        <div>
          <div className="text-white text-sm" style={{ fontFamily: "Inter", fontWeight: 700 }}>{members.length} Mitglieder</div>
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>{canSeeFees ? `${openCount} Beiträge noch offen` : "Vereinsverwaltung"}</div>
        </div>
      </div>}

      <div className="flex gap-2 mb-4 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {panels.map(([k, l]) => (
          <button key={k} onClick={() => setPanel(k)} className="px-3 py-1.5 rounded-full text-xs flex-shrink-0"
            style={{ fontFamily: "Inter", fontWeight: 700, background: panel === k ? C.ink : C.paperDim, color: panel === k ? C.white : C.textDim }}>{l}</button>
        ))}
      </div>

      {panel === "overview" && <OverviewPanel members={members} events={events} feePaid={feePaid} protocols={protocols} dutyPlan={dutyPlan} seasonVotes={seasonVotes} goPanel={setPanel} showFees={canSeeFees} />}
      {panel === "memberships" && currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role)) && <MembershipApprovalsPanel club={currentClub} members={members} setMembers={setMembers} />}
      {panel === "clubprofile" && currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role)) && <><ClubLogoPanel club={currentClub} onLogoUpdated={onClubLogoUpdated} /><ClubColorPanel club={currentClub} onColorsUpdated={onClubColorsUpdated} /></>}

      {panel === "automation" && (
        <AutomationsPanel members={members} feePaid={feePaid} remindersSent={remindersSent} setRemindersSent={setRemindersSent}
          welcomeAutomation={welcomeAutomation} setWelcomeAutomation={setWelcomeAutomation}
          billingAutomation={billingAutomation} setBillingAutomation={setBillingAutomation}
          onEinstellung={onEinstellung} onErinnerung={onErinnerung} />
      )}

      {panel === "duty" && dutyFeatureOn && <AdminDutyPanel members={members} events={events} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} onSetzen={onDienstSetzen} />}
      {panel === "duty-templates" && <DutyTemplatesPanel currentUser={currentUser} sport={currentClub?.sport} />}
      {panel === "functions" && canManageClubFeatures && <ClubFeatureSettingsPanel currentClub={currentClub} clubFeatures={clubFeatures} onFeaturesChanged={onClubFeaturesChanged} dashboardTileOrder={dashboardTileOrder} setDashboardTileOrder={setDashboardTileOrder} />}
      {panel === "protokolle" && <ProtokollePanel members={members} protocols={protocols} setProtocols={setProtocols} clubId={currentUser.clubId} onSpeichern={onProtokollSpeichern} onAufgabe={onAufgabeUmschalten} />}
      {panel === "sponsoring" && <SponsoringPanel bookings={werbeplaetze} currentClub={currentClub} clubFeatures={clubFeatures} onFeaturesChanged={onClubFeaturesChanged} onChanged={onWerbeplaetzeGeaendert} />}
      {panel === "polls" && <PollManagerPanel polls={polls} setPolls={setPolls} clubId={currentUser.clubId} onAnlegen={onUmfrageAnlegen} onUmschalten={onUmfrageUmschalten} />}
      {panel === "roles" && <><RolesPanel members={members} setMembers={setMembers} /><ClaimManagedPlayerPanel members={members} setMembers={setMembers} currentUser={currentUser} /></>}
      {panel === "results" && currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role)) && <MatchResultsPanel results={tippResults} onSave={onSaveTippResult} events={events} />}
      {panel === "families" && isSysAdmin(currentUser) && <AdminFamilyPanel members={members} setMembers={setMembers} />}
      {panel === "system" && isSysAdmin(currentUser) && (
        <SystemPanel members={members} channels={channels} setChannels={setChannels} maintenanceMode={maintenanceMode} setMaintenanceMode={setMaintenanceMode} onResetDemo={onResetDemo} onEinstellung={onEinstellung} />
      )}

      {panel === "season" && (() => {
        const { counts, total, sorted } = seasonResults(seasonVotes, saisonKandidaten(members));
        return (
          <div>
            <div className="text-xs mb-3" style={{ color: C.textDim, fontFamily: "Inter" }}>Nur für den Vorstand sichtbar — {total} Stimmen bisher.</div>
            {sorted.length === 0 && (
              <div className="rounded-2xl p-4 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>
                Für diese Wahl sind noch keine Kandidat/innen hinterlegt.
              </div>
            )}
            <div className="space-y-2">
              {sorted.map((c, i) => {
                const pct = total ? Math.round((counts[c.id] / total) * 100) : 0;
                return (
                  <div key={c.id} className="relative overflow-hidden rounded-xl" style={{ border: `1px solid ${C.line}` }}>
                    <div className="absolute inset-y-0 left-0" style={{ width: `${pct}%`, background: i === 0 ? C.fehlerFlaeche : C.paperDim }} />
                    <div className="relative flex items-center justify-between px-3.5 py-2.5">
                      <span className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{c.name}</span>
                      <span className="text-xs" style={{ fontFamily: "JetBrains Mono", color: C.textDim }}>{pct}% · {counts[c.id]}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        );
      })()}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* App shell                                                            */
/* ------------------------------------------------------------------ */
function baseTabs(isAdminUser, canEditNews, canEditSponsors, canManageFees, canManageDutyUser) {
  const tabs = [
    { id: "home", label: "Home", icon: Home },
    { id: "events", label: "Termine", icon: CalendarDays },
    { id: "teams", label: "Teams", icon: Users },
    { id: "chat", label: "Chat", icon: MessageCircle },
    { id: "profile", label: "Profil", icon: User },
  ];
  if (canManageFees) tabs.splice(tabs.findIndex((tab) => tab.id === "chat"), 0, { id: "fees", label: "Beiträge", icon: Wallet });
  if (canEditNews) tabs.splice(tabs.findIndex((tab) => tab.id === "chat"), 0, { id: "redaktion", label: "Redaktion", icon: Newspaper });
  if (isAdminUser || canEditSponsors || canManageDutyUser) tabs.splice(tabs.findIndex((tab) => tab.id === "profile"), 0, { id: "admin", label: canEditSponsors && !isAdminUser ? "Sponsoren" : "Verwaltung", icon: ShieldCheck });
  return tabs;
}
const SUBVIEW_TITLES = { season: "Athlet/in der Saison", tipp: "Tippspiel", duty: "Helferplanung", postfach: "Benachrichtigungen" };

/* Das Postfach.
 *
 * user_notifications fuellte sich seit Wochen - jeder angelegte oder geaenderte
 * Termin, jede News, jedes Protokoll, jede Umfrage schreibt Zeilen fuer den
 * betroffenen Kreis. Gelesen hat sie niemand: In der ganzen App gab es keine
 * Stelle, die diese Tabelle abfragt. In den Einstellungen konnte man derweil
 * auswaehlen, worueber man benachrichtigt werden moechte.
 *
 * Bewusst kein eigener Reiter unten: Das Postfach ist etwas, das man aufmacht,
 * wenn die Glocke etwas anzeigt - keine Ansicht, in der man sich aufhaelt. */
function PostfachView({ eintraege, laedt, onGelesen, onLoeschen }) {
  const zeit = (wert) => {
    const d = new Date(wert);
    const minuten = Math.round((Date.now() - d.getTime()) / 60000);
    if (minuten < 60) return `vor ${Math.max(1, minuten)} Min.`;
    if (minuten < 1440) return `vor ${Math.round(minuten / 60)} Std.`;
    return d.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "2-digit" });
  };
  const ungelesen = eintraege.filter((e) => !e.read_at).length;

  if (laedt) return <div className="px-4 pt-4 text-xs" style={{ color: C.textDim }}>Wird geladen …</div>;

  return (
    <div className="px-4 pt-4 pb-24">
      {ungelesen > 0 && (
        <button onClick={onGelesen} className="w-full py-2.5 rounded-xl text-xs font-bold mb-3"
          style={{ background: C.paperDim, color: C.ink }}>
          Alle {ungelesen} als gelesen markieren
        </button>
      )}
      {eintraege.length === 0 ? (
        <div className="rounded-2xl p-5 text-center" style={{ background: C.paperDim }}>
          <Bell size={22} style={{ color: C.textDim, margin: "0 auto 10px" }} />
          <div className="text-sm font-bold mb-1" style={{ color: C.ink, fontFamily: "Inter" }}>Noch nichts da</div>
          <div className="text-[11px] leading-snug" style={{ color: C.textDim, fontFamily: "Inter" }}>
            Hier landen neue Termine, News, Umfragen und alles, wofür du in den Einstellungen
            Benachrichtigungen eingeschaltet hast.
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          {eintraege.map((e) => (
            <div key={e.id} className="rounded-2xl p-3.5 flex gap-3"
                 style={{ background: e.read_at ? C.paperDim : C.glass, border: `1px solid ${e.read_at ? "transparent" : C.edge}` }}>
              {!e.read_at && <span className="w-2 h-2 rounded-full flex-shrink-0 mt-1.5" style={{ background: C.red }} />}
              <div className="flex-1 min-w-0">
                <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{e.title}</div>
                {e.body && <div className="text-[11px] mt-0.5 leading-relaxed" style={{ color: C.textDim }}>{e.body}</div>}
                <div className="text-[10px] mt-1" style={{ color: C.textDim }}>{zeit(e.created_at)}</div>
              </div>
              <button onClick={() => onLoeschen(e.id)} aria-label="Entfernen"
                className="w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0" style={{ color: C.textDim }}>
                <X size={13} />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* Was der Browser zu sehen bekommt, wenn NEXT_PUBLIC_NUR_APP=1 gesetzt ist.
   Bewusst schlicht und ohne Anmeldung: Diese Seite ist kein Zugang, sondern
   ein Wegweiser in den Store. */
/* Was zu sehen ist, wenn die Datenbank nicht eingerichtet ist.
   Bewusst nuechtern und ohne Anmeldung: Hier ist nichts zu bedienen, hier ist
   etwas zu reparieren. */
function KonfigurationFehlt() {
  return (
    <div className="min-h-screen w-full flex items-center justify-center px-6" style={{ background: C.paper, fontFamily: "Inter" }}>
      <div className="w-full max-w-sm text-center">
        <AppBrandMark size={56} />
        <div className="text-lg mt-5 mb-2" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>Die App ist nicht einsatzbereit</div>
        <p className="text-sm leading-relaxed" style={{ color: C.textDim }}>
          Die Verbindung zur Vereinsdatenbank fehlt. Es werden keine Daten angezeigt und keine
          gespeichert. Bitte später noch einmal versuchen — wir sind informiert.
        </p>
      </div>
    </div>
  );
}

function NurAlsAppHinweis() {
  const appStore = process.env.NEXT_PUBLIC_APP_STORE_URL;
  const playStore = process.env.NEXT_PUBLIC_PLAY_STORE_URL;
  return (
    <div className="min-h-screen w-full flex items-center justify-center px-6" style={{ background: C.paper, fontFamily: "Inter" }}>
      <div className="w-full max-w-sm text-center">
        <div className="mx-auto mb-6 flex items-center justify-center" style={{ width: 76, height: 76, borderRadius: 24, background: "rgba(255,255,255,0.72)", border: "1px solid rgba(255,255,255,0.85)" }}>
          <AppBrandMark size={46} />
        </div>
        <h1 className="text-xl mb-2" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>Club Member Organisation</h1>
        <p className="text-xs mb-7 leading-relaxed" style={{ color: C.textDim }}>
          Die Vereins-App gibt es als App fürs Smartphone. Lade sie im Store,
          melde dich dort an, und dein Verein ist sofort verfügbar.
        </p>
        <div className="space-y-2 mb-8">
          {appStore && <a href={appStore} className="block py-3 rounded-2xl text-sm font-bold" style={{ background: C.ink, color: C.white }}>Im App Store laden</a>}
          {playStore && <a href={playStore} className="block py-3 rounded-2xl text-sm font-bold" style={{ background: C.glass, border: `1px solid ${C.edge}`, color: C.ink }}>Bei Google Play laden</a>}
          {!appStore && !playStore && <div className="text-[11px] rounded-2xl px-4 py-3" style={{ background: C.paperDim, color: C.textDim }}>Die App wird gerade veröffentlicht. Die Store-Links erscheinen hier, sobald sie verfügbar sind.</div>}
        </div>
        <div className="flex items-center justify-center gap-4 text-[11px]" style={{ color: C.textDim }}>
          <a href="/nutzungsbedingungen" className="underline">Nutzungsbedingungen</a>
          <a href="/datenschutz" className="underline">Datenschutz</a>
          <a href="/impressum" className="underline">Impressum</a>
        </div>
      </div>
    </div>
  );
}

export default function ClubMemberOrganisationApp() {
  const [clubs, setClubs] = useState(INITIAL_CLUBS);
  /* Erst nach dem ersten Rendern bekannt: Auf dem Server gibt es kein
     Capacitor. Bis dahin gilt "noch unbekannt" - so blitzt weder die
     Hinweisseite in der App auf noch die App im Browser. */
  const [imGeraet, setImGeraet] = useState(null);
  useEffect(() => { setImGeraet(Capacitor.isNativePlatform()); }, []);

  /* Tastatur offen? Nur fuer die Anzeige - die Groesse der Webansicht regelt
     das Keyboard-Plugin (resize: "native" in capacitor.config.ts).
     Waehrend getippt wird, weicht die untere Navigationsleiste. Sonst saesse
     sie zwischen Schreibfeld und Tastatur und naehme der Nachrichtenliste
     Platz weg - Messenger blenden sie deshalb aus. */
  const [tastaturOffen, setTastaturOffen] = useState(false);
  useEffect(() => {
    if (!Capacitor.isNativePlatform()) return;
    const griffe = [];
    let abgemeldet = false;
    import("@capacitor/keyboard")
      .then(({ Keyboard }) => Promise.all([
        Keyboard.addListener("keyboardWillShow", () => setTastaturOffen(true)),
        Keyboard.addListener("keyboardWillHide", () => setTastaturOffen(false)),
      ]))
      .then((h) => { if (abgemeldet) h.forEach((x) => x.remove()); else griffe.push(...h); })
      .catch(() => {});
    return () => { abgemeldet = true; griffe.forEach((h) => h.remove()); };
  }, []);
  const [selectedClubId, setSelectedClubId] = useState(null);
  const [clubFeatures, setClubFeatures] = useState(DEFAULT_CLUB_FEATURES);
  const [featureOnboardingClubId, setFeatureOnboardingClubId] = useState(null);
  const [members, setMembers] = useState(INITIAL_MEMBERS);
  const [currentUserId, setCurrentUserId] = useState(null);
  /* Angemeldet wird zuerst, der Verein danach gewaehlt.
  
     Frueher stand die Vereinsauswahl vorn. Das passte nicht: Ein Konto gehoert
     zu einem Menschen, nicht zu einem Verein. Wer in zwei Vereinen ist, musste
     sich zweimal ueberlegen wohin, bevor er ueberhaupt wusste, ob seine
     Anmeldung stimmt - und wer sich vertippt hatte, fing von vorn an.
  
     Reihenfolge jetzt: login -> meineVereine -> hinein. Wer nur einem Verein
     angehoert, sieht meineVereine gar nicht; er landet direkt drin. */
  const [authScreen, setAuthScreen] = useState("login"); // login | meineVereine | club | newclub | register
  const [meineMitgliedschaften, setMeineMitgliedschaften] = useState([]);
  /* Wurde dieses Geraet verdraengt, soll die Anmeldung sagen warum - sonst
     steht man vor einem Formular und weiss nicht, wieso man wieder hier ist. */
  const [verdraengt, setVerdraengt] = useState(false);
  const [vereinLaedt, setVereinLaedt] = useState(false);
  /* Angemeldet, aber (noch) ohne freigegebene Mitgliedschaft — siehe login(). */
  const [pendingAccount, setPendingAccount] = useState(null);
  const [tab, setTab] = useState("home");
  const [tabHistory, setTabHistory] = useState([]);
  const [showSplash, setShowSplash] = useState(true);
  const [eventFocusRequest, setEventFocusRequest] = useState(null);
  const navigateTab = (nextTab) => {
    setTab((current) => {
      if (current !== nextTab) setTabHistory((h) => [...h, current]);
      return nextTab;
    });
  };
  const goBack = () => {
    setTabHistory((h) => {
      if (h.length === 0) return h;
      setTab(h[h.length - 1]);
      return h.slice(0, -1);
    });
  };
  const [subView, setSubView] = useState(null);
  /* Die Mannschaftswahl der Startseite steht hier oben bei den uebrigen
     Zustaenden - abmelden und Vereinswechsel setzen sie zurueck, und diese
     Funktionen stehen weiter oben in der Datei. */
  const [startseiteTeam, setStartseiteTeam] = useState(null);
  /* Die Navigationsleiste liegt UEBER dem Inhalt (absolute, bottom-0). Wie hoch
     sie ist, entscheidet das Geraet: Auf Geraeten mit Home-Leiste kommt
     safe-area-inset-bottom dazu, und die Beschriftungen brechen je nach
     Schriftgroesse anders um. Ein fester Abstand im Inhalt ist deshalb auf dem
     einen Geraet zu klein und auf dem anderen zu gross - im Chat blieb unter
     dem Schreibfeld eine sichtbare Luecke.
     Gemessen statt geraten: Die tatsaechliche Hoehe steht als --erg-nav-h
     bereit. Bei offener Tastatur ist die Leiste display:none - der Beobachter
     meldet dann 0, und das Schreibfeld rueckt bis nach unten. Verschwindet sie
     ganz, etwa in einer Unteransicht, wird der gemessene Wert entfernt und es
     gilt wieder der Vorgabewert aus dem Stylesheet. */
  const navBeobachter = useRef(null);
  /* Bewusst ein Rueckruf-Ref und kein useEffect: Die Leiste entsteht erst,
     wenn Huelle, Verein und Anmeldung stehen. Ein Effekt mit geratenen
     Abhaengigkeiten lief genau einmal - naemlich bevor es die Leiste gab -
     und danach nie wieder. Ein Rueckruf-Ref feuert dagegen exakt dann, wenn
     der Knoten kommt oder geht. */
  const navRef = useCallback((knoten) => {
    const setzen = (hoehe) => document.documentElement.style.setProperty("--erg-nav-h", `${Math.round(hoehe)}px`);
    /* Zuruecksetzen heisst: den gemessenen Wert entfernen, nicht ihn auf 0
       stellen. Sonst uebersteuerte eine 0 den Vorgabewert aus dem Stylesheet,
       und ohne Messung saesse das Schreibfeld unter der Leiste. */
    const zuruecksetzen = () => document.documentElement.style.removeProperty("--erg-nav-h");
    navBeobachter.current?.disconnect();
    navBeobachter.current = null;
    if (!knoten) { zuruecksetzen(); return; }
    /* Sofort messen - der Beobachter meldet sich erst nach dem naechsten
       Zeichnen, und bis dahin soll der Abstand schon stimmen. */
    setzen(knoten.getBoundingClientRect().height);
    if (typeof ResizeObserver === "undefined") return;
    const beobachter = new ResizeObserver((eintraege) => {
      const eintrag = eintraege[0];
      setzen(eintrag?.borderBoxSize?.[0]?.blockSize ?? eintrag?.contentRect?.height ?? 0);
    });
    beobachter.observe(knoten);
    navBeobachter.current = beobachter;
  }, []);

  const [feePaid, setFeePaid] = useState(INITIAL_FEE_PAID);
  const [feeRecords, setFeeRecords] = useState(INITIAL_FEE_RECORDS);
  const [events, setEvents] = useState(EVENTS);
  const [carpools, setCarpools] = useState({});
  const [channels, setChannels] = useState(INITIAL_CHANNELS);

  /* Chat aus der Datenbank.
   *
   * Bisher lagen Nachrichten nur im Arbeitsspeicher: Beim Senden gingen sie in
   * den lokalen Zustand und als Push-Mitteilung hinaus - geschrieben wurde
   * nichts. Der Empfaenger bekam "Neue Nachricht", oeffnete die App und fand
   * nichts. Nach einem Neustart war auch beim Absender alles weg.
   *
   * Tabellen und Sicherheitsregeln lagen von Anfang an bereit; nur benutzt hat
   * sie niemand. Genau das holt dieser Block nach.
   *
   * INITIAL_CHANNELS bleibt als Rueckfallebene fuer den Demo-Betrieb ohne
   * Datenbank - dort ist ein fluechtiger Chat richtig, weil nichts bleiben
   * soll. */
  useEffect(() => {
    /* currentUserId gehoert zwingend in die Abhaengigkeiten. Der Verein wird
       naemlich schon auf dem Auswahlbildschirm gesetzt, also VOR der Anmeldung -
       und die Sicherheitsregel auf channels lautet
       "using (public.is_club_member(club_id))". Ein nicht angemeldeter Zugriff
       bekommt deshalb null Kanaele zurueck, ohne Fehler.
       Ohne diese Abhaengigkeit lief der Ladevorgang genau einmal, naemlich
       anonym, und danach nie wieder: Der Chat waere die ganze Sitzung leer
       geblieben, obwohl der Verein Kanaele hat. Mit ihr laedt er direkt nach der
       Anmeldung erneut - dann mit Leserecht. */
    if (!supabase || !isDbId(selectedClubId) || !currentUserId) return;
    let abgemeldet = false;

    const laden = async () => {
      const { data: kanaele, error } = await supabase
        .from("channels")
        .select("id,name,emoji,team_id,write_roles,visible_roles,teams(name)")
        .eq("club_id", selectedClubId)
        .order("created_at");
      if (error || abgemeldet) return;

      /* Ein Verein ohne Kanaele bekommt eine leere Liste - nicht die
         Demo-Kanaele. Vorher kehrte die Funktion hier einfach zurueck, und
         INITIAL_CHANNELS blieb stehen: Ein frisch angelegter Verein sah damit
         erfundene Unterhaltungen fremder Leute als seinen eigenen Chat.
         Beim Fehler wird bewusst nichts geleert - dann ist der bisherige Stand
         besser als eine leere Ansicht. */
      if (!kanaele.length) { setChannels([]); return; }

      const ids = kanaele.map((k) => k.id);
      /* Die letzten 200 je Kanal reichen fuer die Ansicht. Aeltere holt der
         Nutzer ueber "Frueheres laden" nach - alles auf einmal zu ziehen waere
         bei einem Verein mit jahrelanger Historie eine lange Wartezeit beim
         Oeffnen. */
      const { data: nachrichten } = await supabase
        .from("messages")
        .select("id,channel_id,body,created_at,author_id,profiles(full_name)")
        .in("channel_id", ids)
        .order("created_at", { ascending: false })
        .limit(200 * ids.length);
      if (abgemeldet) return;

      const proKanal = {};
      for (const zeile of (nachrichten || []).reverse()) {
        (proKanal[zeile.channel_id] ||= []).push(zeileZuNachricht(zeile));
      }

      setChannels(kanaele.map((k) => {
        const team = Array.isArray(k.teams) ? k.teams[0] : k.teams;
        return {
          id: k.id,
          name: k.name,
          emoji: k.emoji || "💬",
          team: team?.name || null,
          adminOnly: (k.write_roles || []).length > 0,
          writeRoles: (k.write_roles || []).length ? k.write_roles : null,
          visibleRoles: (k.visible_roles || []).length ? k.visible_roles : null,
          messages: proKanal[k.id] || [],
        };
      }));
    };

    laden();

    /* Realtime: Neue Nachrichten erscheinen, ohne dass jemand die Ansicht neu
       laedt. Ohne das muesste man die App schliessen und oeffnen, um eine
       Antwort zu sehen - bei einem Chat der haeufigste Grund fuer den Eindruck,
       er funktioniere nicht. */
    const kanal = supabase
      .channel(`chat-${selectedClubId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages" }, (ereignis) => {
        const neu = ereignis.new;
        setChannels((cs) => cs.map((c) => c.id !== neu.channel_id || c.messages.some((m) => m.id === neu.id)
          ? c
          : { ...c, messages: [...c.messages, zeileZuNachricht(neu)].slice(-200) }));
      })
      /* Auch Loeschungen weitergeben. Ohne das verschwaende eine entfernte
         Nachricht nur beim Loeschenden und stuende bei allen anderen weiter da,
         bis sie die App neu starten - bei einer gemeldeten Nachricht genau das
         Gegenteil dessen, was passieren soll.
         Die Zeile kommt vollstaendig an, weil die Migration
         "replica identity full" setzt; sonst enthielte das Ereignis nur die
         Kennung und wir wuessten den Kanal nicht. */
      .on("postgres_changes", { event: "DELETE", schema: "public", table: "messages" }, (ereignis) => {
        const weg = ereignis.old;
        if (!weg?.id) return;
        setChannels((cs) => cs.map((c) => (weg.channel_id && c.id !== weg.channel_id
          ? c
          : { ...c, messages: c.messages.filter((m) => m.id !== weg.id) })));
      })
      .subscribe();

    return () => { abgemeldet = true; supabase.removeChannel(kanal); };
  }, [selectedClubId, currentUserId]);
  const [chatChannelId, setChatChannelId] = useState("team");
  /* Die Vereins-News. Sie kommen aus news_posts, nicht aus den Chatkanaelen -
     siehe RedaktionView. */
  const [vereinsNews, setVereinsNews] = useState([]);
  const [seasonVotes, setSeasonVotes] = useState({});
  const [tippPredictions, setTippPredictions] = useState({});
  const [tippResults, setTippResults] = useState({});
  const [dutyPlan, setDutyPlan] = useState(INITIAL_DUTY_PLAN);
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [protocols, setProtocols] = useState(INITIAL_PROTOCOLS);
  const [remindersSent, setRemindersSent] = useState({});
  const [welcomeAutomation, setWelcomeAutomation] = useState(true);
  const [billingAutomation, setBillingAutomation] = useState(true);
  /* Die Werbeplaetze kommen aus der Datenbank, nicht aus dem gemeinsamen
     Zustandsblock der Administratoren: Was auf einem Platz steht, entscheidet
     anzeige_fuer_platz() - eigener Sponsor des Vereins vor Werbung des
     Betreibers, und beides nur, solange es laeuft. */
  const [werbeplaetze, setWerbeplaetze] = useState({});
  /* Die Kachelreihenfolge ist eine persoenliche Vorliebe und lag trotzdem im
     Zustandsblock des Vereins - jeder Administrator hat sie damit fuer alle
     anderen mitgeaendert. Sie steht jetzt am Profil. Der Setzer schreibt gleich
     mit, damit keine Aufrufstelle daran denken muss. */
  const [dashboardTileOrder, setDashboardTileOrderIntern] = useState(DEFAULT_DASHBOARD_TILE_ORDER);
  const setDashboardTileOrder = (wert) => {
    if (Array.isArray(wert)) kachelreihenfolgeSpeichern(wert);
    setDashboardTileOrderIntern(wert);
  };
  const [polls, setPolls] = useState(INITIAL_POLLS);
  /* Welche Vereinsdaten sich beim Anmelden nicht laden liessen. Null heisst:
     alles da. */
  const [datenFehler, setDatenFehler] = useState(null);
  /* Und was beim SCHREIBEN schiefging. Bisher scheiterten mehrere
     Schreibvorgaenge stumm: Der Eintrag stand auf dem Bildschirm, die Datenbank
     wies ihn ab (etwa weil die Sicherheitsregel die Rolle nicht zulaesst), und
     beim naechsten Oeffnen war er weg. Niemand erfuhr, dass etwas nicht
     angekommen ist - das ist die unangenehmste Art, Daten zu verlieren. */
  const [schreibFehler, setSchreibFehler] = useState("");
  /* Punkteziel und Praemie des Vereins. Beides steht in club_settings; ohne
     Praemie verspricht die App nichts. */
  const [punkteZiel, setPunkteZiel] = useState(1000);
  const [punktePraemie, setPunktePraemie] = useState("");
  /* Das Postfach. Geladen wird es beim Oeffnen, die Zahl der Ungelesenen
     zusaetzlich beim Betreten des Vereins - sonst muesste die Kopfzeile bei
     jedem Tastendruck fragen. */
  const [postfach, setPostfach] = useState([]);
  const [postfachLaedt, setPostfachLaedt] = useState(false);
  const [ungelesen, setUngelesen] = useState(0);

  useEffect(() => {
    setFeePaid(Object.fromEntries(members.map((member) => {
      const entries = feeRecords.filter((record) => record.memberId === member.id);
      return [member.id, entries.length > 0 && entries.every((record) => record.paid)];
    })));
  }, [feeRecords, members]);

  useEffect(() => {
    if (!supabase) return;
    supabase.from("clubs").select("id,name,short_name,city,founded_year,logo_url,register_number,currency,referral_code,referral_credit_months,sport,primary_color,secondary_color,sponsoring_freigeschaltet").order("name").then(({ data }) => {
      if (data?.length) setClubs(data.map((club) => ({
        id: club.id,
        name: club.name,
        shortName: club.short_name,
        city: club.city || "—",
        foundedYear: club.founded_year || new Date().getFullYear(),
        logoUrl: club.logo_url || null,
        registerNumber: club.register_number || "", currency: club.currency || "EUR", referralCode: club.referral_code || "", referralCreditMonths: club.referral_credit_months || 0,
        sport: club.sport || "rollhockey",
        primaryColor: club.primary_color || DEFAULT_CLUB_COLORS.primary,
        secondaryColor: club.secondary_color || DEFAULT_CLUB_COLORS.secondary,
        sponsoringFrei: club.sponsoring_freigeschaltet === true,
      })));
    });
  }, []);

  const currentUser = members.find((m) => m.id === currentUserId);
  useEffect(() => {
    if (!currentUser) return;
    listenForForegroundMessages();
  }, [currentUser?.id]);
  useEffect(() => {
    const isRealAccount = !!supabase && isDbId(currentUser?.id || "");
    if (!isRealAccount || !currentUser?.clubId) return;
    const loadEvents = async () => {
      const { data, error } = await supabase.from("events")
        .select("id,type,status,title,description,starts_at,location,home_away,series_id,helper_slots,teams(name)")
        .eq("club_id", currentUser.clubId)
        .order("starts_at", { ascending: true });
      /* Vorher stand hier ein blosses return. Der Anfangszustand von events sind
         aber die zehn erfundenen Demo-Termine - bei einem Ladefehler blieben sie
         also stehen, und der Verein sah "Heimspiel vs. Herringen" in der
         Hemberghalle Iserlohn als seinen eigenen Spielplan. */
      if (error) { setDatenFehler((v) => [...new Set([...(v || []), "Termine"])]); setEvents([]); return; }
      if (!data) { setEvents([]); return; }
      const mapped = data.map((row) => {
        const teamName = Array.isArray(row.teams) ? row.teams[0]?.name : row.teams?.name;
        return {
          id: row.id,
          type: row.type,
          team: teamName || undefined,
          title: row.title,
          date: row.starts_at,
          location: row.location || "",
          desc: row.description || "",
          carpool: false,
          home: row.home_away === "heim" ? true : row.home_away === "auswaerts" ? false : undefined,
          cancelled: row.status === "cancelled",
          seriesId: row.series_id || null,
          helperSlots: (row.helper_slots || []).length ? row.helper_slots : undefined,
          ...(row.type === "training" && teamName ? { youthClassIds: [TEAM_TO_YOUTHCLASS[teamName]] } : {}),
        };
      });
      setEvents(mapped);
    };
    loadEvents();
  }, [currentUser?.id, currentUser?.clubId]);
  const currentClub = clubs.find((c) => c.id === selectedClubId) || clubs.find((c) => c.id === currentUser?.clubId);
  const clubMembers = members.filter((m) => m.clubId === selectedClubId);
  const featureEnabled = (key) => clubFeatures[key] !== false;
  const entitlement = useClubEntitlement(currentUser);
  /* "Abo ansehen" fuehrt direkt in den Kaufbereich, nicht nur auf den
     Profil-Reiter. Vorher landete man dort und musste sich selbst durch
     Einstellungen > Abo & Empfehlungen klicken - ausgerechnet an der Stelle,
     an der jemand gerade kaufen will.

     Der Wunsch wird als Zustand gesetzt und von ProfileView beim Aufbau
     eingeloest; danach setzt sie ihn zurueck, damit ein spaeterer Besuch des
     Profils wieder normal auf der Uebersicht beginnt. */
  const [profilZiel, setProfilZiel] = useState("");
  const goSubscribe = () => { setSubView(null); setProfilZiel("billing"); setTab("profile"); };

  const loadClubFeatures = useCallback(async () => {
    if (!supabase || !currentClub?.id) { setClubFeatures(DEFAULT_CLUB_FEATURES); return; }
    const { data } = await supabase.from("club_feature_toggles").select("feature_key,enabled").eq("club_id", currentClub.id);
    setClubFeatures({ ...DEFAULT_CLUB_FEATURES, ...Object.fromEntries((data || []).map((row) => [row.feature_key, row.enabled])) });
  }, [currentClub?.id]);
  useEffect(() => { loadClubFeatures(); }, [loadClubFeatures]);

  /* Was auf den vier Werbeplaetzen steht. Eine Abfrage fuer alle vier; die
     Rangfolge und die Laufzeit entscheidet die Datenbank. Neu geladen wird
     beim Vereinswechsel und wenn der Sponsorenmanager etwas geaendert hat. */
  const ladeWerbeplaetze = useCallback(async () => {
    if (!supabase || !currentClub?.id) { setWerbeplaetze({}); return; }
    const { data, error } = await supabase.rpc("anzeigen_fuer_verein", { target_club: currentClub.id });
    if (error) { setWerbeplaetze({}); return; }
    const belegt = {};
    for (const a of data || []) {
      belegt[a.platz] = {
        ...a,
        bild_url: a.bild_pfad ? supabase.storage.from("sponsor-bilder").getPublicUrl(a.bild_pfad).data.publicUrl : "",
      };
    }
    setWerbeplaetze(belegt);
  }, [currentClub?.id]);
  useEffect(() => { ladeWerbeplaetze(); }, [ladeWerbeplaetze]);

  /* ------------------------------------------------------------------ *
   * Vereinsdaten laden.
   *
   * Bis zum 01.09.2026 lag all das als ein JSON-Klumpen in club_app_state.
   * Der wurde nur von Administratoren geschrieben - Umfrage-Stimmen,
   * Tipps, Helferdienste und Wahlen der Mitglieder gingen also verloren,
   * sobald jemand die App schloss. Die Tabellen dafuer gibt es seit dem
   * Ursprungsschema; die App hat sie nie angefasst.
   * ------------------------------------------------------------------ */
  const ladeVereinsdaten = async (clubId, profileId, roster) => {
    if (!supabase || !clubId) return;
    const profilZuMitglied = Object.fromEntries((roster || []).filter((m) => m.authProfileId).map((m) => [m.authProfileId, m.id]));

    const [tipps, ergebnisse, umfragen, antworten, stimmen, wahl, dienste, protokolle, aufgaben, einstellungen, erinnerungen, eigenesProfil] = await Promise.all([
      supabase.from("predictions").select("event_id,profile_id,home_score,away_score"),
      supabase.from("event_results").select("event_id,heim,auswaerts").eq("club_id", clubId),
      supabase.from("polls").select("id,title,active,created_at").eq("club_id", clubId).order("created_at", { ascending: false }),
      supabase.from("poll_options").select("id,poll_id,label,position,legacy_votes"),
      supabase.from("poll_votes").select("poll_id,option_id,profile_id"),
      supabase.from("season_votes").select("voter_profile_id,candidate_membership_id").eq("club_id", clubId).eq("season", SAISON_KENNUNG),
      supabase.from("duty_assignments").select("event_id,station,membership_id"),
      supabase.from("protocols").select("id,title,meeting_date,raw_text,attendee_membership_ids,created_at").eq("club_id", clubId).order("meeting_date", { ascending: false }),
      supabase.from("protocol_tasks").select("id,protocol_id,text,assignee_membership_id,due_date,done"),
      supabase.from("club_settings").select("maintenance_mode,welcome_automation,billing_automation,punkte_ziel,punkte_praemie").eq("club_id", clubId).maybeSingle(),
      supabase.from("fee_reminders").select("membership_id,gesendet_am").eq("club_id", clubId).eq("jahr", new Date().getFullYear()),
      profileId ? supabase.from("profiles").select("dashboard_tile_order").eq("id", profileId).maybeSingle() : Promise.resolve({ data: null }),
    ]);

    /* Tipps: In der Datenbank haengen sie am Profil, in der Oberflaeche an der
       Mitgliedschaft. Fremde Tipps liefert die Regel erst, wenn das Ergebnis
       feststeht - vorher koennte man sonst abschreiben. */
    const tippBlock = {};
    for (const t of tipps.data || []) {
      const mid = profilZuMitglied[t.profile_id];
      if (!mid) continue;
      (tippBlock[mid] ||= {})[t.event_id] = { home: String(t.home_score ?? ""), away: String(t.away_score ?? "") };
    }
    setTippPredictions(tippBlock);
    setTippResults(Object.fromEntries((ergebnisse.data || []).map((r) => [r.event_id, { home: String(r.heim), away: String(r.auswaerts) }])));

    const antwortenJeUmfrage = {};
    for (const o of (antworten.data || []).sort((a, b) => a.position - b.position)) (antwortenJeUmfrage[o.poll_id] ||= []).push(o);
    const stimmenJeUmfrage = {};
    for (const v of stimmen.data || []) (stimmenJeUmfrage[v.poll_id] ||= []).push(v);
    setPolls((umfragen.data || []).map((p) => {
      const meine = (stimmenJeUmfrage[p.id] || []).filter((v) => v.profile_id === profileId)[0];
      return {
        id: p.id, title: p.title, active: p.active,
        options: (antwortenJeUmfrage[p.id] || []).map((o) => ({
          id: o.id, label: o.label,
          /* Die alten Summen aus dem Zustandsblock zaehlen mit. Dort stand nur,
             wie viele gestimmt haben, nicht wer wie - zerlegen liesse sich das
             nur durch Erfinden. */
          votes: (stimmenJeUmfrage[p.id] || []).filter((v) => v.option_id === o.id).length + (o.legacy_votes || 0),
        })),
        voterIds: (stimmenJeUmfrage[p.id] || []).map((v) => profilZuMitglied[v.profile_id]).filter(Boolean),
        meineAntwortId: meine?.option_id || null,
      };
    }));

    setSeasonVotes(Object.fromEntries((wahl.data || [])
      .map((v) => [profilZuMitglied[v.voter_profile_id], v.candidate_membership_id])
      .filter(([waehler]) => !!waehler)));

    const dienstBlock = {};
    for (const d of dienste.data || []) ((dienstBlock[d.event_id] ||= {})[d.station] ||= []).push(d.membership_id);
    setDutyPlan(dienstBlock);

    const aufgabenJeProtokoll = {};
    for (const a of aufgaben.data || []) (aufgabenJeProtokoll[a.protocol_id] ||= []).push({
      id: a.id, text: a.text, assignee: a.assignee_membership_id || "", due: a.due_date || "", done: a.done,
    });
    setProtocols((protokolle.data || []).map((p) => ({
      id: p.id, title: p.title, date: p.meeting_date, attendees: p.attendee_membership_ids || [],
      rawText: p.raw_text || "", tasks: aufgabenJeProtokoll[p.id] || [],
    })));

    setPunkteZiel(einstellungen.data?.punkte_ziel || 1000);
    setPunktePraemie(einstellungen.data?.punkte_praemie || "");

    /* Die Vereinspunkte werden in der Datenbank gerechnet, aus dem, was
       ohnehin dasteht - Helferdienste, uebernommene Aufgaben, Umfragen, Tipps
       und Vereinstreue. Vorher bekam jedes aus der Datenbank geladene Mitglied
       fest 0, und im Profil stand bei allen dauerhaft "0 / 1000". */
    const { data: punkte } = await supabase.rpc("punkte_je_mitglied", { target_club: clubId });
    if (punkte?.length) {
      const jeMitglied = Object.fromEntries(punkte.map((p) => [p.membership_id, p.punkte]));
      setMembers((alle) => alle.map((m) => (jeMitglied[m.id] === undefined ? m : { ...m, points: jeMitglied[m.id] })));
    }

    setMaintenanceMode(einstellungen.data?.maintenance_mode === true);
    setWelcomeAutomation(einstellungen.data?.welcome_automation !== false);
    setBillingAutomation(einstellungen.data?.billing_automation !== false);
    setRemindersSent(Object.fromEntries((erinnerungen.data || []).map((r) => [r.membership_id, r.gesendet_am])));
    if (Array.isArray(eigenesProfil?.data?.dashboard_tile_order) && eigenesProfil.data.dashboard_tile_order.length) {
      setDashboardTileOrderIntern(eigenesProfil.data.dashboard_tile_order);
    }

    /* Eine fehlgeschlagene Abfrage sieht aus wie eine leere Liste - und eine
       leere Liste sieht aus, als haette der Verein nichts eingetragen. Genau
       dieser Unterschied entscheidet aber darueber, ob jemand seine Arbeit fuer
       verloren haelt. Also wird gesagt, was nicht geladen werden konnte. */
    const fehlgeschlagen = [
      [tipps.error, "Tipps"], [ergebnisse.error, "Spielergebnisse"],
      [umfragen.error, "Umfragen"], [antworten.error, "Umfrage-Antworten"], [stimmen.error, "Umfrage-Stimmen"],
      [wahl.error, "Athletenwahl"], [dienste.error, "Helferplan"],
      [protokolle.error, "Protokolle"], [aufgaben.error, "Protokoll-Aufgaben"],
      [einstellungen.error, "Vereinseinstellungen"], [erinnerungen.error, "Zahlungserinnerungen"],
    ].filter(([fehler]) => !!fehler).map(([, name]) => name);
    setDatenFehler(fehlgeschlagen.length ? fehlgeschlagen : null);
  };

  /* ------------------------------------------------------------------ *
   * Schreiben.
   *
   * Jede Aenderung geht dorthin, wo sie hingehoert - und zwar sofort, nicht
   * ueber einen gesammelten Block. Das ist nicht nur sauberer, es ist die
   * einzige Fassung, die mit den Sicherheitsregeln zusammenpasst: Ein Mitglied
   * darf seine eigene Zeile schreiben, die Vereinsleitung die des Vereins. Ein
   * Block, der alles auf einmal schreibt, kann das nicht abbilden.
   *
   * Der Zustand im Arbeitsspeicher wird sofort gesetzt, damit die Oberflaeche
   * nicht auf das Netz wartet. Geht das Schreiben schief, wird er
   * zurueckgenommen - eine Anzeige, die etwas behauptet, was nicht in der
   * Datenbank steht, waere schlimmer als eine kurze Zuckung.
   * ------------------------------------------------------------------ */
  const meineMitgliedsId = currentUserId;
  const meinProfil = () => currentUser?.authProfileId || offeneSitzung?.profileId || null;

  const tippSpeichern = async (eventId, heim, auswaerts) => {
    if (!supabase || !meinProfil() || typeof eventId !== "string") return;
    const zahl = (w) => (w === "" || w === null || w === undefined ? null : Number(w));
    if (zahl(heim) === null || zahl(auswaerts) === null) {
      await supabase.from("predictions").delete().eq("event_id", eventId).eq("profile_id", meinProfil());
      return;
    }
    const { error } = await supabase.from("predictions").upsert({
      event_id: eventId, profile_id: meinProfil(),
      home_score: zahl(heim), away_score: zahl(auswaerts),
    }, { onConflict: "event_id,profile_id" });
    if (error) setSchreibFehler("Dein Tipp konnte nicht gespeichert werden. Steht das Ergebnis schon fest?");
  };

  const ergebnisSpeichern = async (eventId, ergebnis) => {
    if (!supabase || !selectedClubId || typeof eventId !== "string") return;
    const { error } = await supabase.from("event_results").upsert({
      club_id: selectedClubId, event_id: eventId,
      heim: Number(ergebnis.home), auswaerts: Number(ergebnis.away),
      erfasst_von: isDbId(meineMitgliedsId) ? meineMitgliedsId : null,
    }, { onConflict: "club_id,event_id" });
    if (error) setSchreibFehler("Das Ergebnis konnte nicht gespeichert werden.");
  };

  const stimmeAbgeben = async (pollId, optionId) => {
    if (!supabase || !meinProfil() || typeof pollId !== "string") return { error: "Nicht moeglich." };
    const { error } = await supabase.from("poll_votes").upsert(
      { poll_id: pollId, option_id: optionId, profile_id: meinProfil() },
      { onConflict: "poll_id,profile_id" },
    );
    return error ? { error: "Deine Stimme konnte nicht gespeichert werden." } : {};
  };

  const umfrageAnlegen = async (titel, antworten) => {
    if (!supabase || !selectedClubId) return { error: "Nicht moeglich." };
    const { data: umfrage, error } = await supabase.from("polls")
      .insert({ club_id: selectedClubId, title: titel, active: true, created_by: meinProfil() })
      .select("id").single();
    if (error || !umfrage) return { error: "Die Umfrage konnte nicht angelegt werden." };
    const { error: antwortFehler } = await supabase.from("poll_options")
      .insert(antworten.map((label, i) => ({ poll_id: umfrage.id, label, position: i })));
    if (antwortFehler) {
      /* Eine Umfrage ohne Antworten waere unbenutzbar und liesse sich in der
         Oberflaeche nicht mehr loswerden. Also zurueck. */
      await supabase.from("polls").delete().eq("id", umfrage.id);
      return { error: "Die Antworten konnten nicht gespeichert werden." };
    }
    return { id: umfrage.id };
  };

  const umfrageUmschalten = async (pollId, aktiv) => {
    if (!supabase || typeof pollId !== "string") return;
    const { error } = await supabase.from("polls").update({ active: aktiv }).eq("id", pollId);
    if (error) setSchreibFehler("Die Umfrage konnte nicht umgeschaltet werden.");
  };

  const saisonStimmeAbgeben = async (kandidatMitgliedsId) => {
    if (!supabase || !selectedClubId || !meinProfil()) return { error: "Nicht moeglich." };
    const { error } = await supabase.from("season_votes").upsert({
      club_id: selectedClubId, season: SAISON_KENNUNG,
      voter_profile_id: meinProfil(), candidate_membership_id: kandidatMitgliedsId,
    }, { onConflict: "club_id,season,voter_profile_id" });
    return error ? { error: "Deine Stimme konnte nicht gespeichert werden." } : {};
  };

  const dienstSetzen = async (eventId, station, mitgliedsId, eintragen) => {
    if (!supabase || typeof eventId !== "string" || !isDbId(mitgliedsId)) return;
    /* Genau hier ging bisher am meisten verloren: Ein Trainer, der jemand
       anderen einteilt, darf das laut Sicherheitsregel nicht - die eigene Zeile
       ja, fremde nur die Vereinsleitung. Die Ansicht zeigte den Namen trotzdem
       an, und nach dem naechsten Start war er weg. */
    const { error } = eintragen
      ? await supabase.from("duty_assignments").insert({ event_id: eventId, station, membership_id: mitgliedsId })
      : await supabase.from("duty_assignments").delete()
          .eq("event_id", eventId).eq("station", station).eq("membership_id", mitgliedsId);
    if (error) {
      setSchreibFehler(eintragen
        ? "Die Einteilung konnte nicht gespeichert werden. Fremde Personen darf nur die Vereinsleitung einteilen."
        : "Die Einteilung konnte nicht entfernt werden.");
      return { error: true };
    }
    return {};
  };

  const protokollSpeichern = async (entwurf) => {
    if (!supabase || !selectedClubId) return { error: "Nicht moeglich." };
    const { data: protokoll, error } = await supabase.from("protocols").insert({
      club_id: selectedClubId, title: entwurf.title, meeting_date: entwurf.date,
      raw_text: entwurf.rawText, attendee_membership_ids: (entwurf.attendees || []).filter(isDbId),
      created_by: meinProfil(),
    }).select("id").single();
    if (error || !protokoll) return { error: "Das Protokoll konnte nicht gespeichert werden." };
    const aufgaben = (entwurf.tasks || []).filter((t) => t.text.trim());
    if (aufgaben.length) {
      /* Auch hier wurde das Ergebnis verworfen. Das Protokoll selbst war dann
         gespeichert, die Aufgaben nicht - und die Ansicht meldete Erfolg.
         Jemand bekam eine Aufgabe zugeteilt, von der er nie erfuhr. Weil das
         Protokoll steht, ist das kein voller Fehlschlag: Die Meldung sagt
         genau das, damit niemand aus Versehen ein zweites anlegt. */
      const { error: aufgabenFehler } = await supabase.from("protocol_tasks").insert(aufgaben.map((t) => ({
        protocol_id: protokoll.id, text: t.text.trim(),
        assignee_membership_id: isDbId(t.assignee) ? t.assignee : null,
        due_date: t.due || null, done: false,
      })));
      if (aufgabenFehler) {
        return { id: protokoll.id, warnung: "Das Protokoll ist gespeichert, die Aufgaben darin konnten aber nicht angelegt werden. Bitte trage sie noch einmal ein." };
      }
    }
    return { id: protokoll.id };
  };

  const aufgabeUmschalten = async (taskId, erledigt) => {
    if (!supabase || typeof taskId !== "string") return;
    const { error } = await supabase.from("protocol_tasks").update({ done: erledigt }).eq("id", taskId);
    if (error) setSchreibFehler("Der Haken an der Aufgabe konnte nicht gespeichert werden.");
  };

  const vereinseinstellungSetzen = async (feld, wert) => {
    if (!supabase || !selectedClubId) return;
    const { error } = await supabase.from("club_settings").upsert(
      { club_id: selectedClubId, [feld]: wert, updated_at: new Date().toISOString() },
      { onConflict: "club_id" },
    );
    if (error) setSchreibFehler("Die Einstellung konnte nicht gespeichert werden.");
  };

  const erinnerungVermerken = async (mitgliedsId) => {
    if (!supabase || !selectedClubId || !isDbId(mitgliedsId)) return;
    const { error } = await supabase.from("fee_reminders").upsert({
      club_id: selectedClubId, membership_id: mitgliedsId, jahr: new Date().getFullYear(),
      gesendet_am: new Date().toISOString(),
      gesendet_von: isDbId(meineMitgliedsId) ? meineMitgliedsId : null,
    }, { onConflict: "membership_id,jahr" });
    if (error) setSchreibFehler("Die Erinnerung wurde verschickt, aber nicht vermerkt — sie könnte doppelt kommen.");
  };

  const ungelesenZaehlen = useCallback(async () => {
    if (!supabase || !selectedClubId || !meinProfil()) return;
    const { data } = await supabase.rpc("ungelesene_benachrichtigungen", { target_club: selectedClubId });
    setUngelesen(typeof data === "number" ? data : 0);
  }, [selectedClubId, currentUserId]);
  /* Der Effekt stand vorher weiter oben, direkt bei den anderen Ladeeffekten -
     und damit ueber dieser Definition. Die Abhaengigkeitsliste [ungelesenZaehlen]
     wird beim Rendern ausgewertet, also bevor das useCallback ueberhaupt
     zugewiesen ist: ReferenceError, die ganze App blieb schwarz. Ein Effekt
     gehoert hinter die Funktion, die er aufruft. */
  useEffect(() => { ungelesenZaehlen(); }, [ungelesenZaehlen]);

  const postfachLaden = async () => {
    if (!supabase || !selectedClubId) return;
    setPostfachLaedt(true);
    const { data, error } = await supabase.from("user_notifications")
      .select("id,kind,title,body,read_at,created_at")
      .eq("club_id", selectedClubId)
      .order("created_at", { ascending: false })
      .limit(100);
    setPostfachLaedt(false);
    if (error) { setSchreibFehler("Die Benachrichtigungen konnten nicht geladen werden."); return; }
    setPostfach(data || []);
    setUngelesen((data || []).filter((e) => !e.read_at).length);
  };

  const postfachGelesen = async () => {
    if (!supabase || !selectedClubId) return;
    const jetzt = new Date().toISOString();
    setPostfach((alle) => alle.map((e) => (e.read_at ? e : { ...e, read_at: jetzt })));
    setUngelesen(0);
    const { error } = await supabase.rpc("benachrichtigungen_gelesen", { target_club: selectedClubId });
    if (error) { setSchreibFehler("Konnte nicht als gelesen vermerkt werden."); postfachLaden(); }
  };

  const postfachLoeschen = async (id) => {
    const vorher = postfach;
    setPostfach((alle) => alle.filter((e) => e.id !== id));
    setUngelesen((n) => Math.max(0, n - (vorher.find((e) => e.id === id)?.read_at ? 0 : 1)));
    const { error } = await supabase.from("user_notifications").delete().eq("id", id);
    if (error) { setSchreibFehler("Die Benachrichtigung konnte nicht entfernt werden."); setPostfach(vorher); }
  };

  const kachelreihenfolgeSpeichern = async (reihenfolge) => {
    if (!supabase || !meinProfil()) return;
    const { error } = await supabase.from("profiles").update({ dashboard_tile_order: reihenfolge }).eq("id", meinProfil());
    if (error) setSchreibFehler("Die Reihenfolge konnte nicht gespeichert werden.");
  };

  /* Wer schon angemeldet ist, soll sich nicht erneut anmelden muessen, nur weil
     er einen weiteren Verein sucht - genau daran ist der Weg vorher
     gescheitert. */
  const selectClub = (clubId) => {
    setSelectedClubId(clubId);
    setAuthScreen(offeneSitzung ? "beitreten" : "login");
  };
  /* Einen Verein anlegen.
   *
   * Ohne Konto fuehrt der Weg ueber die Registrierung: Dort entstehen Konto und
   * Verein zusammen. Mit Konto ginge das nicht - die Registrierung scheiterte
   * an der schon vergebenen E-Mail, und der Weg endete genauso in einer
   * Sackgasse wie frueher der Beitritt zu einem zweiten Verein. Wer angemeldet
   * ist, legt den Verein deshalb direkt an. */
  const createClub = async (club) => {
    if (!offeneSitzung || !supabase) {
      setClubs((cs) => [...cs, club]);
      setSelectedClubId(club.id);
      setAuthScreen("register");
      return {};
    }

    const { data: sitzung } = await supabase.auth.getUser();
    const profileId = sitzung?.user?.id;
    if (!profileId) return { error: "Die Sitzung ist abgelaufen. Bitte melde dich erneut an." };

    const { data: angelegt, error } = await supabase.rpc("register_new_club", {
      club_name: club.name, club_short_name: club.shortName, club_city: club.city || "",
      club_register_number: club.registerNumber, club_currency: club.currency || "EUR",
      referral: club.referralCode || null,
      member_name: meineMitgliedschaften[0]?.display_name || sitzung.user.email.split("@")[0],
      member_birthdate: null,
      club_sport: club.sport || "rollhockey",
      club_primary_color: club.primaryColor || DEFAULT_CLUB_COLORS.primary,
      club_secondary_color: club.secondaryColor || DEFAULT_CLUB_COLORS.secondary,
    });
    if (error) return { error: "Der Verein konnte nicht angelegt werden. Bitte pruefe die Angaben." };

    const neueId = angelegt?.[0]?.club_id;
    if (!neueId) return { error: "Der Verein konnte nicht angelegt werden." };

    if (club.logoDataUrl) {
      try {
        const blob = await (await fetch(club.logoDataUrl)).blob();
        const pfad = `${neueId}/logo-${Date.now()}.png`;
        const upload = await supabase.storage.from("club-logos").upload(pfad, blob, { upsert: true });
        if (!upload.error) {
          const { data: oeffentlich } = supabase.storage.from("club-logos").getPublicUrl(pfad);
          await supabase.from("clubs").update({ logo_url: oeffentlich.publicUrl }).eq("id", neueId);
        }
      } catch {}
    }

    setClubs((cs) => [...cs.filter((c) => c.id !== neueId), {
      id: neueId, name: club.name, shortName: club.shortName, city: club.city || "—",
      foundedYear: new Date().getFullYear(), logoUrl: club.logoDataUrl || null,
      registerNumber: club.registerNumber || "", currency: club.currency || "EUR",
      referralCode: club.referralCode || "", referralCreditMonths: 0, sport: club.sport || "rollhockey",
      primaryColor: club.primaryColor || DEFAULT_CLUB_COLORS.primary,
      secondaryColor: club.secondaryColor || DEFAULT_CLUB_COLORS.secondary,
      sponsoringFrei: false,
    }]);
    setSelectedClubId(neueId);
    setFeatureOnboardingClubId(neueId);
    await mitgliedschaftenLaden(profileId);
    return loadSupabaseMembership(profileId, neueId);
  };
  /* "Verein wechseln" fuehrt zu den eigenen Vereinen, nicht in die Suche. Wer
     wechselt, will fast immer zu einem, in dem er schon ist. */
  const changeClub = () => { setSelectedClubId(null); setAuthScreen(meineMitgliedschaften.length > 0 ? "meineVereine" : "club"); };
  const updateCurrentClubLogo = (logoUrl) => setClubs((items) => items.map((club) => club.id === currentClub?.id ? { ...club, logoUrl } : club));
  const updateCurrentClubColors = (primaryColor, secondaryColor) => setClubs((items) => items.map((club) => club.id === currentClub?.id ? { ...club, primaryColor, secondaryColor } : club));

  const enterApp = (member, clubRoster = null) => {
    setMembers((current) => clubRoster
      ? [...current.filter((item) => item.clubId !== member.clubId), ...clubRoster]
      : [...current.filter((item) => item.id !== member.id), member]);
    setSelectedClubId(member.clubId);
    setCurrentUserId(member.id);
    setTab("home"); setTabHistory([]); setSubView(null);
  };
  const loadSupabaseMembership = async (profileId, clubId) => {
    /* Ohne Verein gibt es nichts zu laden. Ohne diese Zeile ging die Abfrage
       mit club_id=eq.null an eine uuid-Spalte, PostgREST antwortete mit 400,
       und der Nutzer bekam "Das Vereinsprofil konnte nicht geladen werden" zu
       lesen - eine Meldung, aus der niemand schliessen kann, dass er schlicht
       noch keinem Verein angehoert. */
    if (!clubId) return { error: "Für dieses Konto besteht noch keine Mitgliedschaft in einem Verein.", code: "membership_missing" };
    const { data, error } = await supabase.from("club_memberships")
      .select("id,club_id,display_name,email,member_since,membership_number,status,team_filter,is_managed_profile,membership_roles(role),team_members(function,teams(name)),profiles!club_memberships_profile_id_fkey(birthdate,academic_title,first_name,last_name,contact_emails,contact_phones,gender,nationality,street,postal_code,city,country_code,notification_master,notification_preferences,auto_logout_days,calendar_sync_interval,show_birthday)")
      .eq("profile_id", profileId).eq("club_id", clubId).maybeSingle();
    if (error) return { error: "Das Vereinsprofil konnte nicht geladen werden." };
    if (!data) return { error: "Für dieses Konto besteht noch keine Mitgliedschaft in diesem Verein.", code: "membership_missing" };
    if (data.status === "pending") return { error: "Deine Registrierung wartet noch auf die Freigabe durch den Vereins-Administrator.", code: "membership_pending" };
    if (data.status !== "active") return { error: "Dieses Vereinsprofil ist derzeit nicht aktiv." };
    const { data: rosterData, error: rosterError } = await supabase.from("club_memberships")
      .select("id,profile_id,club_id,display_name,email,member_since,membership_number,status,team_filter,is_managed_profile,membership_roles(role),team_members(function,teams(name)),profiles!club_memberships_profile_id_fkey(birthdate,academic_title,first_name,last_name,contact_emails,contact_phones,gender,nationality,street,postal_code,city,country_code,notification_master,notification_preferences,auto_logout_days,calendar_sync_interval,show_birthday)")
      .eq("club_id", clubId).in("status", ["active", "pending"]);
    if (rosterError) return { error: "Die Mitgliederliste konnte nicht geladen werden." };
    const { data: familyData, error: familyError } = await supabase.from("family_links")
      .select("id,first_membership_id,second_membership_id,first_to_second,second_to_first")
      .eq("club_id", clubId);
    if (familyError) return { error: "Die Familienverknüpfungen konnten nicht geladen werden." };
    const roster = (rosterData || []).map((record, index) => {
      const assignments = record.team_members || [];
      const teamNames = [...new Set(assignments.map((entry) => entry.teams?.name).filter(Boolean))];
      const playerTeamNames = [...new Set(assignments.filter((entry) => entry.function === "spieler").map((entry) => entry.teams?.name).filter(Boolean))];
      return {
        id: record.id, authProfileId: record.profile_id, clubId: record.club_id, teamFilter: record.team_filter || "alle",
        name: record.display_name, email: record.email || "", password: "",
        team: hoechsteMannschaft(playerTeamNames) || hoechsteMannschaft(teamNames) || "Mitglied", teams: teamNames, playerTeams: playerTeamNames, number: null,
        trainerTeams: [...new Set(assignments.filter((entry) => entry.function === "trainer").map((entry) => entry.teams?.name).filter(Boolean))],
        /* Kapitaen und Teammanager kann jemand in MEHREREN Mannschaften sein.
           managedTeam blieb als Einzelwert stehen, weil aelterer Code ihn
           liest; massgeblich sind die Listen. */
        captainTeams: [...new Set(assignments.filter((entry) => entry.function === "kapitaen").map((entry) => entry.teams?.name).filter(Boolean))],
        managedTeams: [...new Set(assignments.filter((entry) => entry.function === "teammanager").map((entry) => entry.teams?.name).filter(Boolean))],
        managedTeam: assignments.find((entry) => entry.function === "teammanager")?.teams?.name || null,
        since: record.member_since || new Date().getFullYear(),
        roles: (record.membership_roles || []).map((entry) => entry.role),
        color: AVATAR_FARBEN[index % 5],
        points: 0, tippPoints: 0, badges: [], birthdate: record.profiles?.birthdate || "",
        membershipNumber: record.membership_number || "", academicTitle: record.profiles?.academic_title || "",
        firstName: record.profiles?.first_name || "", lastName: record.profiles?.last_name || "",
        contactEmails: record.profiles?.contact_emails || [], contactPhones: record.profiles?.contact_phones || [],
        gender: record.profiles?.gender || "keine_angabe", nationality: record.profiles?.nationality || "",
        street: record.profiles?.street || "", postalCode: record.profiles?.postal_code || "", city: record.profiles?.city || "", countryCode: record.profiles?.country_code || "DE",
        notificationMaster: record.profiles?.notification_master ?? true, notificationPreferences: record.profiles?.notification_preferences || {},
        showBirthday: record.profiles?.show_birthday ?? true,
        autoLogoutDays: record.profiles?.auto_logout_days || null, calendarSyncInterval: record.profiles?.calendar_sync_interval || "never",
        accountPending: !!record.is_managed_profile || record.status === "pending",
        familyLinks: [], familyId: null, familyRole: null,
      };
    });
    const hydratedRoster = hydrateFamilyLinks(roster, familyData || []);
    const member = hydratedRoster.find((item) => item.id === data.id);
    if (!member) return { error: "Das Vereinsprofil konnte nicht geladen werden." };
    if (canManageFees(member)) {
      const { data: feesData, error: feesError } = await supabase.from("fee_records")
        .select("id,membership_id,year,type,amount,payment_status,invoice_number,person_count,fee_people(membership_id,manual_name)")
        .eq("club_id", clubId).order("year", { ascending: false }).order("created_at", { ascending: false });
      if (feesError) return { error: "Die Beitragsverwaltung konnte nicht geladen werden." };
      const loadedFees = (feesData || []).map((record) => ({
        id: record.id,
        memberId: record.membership_id,
        year: String(record.year),
        type: record.type,
        amount: Number(record.amount).toFixed(2).replace(".", ","),
        paid: record.payment_status === "bezahlt",
        invoiceNumber: record.invoice_number || "",
        personCount: record.person_count || 1,
        linkedMemberIds: (record.fee_people || []).map((person) => person.membership_id).filter(Boolean),
        manualNames: (record.fee_people || []).map((person) => person.manual_name).filter(Boolean),
      }));
      setFeeRecords(loadedFees);
      setFeePaid(Object.fromEntries(hydratedRoster.map((rosterMember) => {
        const entries = loadedFees.filter((fee) => fee.memberId === rosterMember.id);
        return [rosterMember.id, entries.length > 0 && entries.every((fee) => fee.paid)];
      })));
    }
    const { data: newsData, error: newsError } = await supabase.from("news_posts")
      .select("id,title,body,image_path,author_name,created_at")
      .eq("club_id", clubId).order("created_at", { ascending: true }).limit(100);
    if (newsError) return { error: "Die Vereins-News konnten nicht geladen werden." };
    const loadedNews = await Promise.all((newsData || []).map(async (post) => {
      let signedUrl;
      if (post.image_path) {
        const { data: signedImage } = await supabase.storage.from("news-images").createSignedUrl(post.image_path, 604800);
        signedUrl = signedImage?.signedUrl;
      }
      return {
        id: post.id, who: post.author_name || "Verein", init: initialsOf(post.author_name || "Verein"), color: C.ink,
        title: post.title, text: post.body, imageUrl: signedUrl, imagePath: post.image_path,
        time: new Date(post.created_at).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "2-digit" }),
      };
    }));
    setVereinsNews(loadedNews);

    /* Alles, was sich aendert und bleiben soll, kommt aus eigenen Tabellen.
       Vorher lag es als ein JSON-Klumpen in club_app_state - geschrieben
       ausschliesslich von Administratoren. Wer als Mitglied abstimmte, tippte
       oder sich in einen Helferdienst eintrug, legte das in den Arbeitsspeicher
       und verlor es beim naechsten Oeffnen. Die Tabellen dafuer gab es seit dem
       ersten Tag; benutzt hat sie nur niemand. */
    await ladeVereinsdaten(clubId, profileId, hydratedRoster);
    enterApp(member, hydratedRoster);
    return { ok: true };
  };
  /* Wer angemeldet ist, soll das auch merken.

     Bisher fragte die App beim Start nie nach einer bestehenden Sitzung. Sie
     zeigte immer Vereinsauswahl und danach das Anmeldeformular - auch wenn die
     Supabase-Sitzung noch gueltig war. Man musste sich also jedes Mal erneut
     anmelden, obwohl man angemeldet war.

     Hier wird die vorhandene Sitzung einmal gelesen und dazu, in welchen
     Vereinen dieses Konto Mitglied ist. Der Anmeldebildschirm bietet daraus
     einen Knopf an: ein Tipp, und man ist drin.

     Bewusst nur das EIGENE Konto. Frueher standen dort alle Mitglieder des
     Vereins mit Namen und Rollen, noch vor jeder Anmeldung - das war ein
     Datenschutzproblem und wurde entfernt. */
  const [offeneSitzung, setOffeneSitzung] = useState(null);
  useEffect(() => {
    if (!supabase) return;
    let abgebrochen = false;
    (async () => {
      const { data } = await supabase.auth.getSession();
      const konto = data.session?.user;
      if (!konto || abgebrochen) return;
      const { data: zugehoerig } = await supabase.from("club_memberships")
        .select("id,club_id,display_name,status")
        .eq("profile_id", konto.id)
        .in("status", ["active", "pending"]);
      if (abgebrochen) return;
      /* Gilt dieses Geraet noch? Wurde die Person zwischenzeitlich auf zwei
         anderen Geraeten angemeldet, ist dieses verdraengt worden. Dann meldet
         sich die App ab, statt weiterzulaufen, als sei nichts gewesen. */
      /* Nur eine SCHON gespeicherte Kennung kann verdraengt worden sein. Ist
         keine da, ist das ein neues Geraet - es wird angemeldet, nicht
         abgewiesen. Das betrifft jede Sitzung, die nicht ueber das
         Anmeldeformular entstanden ist: frische Registrierung, Rueckkehr ueber
         den Bestaetigungslink, neues Passwort. */
      const bekannt = gespeicherteGeraeteKennung();
      if (bekannt) {
        const { data: giltNoch } = await supabase.rpc("geraet_gilt_noch", { kennung: bekannt });
        if (giltNoch === false) {
          await supabase.auth.signOut();
          setVerdraengt(true);
          setAuthScreen("login");
          return;
        }
      }
      await geraetAnmelden(konto.id);

      setOffeneSitzung({ profileId: konto.id, email: konto.email, mitgliedschaften: zugehoerig || [] });
      /* Wer angemeldet ist, soll das Anmeldeformular gar nicht erst sehen. */
      if ((zugehoerig || []).length > 0) await nachDerAnmeldung(konto.id);
    })();
    return () => { abgebrochen = true; };
  }, []);

  /* Wiederaufnahme.
   *
   * geraet_gilt_noch und geraet_anmelden liefen bisher nur beim Kaltstart. Auf
   * iOS wird eine App aber selten beendet, sondern nur schlafen gelegt - ein
   * verdraengtes Geraet lief deshalb wochenlang mit vollem Zugriff weiter, und
   * last_seen mass den letzten App-START statt der letzten Nutzung. Das
   * taeglich benutzte Tablet sah damit aelter aus als ein Telefon, das einmal
   * im Monat neu gestartet wird - und wurde als erstes verdraengt.
   *
   * Hoechstens einmal je Stunde: Die Zahl muss nicht auf die Minute stimmen,
   * sie muss nur die richtige Reihenfolge ergeben. */
  const letzteGeraetePruefung = useRef(0);
  useEffect(() => {
    if (!supabase || typeof document === "undefined") return;
    const pruefen = async () => {
      if (document.visibilityState !== "visible") return;
      const jetzt = Date.now();
      if (jetzt - letzteGeraetePruefung.current < 3600000) return;
      letzteGeraetePruefung.current = jetzt;
      const { data } = await supabase.auth.getSession();
      const konto = data.session?.user;
      if (!konto) return;
      const bekannt = gespeicherteGeraeteKennung();
      if (!bekannt) return;
      const { data: giltNoch } = await supabase.rpc("geraet_gilt_noch", { kennung: bekannt });
      if (giltNoch === false) {
        await supabase.auth.signOut();
        setCurrentUserId(null); setSelectedClubId(null);
        setMeineMitgliedschaften([]); setOffeneSitzung(null);
        setVerdraengt(true); setAuthScreen("login");
        return;
      }
      await geraetAnmelden(konto.id);
    };
    document.addEventListener("visibilitychange", pruefen);
    return () => document.removeEventListener("visibilitychange", pruefen);
  }, []);

  useEffect(() => {
    if (!supabase) return;
    let cancelled = false;
    const finishNewClubRegistration = async () => {
      const { data: sessionData } = await supabase.auth.getSession();
      const account = sessionData.session?.user;
      const pending = account?.user_metadata?.pending_new_club;
      if (!account || !pending || cancelled) return;
      await geraetAnmelden(account.id);
      const { data: registration, error } = await supabase.rpc("register_new_club", {
        club_name: pending.name,
        club_short_name: pending.short_name,
        club_city: pending.city || "",
        club_register_number: pending.register_number,
        club_currency: pending.currency || "EUR",
        referral: pending.referral_code || null,
        member_name: account.user_metadata?.full_name || account.email?.split("@")[0] || "Mitglied",
        member_birthdate: account.user_metadata?.birthdate || null,
        club_sport: pending.sport || "rollhockey",
        club_primary_color: pending.primary_color || DEFAULT_CLUB_COLORS.primary,
        club_secondary_color: pending.secondary_color || DEFAULT_CLUB_COLORS.secondary,
      });
      if (error || cancelled) return;
      const newClubId = registration?.[0]?.club_id;
      await supabase.auth.updateUser({ data: { ...account.user_metadata, pending_new_club: null } });
      if (!newClubId || cancelled) return;

      /* Das Logo, das der Gruender vor der Bestaetigung hochgeladen hat. Es
         liegt als Datenzeile in den Kontodaten und wird jetzt erst in den
         Speicher gelegt - vorher ging es auf diesem Weg still verloren. */
      if (pending.logo) {
        try {
          const blob = await (await fetch(pending.logo)).blob();
          const pfad = `${newClubId}/logo-${Date.now()}.png`;
          const upload = await supabase.storage.from("club-logos").upload(pfad, blob, { upsert: true });
          if (!upload.error) {
            const { data: oeffentlich } = supabase.storage.from("club-logos").getPublicUrl(pfad);
            await supabase.from("clubs").update({ logo_url: oeffentlich.publicUrl }).eq("id", newClubId);
          }
        } catch {}
      }
      const { data: createdClub } = await supabase.from("clubs")
        .select("id,name,short_name,city,founded_year,logo_url,register_number,currency,referral_code,referral_credit_months,sport,primary_color,secondary_color")
        .eq("id", newClubId).single();
      if (createdClub && !cancelled) {
        setClubs((items) => [...items.filter((item) => item.id !== createdClub.id), {
          id: createdClub.id, name: createdClub.name, shortName: createdClub.short_name,
          city: createdClub.city || "—", foundedYear: createdClub.founded_year || new Date().getFullYear(),
          logoUrl: createdClub.logo_url || null, registerNumber: createdClub.register_number || "",
          currency: createdClub.currency || "EUR", referralCode: createdClub.referral_code || "",
          referralCreditMonths: createdClub.referral_credit_months || 0, sport: createdClub.sport || "rollhockey",
          primaryColor: createdClub.primary_color || DEFAULT_CLUB_COLORS.primary, secondaryColor: createdClub.secondary_color || DEFAULT_CLUB_COLORS.secondary,
        }]);
        setSelectedClubId(newClubId);
        setFeatureOnboardingClubId(newClubId);
        await loadSupabaseMembership(account.id, newClubId);
      }
    };
    finishNewClubRegistration();
    return () => { cancelled = true; };
  }, []);
  const attemptLogin = async (email, password) => {
    if (!supabase) {
      /* Hiess frueher ebenfalls "E-Mail oder Passwort ist falsch". Das war
         gleich doppelt irrefuehrend: Es ist kein Anmeldefehler, sondern eine
         fehlende Einrichtung, und niemand findet den Grund, indem er sein
         Passwort noch einmal tippt. */
      return { error: "Die App ist nicht mit der Datenbank verbunden. Bitte melde das dem Verein." };
    }
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return { error: anmeldeFehlerText(error) };
    if (!data.user) return { error: "Die Anmeldung hat nicht geklappt. Bitte versuche es noch einmal." };
    /* Ab hier gibt es eine Sitzung. Sie muss bekannt sein, damit der Beitritt
       zu einem weiteren Verein ohne erneute Anmeldung funktioniert. */
    setOffeneSitzung({ profileId: data.user.id, email: data.user.email, mitgliedschaften: [] });

    /* Ohne vorgewaehlten Verein - der Regelfall seit der Umstellung - wird
       zuerst geschaut, wo dieses Konto ueberhaupt dazugehoert. Nur wenn dabei
       gar nichts herauskommt, greifen die Sonderfaelle weiter unten (Verein aus
       der Registrierung, noch nicht bestaetigte Aufnahme). */
    await geraetAnmelden(data.user.id);

    if (!selectedClubId) {
      const ergebnis = await nachDerAnmeldung(data.user.id);
      if (ergebnis?.code !== "membership_missing") return ergebnis;
    }

    /* Wer sich bei der Registrierung fuer einen Verein entschieden hat, hat ihn
       in seinen Kontodaten stehen. Ohne diesen Rueckgriff ginge die Anmeldung
       nach dem Bestaetigungslink ins Leere: vorgewaehlt ist dann nichts, und
       der Verein aus der Registrierung wuerde uebersehen. */
    const metadata = data.user.user_metadata || {};
    const zielClub = selectedClubId || metadata.pending_club_id || null;
    const loaded = await loadSupabaseMembership(data.user.id, zielClub);
    if (loaded?.code !== "membership_missing") { if (zielClub) setSelectedClubId(zielClub); return loaded; }
    if (metadata.pending_new_club) {
      const pending = metadata.pending_new_club;
      const { data: registration, error: newClubError } = await supabase.rpc("register_new_club", {
        club_name: pending.name,
        club_short_name: pending.short_name,
        club_city: pending.city || "",
        club_register_number: pending.register_number,
        club_currency: pending.currency || "EUR",
        referral: pending.referral_code || null,
        member_name: metadata.full_name || email.split("@")[0],
        member_birthdate: metadata.birthdate || null,
        club_sport: pending.sport || "rollhockey",
        club_primary_color: pending.primary_color || DEFAULT_CLUB_COLORS.primary,
        club_secondary_color: pending.secondary_color || DEFAULT_CLUB_COLORS.secondary,
      });
      if (newClubError) return { error: "Die Vereinsregistrierung konnte nicht fertiggestellt werden." };
      const newClubId = registration?.[0]?.club_id;
      await supabase.auth.updateUser({ data: { ...metadata, pending_new_club: null } });
      if (!newClubId) return { error: "Der neue Verein konnte nicht geladen werden." };
      if (pending.logo) {
        try {
          const blob = await (await fetch(pending.logo)).blob();
          const pfad = `${newClubId}/logo-${Date.now()}.png`;
          const upload = await supabase.storage.from("club-logos").upload(pfad, blob, { upsert: true });
          if (!upload.error) {
            const { data: oeffentlich } = supabase.storage.from("club-logos").getPublicUrl(pfad);
            await supabase.from("clubs").update({ logo_url: oeffentlich.publicUrl }).eq("id", newClubId);
          }
        } catch {}
      }
      const { data: createdClub } = await supabase.from("clubs")
        .select("id,name,short_name,city,founded_year,logo_url,register_number,currency,referral_code,referral_credit_months,sport,primary_color,secondary_color")
        .eq("id", newClubId).single();
      if (createdClub) {
        setClubs((items) => [...items.filter((item) => item.id !== createdClub.id), {
          id: createdClub.id, name: createdClub.name, shortName: createdClub.short_name,
          city: createdClub.city || "—", foundedYear: createdClub.founded_year || new Date().getFullYear(),
          logoUrl: createdClub.logo_url || null, registerNumber: createdClub.register_number || "",
          currency: createdClub.currency || "EUR", referralCode: createdClub.referral_code || "",
          referralCreditMonths: createdClub.referral_credit_months || 0, sport: createdClub.sport || "rollhockey",
          primaryColor: createdClub.primary_color || DEFAULT_CLUB_COLORS.primary, secondaryColor: createdClub.secondary_color || DEFAULT_CLUB_COLORS.secondary,
        }]);
      }
      setSelectedClubId(newClubId);
      setFeatureOnboardingClubId(newClubId);
      return loadSupabaseMembership(data.user.id, newClubId);
    }
    if (!zielClub || metadata.pending_club_id !== zielClub) return loaded;
    const { error: registrationError } = await supabase.rpc("register_for_club", {
      target_club: zielClub,
      member_name: metadata.full_name || email.split("@")[0],
      account_role: metadata.account_role || "mitglied",
      member_birthdate: metadata.birthdate || null,
      member_team: metadata.requested_team || null,
    });
    if (registrationError) return { error: "Das Vereinsprofil konnte nicht fertiggestellt werden." };
    setSelectedClubId(zielClub);
    return loadSupabaseMembership(data.user.id, zielClub);
  };

  /* Apple-Richtlinie 5.1.1(v): Ein Konto, das sich anlegen lässt, muss sich auch
     in der App wieder löschen lassen. Wer einem bestehenden Verein beitritt,
     wartet auf die Freigabe — und kam bisher nie über den Anmeldebildschirm
     hinaus. Das Konto existierte in auth.users, war aus der App heraus aber
     nicht mehr erreichbar und damit auch nicht löschbar. Diese Zustände landen
     jetzt auf einer eigenen Ansicht, von der aus beides geht. */
  /* Traegt die Mitgliedschaften dieses Kontos zusammen und entscheidet, wohin
     es weitergeht: bei genau einem Verein direkt hinein, bei mehreren zur
     Auswahl, bei keinem auf die Vereinssuche. */
  const mitgliedschaftenLaden = async (profileId) => {
    const { data } = await supabase.from("club_memberships")
      .select("id,club_id,display_name,status,clubs(name,short_name)")
      .eq("profile_id", profileId)
      .in("status", ["active", "pending"]);

    const liste = (data || []).map((m) => {
      const verein = Array.isArray(m.clubs) ? m.clubs[0] : m.clubs;
      return { ...m, clubName: verein?.name || "Verein", clubShortName: verein?.short_name || "" };
    }).sort((a, b) => a.clubName.localeCompare(b.clubName, "de"));

    setMeineMitgliedschaften(liste);
    setOffeneSitzung((s) => (s ? { ...s, mitgliedschaften: liste } : s));
    return liste;
  };

  const nachDerAnmeldung = async (profileId) => {
    const liste = await mitgliedschaftenLaden(profileId);

    if (liste.length === 1) {
      setSelectedClubId(liste[0].club_id);
      return loadSupabaseMembership(profileId, liste[0].club_id);
    }
    if (liste.length > 1) { setAuthScreen("meineVereine"); return {}; }
    /* Bei keinem Verein geht es zur Suche - genau das versprach der Kommentar
       ueber dieser Funktion schon, getan hat es niemand. Ohne diese Zeile fiel
       der Aufrufer weiter durch bis zu einer Abfrage mit leerem Verein. */
    setAuthScreen("club");
    return { code: "membership_missing" };
  };

  /* Beitritt mit einem Konto, das es schon gibt. */
  const vereinBeitreten = async ({ name, art, team }) => {
    if (!supabase || !selectedClubId) return { error: "Bitte wähle zuerst einen Verein aus." };
    const { data: sitzung } = await supabase.auth.getUser();
    const profileId = sitzung?.user?.id;
    if (!profileId) return { error: "Die Sitzung ist abgelaufen. Bitte melde dich erneut an." };

    const { data, error } = await supabase.rpc("register_for_club", {
      target_club: selectedClubId, member_name: name,
      account_role: art, member_birthdate: null, member_team: team || null,
    });
    if (error) {
      return { error: /blocked/i.test(error.message || "")
        ? "Dieser Verein hat dich gesperrt. Ein Beitritt ist nicht möglich."
        : "Die Anfrage konnte nicht gesendet werden. Bitte versuche es später noch einmal." };
    }
    if (data?.[0]?.membership_status === "active") return loadSupabaseMembership(profileId, selectedClubId);
    await mitgliedschaftenLaden(profileId);
    setSelectedClubId(null);
    setAuthScreen("meineVereine");
    return {};
  };

  /* Geraetekennung: einmal erzeugt, im Geraet gespeichert.
  
     Bewusst eine Zufallszahl und keine Hardwarekennung - die gibt iOS gar nicht
     heraus, und wir wollen sie auch nicht. Wird der Speicher geleert, gilt das
     Geraet als neues; das verdraengt hoechstens das aelteste der beiden und ist
     verschmerzbar. */
  /* Lesen und Erzeugen sind zwei verschiedene Dinge, und die Unterscheidung
     entscheidet ueber die Startpruefung: Eine gespeicherte Kennung, zu der es
     keinen Eintrag mehr gibt, ist verdraengt worden. Eine gerade erst erzeugte
     Kennung ist ein neues Geraet und gehoert angemeldet.

     Vorher wurde beides in einem Aufruf erledigt. Die Kennung entstand also
     unmittelbar vor der Frage "gilt dieses Geraet noch?", die Antwort war
     zwangslaeufig nein, und die App meldete beim ersten Start nach dem Update
     jede gueltige Sitzung ab - mit der Begruendung, das Konto sei auf zwei
     anderen Geraeten angemeldet. */
  const gespeicherteGeraeteKennung = () => {
    if (typeof window === "undefined") return null;
    try { return window.localStorage.getItem("cmo-geraet"); } catch { return null; }
  };
  const geraeteKennung = () => {
    if (typeof window === "undefined") return null;
    try {
      let k = window.localStorage.getItem("cmo-geraet");
      if (!k) {
        k = (crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`);
        window.localStorage.setItem("cmo-geraet", k);
      }
      return k;
    } catch { return null; }
  };

  /* Meldet das Geraet an. Sind schon zwei andere im Einsatz, faellt das
     aelteste heraus - nicht dieses hier. Wer sein Telefon wechselt, soll sich
     einfach anmelden koennen, statt anzurufen. */
  const geraetAnmelden = async (profileId) => {
    if (!supabase || !profileId) return;
    const kennung = geraeteKennung();
    if (!kennung) return;
    const bezeichnung = typeof navigator !== "undefined" ? (Capacitor.getPlatform() === "ios" ? "iPhone" : Capacitor.getPlatform() === "android" ? "Android" : "Browser") : null;
    await supabase.rpc("geraet_anmelden", { kennung, bezeichnung });
  };

  /* Beim Abmelden den Platz wieder freigeben.
     Ohne das belegt ein aufgegebenes Geraet weiter einen der beiden Plaetze -
     und weil last_seen aus dem Moment seines letzten Starts stammt, gilt es
     sogar als juenger als ein taeglich benutztes Tablet, das nur nie neu
     gestartet wird. Verdraengt wuerde dann das falsche Geraet. */
  const geraetAbmelden = async () => {
    if (!supabase) return;
    const kennung = gespeicherteGeraeteKennung();
    if (!kennung) return;
    try { await supabase.from("user_devices").delete().eq("device_id", kennung); } catch {}
  };

  const login = async (email, password) => {
    const result = await attemptLogin(email, password);
    /* Wer auf die Freigabe wartet, sieht die Wartesansicht - dort laesst sich
       das Konto auch wieder loeschen (Apple 5.1.1(v)).
       Wer dagegen ueberhaupt keinem Verein angehoert, hat nichts, worauf er
       warten koennte: Er gehoert zur Vereinssuche, nicht in eine Ansicht, aus
       der nur Abmelden und Loeschen herausfuehren. */
    if (result?.code === "membership_pending") {
      setPendingAccount({ email, reason: result.code });
      return {};
    }
    if (result?.code === "membership_missing") {
      setAuthScreen(selectedClubId ? "beitreten" : "club");
      return {};
    }
    return result;
  };

  const vereinOeffnen = async (mitgliedschaft) => {
    setVereinLaedt(true);
    setSelectedClubId(mitgliedschaft.club_id);
    const profileId = offeneSitzung?.profileId || (await supabase.auth.getUser()).data.user?.id;
    const ergebnis = await loadSupabaseMembership(profileId, mitgliedschaft.club_id);
    setVereinLaedt(false);
    return ergebnis;
  };

  const leavePendingAccount = async () => {
    await geraetAbmelden();
    if (supabase) await supabase.auth.signOut();
    setPendingAccount(null);
    setMeineMitgliedschaften([]); setOffeneSitzung(null);
    setAuthScreen("login");
  };

  /* Abmelden aus einem Zustand ohne aktive Mitgliedschaft. Stand vorher als
     Einzeiler direkt im Aufruf von MeineVereineScreen; seit die Vereinssuche
     dasselbe anbietet, braucht es einen Namen statt zweier Kopien. */
  const sitzungBeenden = async () => {
    await geraetAbmelden();
    if (supabase) await supabase.auth.signOut();
    setMeineMitgliedschaften([]);
    setOffeneSitzung(null);
    setSelectedClubId(null);
    setAuthScreen("login");
  };
  const deletePendingAccount = async () => {
    if (!supabase) return { error: "Löschen ist nur mit einem echten Konto möglich." };
    const { data } = await supabase.auth.getSession();
    const token = data.session?.access_token;
    if (!token) return { error: "Die Sitzung ist abgelaufen. Bitte melde dich erneut an." };
    const response = await fetch("/api/account/delete", { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
    if (!response.ok) return { error: "Das Konto konnte nicht vollständig gelöscht werden. Bitte wende dich an den Support." };
    await leavePendingAccount();
    /* Beim blossen Abmelden bleibt der gewaehlte Verein absichtlich stehen -
       wer auf die Freigabe wartet, findet ihn beim naechsten Anmelden wieder.
       Nach dem Loeschen gibt es aber kein Konto mehr, zu dem er gehoeren
       koennte. */
    setSelectedClubId(null);
    return {};
  };
  const register = async (draft, familySetup) => {
    if (supabase) {
      const pendingClub = currentClub?.pendingRegistration ? currentClub : null;
      /* Ohne Verein wird nur das Konto angelegt. Danach geht es zur
         Vereinssuche - erst anmelden, dann Verein waehlen, wie ueberall sonst
         in dieser App auch. */
      const nurKonto = !pendingClub && !draft.clubId;
      const { data, error } = await supabase.auth.signUp({
        email: draft.email,
        password: draft.password,
        options: { data: {
          full_name: draft.name,
          pending_club_id: pendingClub || nurKonto ? null : draft.clubId,
          /* Das Logo gehoert mit in die Kontodaten. Ohne das ging es beim Weg ueber
             den Bestaetigungslink still verloren: Der Verein entstand, das Logo
             fehlte kommentarlos, und der Gruender lud es nicht noch einmal
             hoch - er glaubte ja, er haette es schon. */
          pending_new_club: pendingClub ? { name:pendingClub.name, short_name:pendingClub.shortName, city:pendingClub.city, register_number:pendingClub.registerNumber, currency:pendingClub.currency, referral_code:pendingClub.referralCode, sport:pendingClub.sport, primary_color:pendingClub.primaryColor, secondary_color:pendingClub.secondaryColor, logo:pendingClub.logoDataUrl || null } : null,
          account_role: familySetup?.accountType || "mitglied",
          birthdate: draft.birthdate || null,
          requested_team: draft.team || null,
        } },
      });
      if (error) return { error: error.message === "User already registered" ? "Für diese E-Mail existiert bereits ein Konto." : error.message };
      if (!data.session || !data.user) {
        return { ok: true, message: nurKonto
          ? "Dein Konto ist angelegt. Bitte bestätige jetzt die E-Mail — danach meldest du dich an und suchst deinen Verein."
          : "Bitte bestätige jetzt die E-Mail. Danach kannst du dich anmelden und die Vereinsregistrierung abschließen." };
      }
      /* Wer sich hier anmeldet, ist angemeldet - und muss deshalb als Geraet
         eingetragen sein. Ohne das haette das neue Konto null Eintraege, und
         der naechste Kaltstart haette es mit der Begruendung abgemeldet, es sei
         auf zwei anderen Geraeten in Benutzung. */
      await geraetAnmelden(data.user.id);

      /* Konto ohne Verein: Es gibt nichts zu registrieren, nur weiterzugehen. */
      if (nurKonto) {
        setOffeneSitzung({ profileId: data.user.id, email: data.user.email, mitgliedschaften: [] });
        setAuthScreen("club");
        return {};
      }

      let registration; let registrationError;
      if (pendingClub) {
        const result = await supabase.rpc("register_new_club", { club_name:pendingClub.name, club_short_name:pendingClub.shortName, club_city:pendingClub.city, club_register_number:pendingClub.registerNumber, club_currency:pendingClub.currency||"EUR", referral:pendingClub.referralCode||null, member_name:draft.name, member_birthdate:draft.birthdate||null, club_sport:pendingClub.sport||"rollhockey", club_primary_color:pendingClub.primaryColor||DEFAULT_CLUB_COLORS.primary, club_secondary_color:pendingClub.secondaryColor||DEFAULT_CLUB_COLORS.secondary });
        registration=result.data; registrationError=result.error;
        const newClubId=registration?.[0]?.club_id;
        if(!registrationError&&newClubId&&pendingClub.logoDataUrl){try{const blob=await (await fetch(pendingClub.logoDataUrl)).blob();const path=`${newClubId}/logo-${Date.now()}.png`;const upload=await supabase.storage.from("club-logos").upload(path,blob,{upsert:true});if(!upload.error){const {data:publicLogo}=supabase.storage.from("club-logos").getPublicUrl(path);await supabase.from("clubs").update({logo_url:publicLogo.publicUrl}).eq("id",newClubId);}}catch{}}
        if(!registrationError&&newClubId){
          setClubs((items)=>[...items.filter((item)=>item.id!==newClubId), {
            id:newClubId, name:pendingClub.name, shortName:pendingClub.shortName,
            city:pendingClub.city||"—", foundedYear:new Date().getFullYear(),
            logoUrl:pendingClub.logoDataUrl||null, registerNumber:pendingClub.registerNumber||"",
            currency:pendingClub.currency||"EUR", referralCode:pendingClub.referralCode||"", referralCreditMonths:0,
            sport:pendingClub.sport||"rollhockey",
            primaryColor:pendingClub.primaryColor||DEFAULT_CLUB_COLORS.primary, secondaryColor:pendingClub.secondaryColor||DEFAULT_CLUB_COLORS.secondary,
          }]);
          setSelectedClubId(newClubId);setFeatureOnboardingClubId(newClubId);return loadSupabaseMembership(data.user.id,newClubId);
        }
      } else {
        const result = await supabase.rpc("register_for_club", { target_club:draft.clubId, member_name:draft.name, account_role:familySetup?.accountType||"mitglied", member_birthdate:draft.birthdate||null, member_team:draft.team||null });
        registration=result.data; registrationError=result.error;
      }
      if (registrationError) return { error: "Das Konto wurde erstellt, aber das Vereinsprofil konnte nicht angelegt werden." };
      if (registration?.[0]?.membership_status === "pending") {
        await supabase.auth.signOut();
        return { ok: true, message: "Dein Konto wurde erstellt. Der Vereins-Administrator muss deine Mitgliedschaft noch freigeben." };
      }
      return loadSupabaseMembership(data.user.id, draft.clubId);
    }
    setMembers((ms) => {
      let next = [...ms];
      next.push({ ...draft, familyId: null, familyRole: null, familyLinks: [] });
      if (familySetup?.relativeId) {
        next = linkFamilyRecords(next, draft.id, familySetup.relativeId, familySetup.accountType === "eltern" ? "eltern" : "kind");
      }
      if (familySetup?.child) {
        const childId = `dependent-${Date.now()}`;
        const child = { id: childId, clubId: draft.clubId, name: familySetup.child.name, email: "", password: "", team: familySetup.child.team || "U11", number: null, since: new Date().getFullYear(), roles: ["mitglied", "spieler"], color: AVATAR_FARBEN[2], points: 0, tippPoints: 0, badges: [], birthdate: familySetup.child.birthdate || "", accountPending: true, familyLinks: [] };
        next = linkFamilyRecords([...next, child], draft.id, childId, "eltern");
      }
      return next;
    });
    setFeePaid((f) => ({ ...f, [draft.id]: false }));
    /* Der Willkommensgruss stand hier als Nachricht in einem Kanal mit der
       Kennung "news" - den es fuer echte Vereine nicht gibt. Er landete also im
       Arbeitsspeicher des Anlegenden und war beim naechsten Oeffnen weg.
       Geschrieben wird er jetzt in der Datenbank (Trigger willkommens_news),
       damit ihn auch der Begruesste sieht. */
    setCurrentUserId(draft.id);
    setTab("home");
    return { ok: true };
  };
  /* Seit dem Wegfall des In-App-Kaufs gibt es keine Store-Kennung mehr zu
     trennen. */
  /* Abmelden heisst: nichts vom alten Konto bleibt stehen.
     Vorher landete man auf der Vereinssuche, deren "Zurueck" wegen der noch
     gefuellten Mitgliedschaftsliste auf "Deine Vereine" des GERADE
     abgemeldeten Kontos fuehrte - und im Anmeldeformular bot die Karte
     "Angemeldet bleiben" Name und E-Mail des Vorgaengers an. Auf einem
     geteilten Vereinsgeraet ist das keine Kleinigkeit. */
  const logout = async () => {
    await geraetAbmelden();
    if (supabase) await supabase.auth.signOut();
    setCurrentUserId(null); setSelectedClubId(null);
    setMeineMitgliedschaften([]); setOffeneSitzung(null); setPendingAccount(null);
    setAuthScreen("login"); setTab("home"); setTabHistory([]); setSubView(null); setStartseiteTeam(null);
  };
  useEffect(() => {
    if (!currentUser || !currentUser.autoLogoutDays) return;
    const timeoutMs = Number(currentUser.autoLogoutDays) * 24 * 60 * 60 * 1000;
    const storageKey = `cmo-last-activity-${currentUser.authProfileId || currentUser.id}`;
    if (!localStorage.getItem(storageKey)) localStorage.setItem(storageKey, String(Date.now()));
    let lastRecorded = 0;
    const recordActivity = () => {
      const now = Date.now();
      if (now - lastRecorded < 60_000) return;
      lastRecorded = now;
      localStorage.setItem(storageKey, String(now));
    };
    const check = () => {
      const lastActivity = Number(localStorage.getItem(storageKey) || Date.now());
      if (Date.now() - lastActivity >= timeoutMs) logout();
    };
    const eventsToWatch = ["pointerdown", "keydown", "touchstart", "scroll"];
    eventsToWatch.forEach((eventName) => window.addEventListener(eventName, recordActivity, { passive: true }));
    const timer = window.setInterval(check, 60_000);
    check();
    return () => {
      window.clearInterval(timer);
      eventsToWatch.forEach((eventName) => window.removeEventListener(eventName, recordActivity));
    };
  }, [currentUser?.id, currentUser?.autoLogoutDays]);
  /* "Verein wechseln" fuehrt zu den eigenen Vereinen, nicht in die Suche nach
     fremden. Die Sitzung bleibt bestehen; wer wirklich einen weiteren Verein
     sucht, kommt von dort aus mit einem Tipp weiter. */
  const returnToClubOverview = () => {
    setCurrentUserId(null); setSelectedClubId(null);
    setAuthScreen(meineMitgliedschaften.length > 0 ? "meineVereine" : "club");
    setTab("home"); setTabHistory([]); setSubView(null); setEventFocusRequest(null); setStartseiteTeam(null);
  };
  /* "Alle ansehen" unter den Vereins-News.
     Stand vorher auf setChatChannelId("news") + Chat-Reiter - ein Rest aus der
     Zeit, als die News ein Chat-Kanal mit der Kennung "news" waren (der steht
     noch in den Ruecckfalldaten, INITIAL_CHANNELS). Seit die News eine eigene
     Tabelle haben, gibt es diesen Kanal nicht mehr: Der Chat oeffnete
     stattdessen den erstbesten Mannschaftskanal, und wer auf "Alle ansehen"
     tippte, landete in einem leeren Chat. Die vollstaendige Liste steht heute
     im Reiter Redaktion. */
  const goNews = () => navigateTab("redaktion");
  /* Die Mannschaftswahl der Startseite liegt hier oben und nicht im Dashboard:
     Der Container weiter unten traegt key={`${tab}-${subView}`} und montiert
     bei jedem Reiterwechsel neu. Im Dashboard waere die Wahl also schon weg,
     sobald jemand kurz auf Termine und zurueck tippt.
     null heisst "noch nichts ausgewaehlt" - dann gilt die berechnete
     Voreinstellung. Ein fester Startwert waere hier falsch: Beim ersten
     Rendern stehen in events noch die Demo-Termine und currentUser hat unter
     Umstaenden noch keine Mannschaften. Die Ableitung unten zieht automatisch
     nach, sobald die echten Daten da sind. */
  /* Zur Wahl stehen alle Mannschaften mit Terminen - auch vergangenen, damit
     die Auswahl nicht verschwindet, nur weil gerade nichts ansteht. */
  const startseiteMannschaften = [...new Set((events || []).map((e) => e.team).filter(Boolean))];
  const eigeneMannschaften = currentUser
    ? [...new Set([...memberPlayerTeams(currentUser), ...(currentUser.teams || []), currentUser.managedTeam].filter(Boolean))]
    : [];
  /* Die eigenen Mannschaften zuerst, nach Rang - der Vorstand kann weiter jede
     andere nachsehen, muss die eigene aber nicht suchen. */
  const startseiteAuswahl = auswahlReihenfolge(startseiteMannschaften, eigeneMannschaften);
  /* Eine getroffene Wahl gilt, solange es die Mannschaft noch gibt. Sonst die
     Voreinstellung: die hoechste Mannschaft, in der man selbst spielt. */
  const startseiteWahl = startseiteTeam && startseiteMannschaften.includes(startseiteTeam)
    ? startseiteTeam
    : standardMannschaft({
        gespeichert: currentUser?.teamFilter,
        spielt: memberPlayerTeams(currentUser || {}),
        zugeordnet: eigeneMannschaften,
        vorhanden: startseiteMannschaften,
      });
  /* Der Sprung von der Spielkachel in die Terminliste nimmt dieselbe
     Mannschaft mit - sonst zeigt die Liste eine andere als die Kachel. */
  const goToMyNextMatch = () => { setEventFocusRequest({ team: startseiteWahl || "alle", requestedAt: Date.now() }); navigateTab("events"); };
  /* Gezaehlt wird an der Anzeige selbst, damit die Zahl auch die Mitglieder
     erfasst - und nicht nur die Administratoren, die als einzige den
     Zustandsblock speichern durften. Fehler bleiben still: Eine nicht
     gezaehlte Einblendung ist kein Grund, dem Mitglied etwas anzuzeigen. */
  const zaehle = (slotKey, art) => {
    const id = werbeplaetze?.[slotKey]?.id;
    if (!supabase || !id) return;
    supabase.rpc("anzeige_zaehlen", { ziel: id, art }).then(() => {}, () => {});
  };
  const onSponsorImpression = (slotKey) => zaehle(slotKey, "impression");
  const onSponsorClick = (slotKey) => zaehle(slotKey, "klick");
  /* Der Knopf hiess "Alle Aktivitaetsdaten zuruecksetzen" und versprach genau
     das. Getan hat er etwas anderes: Er schrieb nichts in die Datenbank,
     sondern ersetzte den Bildschirminhalt durch die Demo-Daten des ERG
     Iserlohn - zehn erfundene Spiele in der Hemberghalle, vier Chatkanaele mit
     erfundenen Nachrichten. Nach dem Neuladen war alles wieder da.
     Fuer einen echten Verein war das kein Zuruecksetzen, sondern das
     Unterschieben fremder Inhalte. Deshalb tut er das nur noch da, wo es
     stimmt: im Demo-Betrieb ohne Datenbank. */
  const resetDemoData = () => {
    if (supabase) return { error: "Im laufenden Betrieb gibt es nichts zurückzusetzen. Einzelne Termine, News und Umfragen lassen sich dort löschen, wo sie stehen." };
    setCarpools({}); setSeasonVotes({}); setTippPredictions({}); setTippResults({});
    setRemindersSent({});
    setFeePaid(INITIAL_FEE_PAID); setFeeRecords(INITIAL_FEE_RECORDS); setEvents(EVENTS); setDutyPlan(INITIAL_DUTY_PLAN); setChannels(INITIAL_CHANNELS);
    return {};
  };
  const saveTippResult = (matchId, result) => {
    ergebnisSpeichern(matchId, result);
    setTippResults((currentResults) => {
      const nextResults = { ...currentResults, [matchId]: result };
      setMembers((currentMembers) => currentMembers.map((member) => ({
        ...member,
        tippPoints: totalTippPoints(member.id, tippPredictions, nextResults, tippBegegnungen(events)),
      })));
      return nextResults;
    });
    if (supabase && currentUser?.clubId) supabase.rpc("notify_club", { target_club: currentUser.clubId, p_notif_type: "tipp", p_title: "Tippspiel-Ergebnis eingetragen", p_body: "Ein Spielergebnis wurde eingetragen. Schau nach, wie viele Punkte du gemacht hast!" });
  };

  const currentUserIsAdmin = isAdmin(currentUser);
  const currentUserCanEditNews = canWriteNews(currentUser);
  const currentUserCanEditSponsors = canManageSponsors(currentUser);
  const currentUserCanManageDuty = canManageDuty(currentUser);
  const currentUserCanManageFees = canManageFees(currentUser);
  const TABS = baseTabs(currentUserIsAdmin, currentUserCanEditNews, currentUserCanEditSponsors, currentUserCanManageFees, currentUserCanManageDuty);
  const clubPrimary = currentClub?.primaryColor || DEFAULT_CLUB_COLORS.primary;
  const clubSecondary = currentClub?.secondaryColor || DEFAULT_CLUB_COLORS.secondary;
  /* Alle abgeleiteten Toene werden hier einmal ausgerechnet und als Variablen
     gesetzt. So haengt die ganze App an zwei Werten, und keine einzige Regel
     braucht color-mix. */
  const themeVars = {
    "--club-primary": clubPrimary,
    "--club-primary-dark": darkenHex(clubPrimary),
    "--club-primary-soft": mischeHex(clubPrimary, 0.12),
    "--club-primary-border": mischeHex(clubPrimary, 0.28),
    "--club-primary-light": mischeHex(clubPrimary, 0.62),
    "--club-primary-wash": hexMitDeckkraft(clubPrimary, 0.22),
    "--club-secondary": clubSecondary,
    "--club-secondary-dark": mischeHex(clubSecondary, 0.7, false),
    "--club-secondary-soft": mischeHex(clubSecondary, 0.14),
    "--club-secondary-border": mischeHex(clubSecondary, 0.32),
    "--club-secondary-light": mischeHex(clubSecondary, 0.55),
    "--club-secondary-wash": hexMitDeckkraft(clubSecondary, 0.18),
  };

  /* Nur-App-Betrieb.
   *
   * Die Vereins-Oberflaeche soll es ausschliesslich als App aus dem Store
   * geben, nicht im Browser. Der Server bleibt trotzdem noetig: Die native
   * Huelle laedt ihre Oberflaeche von hier, und die API-Routen (Abos,
   * Kalender-Abo, Kontoloeschung) laufen ebenfalls hier.
   * Gesperrt wird also nur die Ansicht im Browser, nicht der Dienst.
   *
   * Rechtsseiten bleiben oeffentlich erreichbar - eigene Routen unter
   * /nutzungsbedingungen, /datenschutz und /impressum, die diese Sperre gar
   * nicht durchlaufen. Apple verlangt das; genau daran ist die erste
   * Einreichung gescheitert.
   *
   * Bewusst ohne Schalter: Die Nutzung soll ausschliesslich ueber die
   * installierte App laufen. Wer die Adresse im Browser oeffnet, bekommt den
   * Weg in den Store gezeigt - keine Anmeldung, kein Zugang. */
  if (imGeraet === null) return <div style={{ minHeight: "100vh", background: C.paper }} />;
  if (!imGeraet) return <NurAlsAppHinweis />;

  /* Ohne Datenbank faellt die App in den Demo-Betrieb: achtzehn erfundene
     Konten mit echten Namen und dem Passwort "demo", zehn erfundene Termine in
     der Hemberghalle Iserlohn. Fuer die Entwicklung ist das praktisch.
     Im Betrieb waere es eine Katastrophe mit Ansage - eine falsch gesetzte
     Variable in Vercel macht aus der Produktions-App eine Demo, ohne dass
     irgendwo ein Fehler sichtbar wuerde, und Aenderungen an app/ gehen ohne
     Apple-Pruefung live. Also lieber laut scheitern. */
  if (!supabase && process.env.NODE_ENV === "production") return <KonfigurationFehlt />;

  return (
    <div className="erg-app erg-shell w-full flex items-center justify-center" style={{ fontFamily: "Inter", ...themeVars }}>
      <style>{FONTS}</style>
      <div className="erg-canvas erg-frame relative w-full flex flex-col overflow-hidden">
        {showSplash && <AppSplashIntro onDone={() => setShowSplash(false)} />}
        {!currentUser ? (
          pendingAccount ? (
            <PendingAccountScreen account={pendingAccount} onLeave={leavePendingAccount} onDelete={deletePendingAccount} />
          ) : authScreen === "meineVereine" ? (
            <MeineVereineScreen
              mitgliedschaften={meineMitgliedschaften}
              laedt={vereinLaedt}
              onOeffnen={vereinOeffnen}
              onWeitererVerein={() => setAuthScreen("club")}
              onAbmelden={sitzungBeenden}
              onKontoLoeschen={offeneSitzung ? deletePendingAccount : null}
            />
          ) : authScreen === "club" ? (
            <ClubSelectScreen clubs={clubs} onSelect={selectClub} goNewClub={() => setAuthScreen("newclub")}
              onAbmelden={offeneSitzung ? sitzungBeenden : null}
              onKontoLoeschen={offeneSitzung ? deletePendingAccount : null}
              goBack={meineMitgliedschaften.length > 0 ? () => setAuthScreen("meineVereine") : () => setAuthScreen("login")} />
          ) : authScreen === "beitreten" ? (
            <BeitrittsScreen club={currentClub}
              vorschlagName={meineMitgliedschaften[0]?.display_name || ""}
              onBeitreten={vereinBeitreten}
              goBack={() => { setSelectedClubId(null); setAuthScreen(meineMitgliedschaften.length > 0 ? "meineVereine" : "club"); }} />
          ) : authScreen === "newclub" ? (
            <NewClubScreen onCreate={createClub} goBack={() => setAuthScreen("club")} />
          ) : authScreen === "login" ? (
            <LoginScreen onLogin={login} members={clubMembers} club={currentClub} goRegister={() => setAuthScreen("register")} goChangeClub={changeClub}
              verdraengt={verdraengt} onVerdraengtGelesen={() => setVerdraengt(false)}
              offeneSitzung={offeneSitzung}
              onSitzungNutzen={async (mitgliedschaft) => {
                /* Die Sitzung ist gueltig, die Mitgliedschaft gehoert diesem
                   Konto - es braucht also keine erneute Anmeldung, nur das
                   Laden des Vereins. */
                setSelectedClubId(mitgliedschaft.club_id);
                return loadSupabaseMembership(offeneSitzung.profileId, mitgliedschaft.club_id);
              }} />
          ) : (
            <RegisterScreen onRegister={register} members={clubMembers} club={currentClub} goLogin={() => setAuthScreen("login")} />
          )
        ) : featureOnboardingClubId && featureOnboardingClubId === currentUser.clubId ? (
          <ClubFeatureOnboarding club={currentClub} onDone={() => { setFeatureOnboardingClubId(null); loadClubFeatures(); }} />
        ) : (
          <>
            {subView ? (
              <div className="erg-topbar flex items-center gap-3 px-4 pt-3 pb-2 flex-shrink-0">
                <button onClick={() => setSubView(null)} className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
                  <ArrowLeft size={15} style={{ color: C.ink }} />
                </button>
                <div className="text-sm" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{SUBVIEW_TITLES[subView]}</div>
              </div>
            ) : (
              <div className="erg-topbar flex items-center px-4 pt-3 pb-2 flex-shrink-0">
                <div className="flex items-center gap-2">
                  {tabHistory.length > 0 ? (
                    <button onClick={goBack} aria-label="Zurück" className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: C.glass, border: `1px solid ${C.line}` }}>
                      <ArrowLeft size={15} style={{ color: C.ink }} />
                    </button>
                  ) : (
                    <ClubLogo club={currentClub} size={32} rounded={8} />
                  )}
                  <div>
                    <div className="text-xs leading-none" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink, letterSpacing: 0.5 }}>{currentClub?.shortName}</div>
                    <div className="text-[10px]" style={{ color: C.textDim }}>seit {currentClub?.foundedYear}</div>
                  </div>
                  {/* Die Glocke. Sie zeigt nur eine Zahl, wenn es etwas zu
                      sehen gibt - eine dauerhaft leere Glocke waere ein Knopf,
                      den niemand mehr ansieht. */}
                  <button onClick={() => { setSubView("postfach"); postfachLaden(); }} aria-label={`Benachrichtigungen${ungelesen ? `, ${ungelesen} ungelesen` : ""}`}
                    className="ml-auto w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 relative"
                    style={{ background: C.glass, border: `1px solid ${C.edge}` }}>
                    <Bell size={15} style={{ color: C.ink }} />
                    {ungelesen > 0 && (
                      <span className="absolute -top-1 -right-1 min-w-[16px] h-4 px-1 rounded-full flex items-center justify-center text-[9px] font-bold"
                        style={{ background: C.red, color: C.white }}>{ungelesen > 99 ? "99+" : ungelesen}</span>
                    )}
                  </button>
                  <button onClick={returnToClubOverview} className="ml-2 px-3 py-1.5 rounded-full text-[10px] font-bold whitespace-nowrap flex-shrink-0" style={{background:C.glass,border:`1px solid ${C.edge}`,color:C.textDim}}>Verein wechseln</button>
                </div>
              </div>
            )}

            {/* Nicht geladene Vereinsdaten sehen sonst aus wie nie eingetragene.
                Der Unterschied entscheidet darueber, ob jemand seine Arbeit fuer
                verloren haelt - er gehoert also gesagt. */}
            {/* Ein misslungener Schreibvorgang muss gesagt werden. Er
                verschwindet beim naechsten Antippen wieder - stehen bleiben
                soll er nur, bis er gelesen ist. */}
            {schreibFehler && (
              <button onClick={() => setSchreibFehler("")} role="status"
                className="px-4 py-2 text-xs text-center flex-shrink-0 w-full"
                style={{ background: C.fehlerFlaeche, color: C.fehler, fontFamily: "Inter", fontWeight: 600, borderBottom: C.fehlerRand }}>
                {schreibFehler} <span style={{ opacity: .6 }}>(tippen zum Ausblenden)</span>
              </button>
            )}
            {datenFehler && (
              <div role="status" className="px-4 py-2 text-xs text-center flex-shrink-0" style={{ background: C.sekundaerWeich, color: C.ink, fontFamily: "Inter", fontWeight: 600, borderBottom: `1px solid ${C.edge}` }}>
                Diese Bereiche konnten nicht geladen werden: {datenFehler.join(", ")}. Sie sind nicht verloren — bitte später noch einmal öffnen.
              </div>
            )}
            {maintenanceMode && (
              <div className="px-4 py-2 text-xs text-center flex-shrink-0" style={{ background: C.fehlerFlaeche, color: C.fehler, fontFamily: "Inter", fontWeight: 600, borderBottom: C.fehlerRand }}>
                🔧 Wartungsmodus aktiv — einige Inhalte können sich kurzfristig ändern.
              </div>
            )}

            <div key={`${tab}-${subView || ""}`} className="tabFade flex-1 overflow-y-auto" style={{ background: C.paper }}>
              {subView === "season" && featureEnabled("season_award") && <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Athlet/in der Saison"><SeasonVoteView currentUser={currentUser} members={clubMembers} seasonVotes={seasonVotes} setSeasonVotes={setSeasonVotes} onVote={saisonStimmeAbgeben} /></LockedFeature>}
              {subView === "tipp" && featureEnabled("tippspiel") && <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Tippspiel"><TippView members={clubMembers} currentUser={currentUser} events={events} tippPredictions={tippPredictions} setTippPredictions={setTippPredictions} tippResults={tippResults} onTippSpeichern={tippSpeichern} /></LockedFeature>}
              {subView === "postfach" && <PostfachView eintraege={postfach} laedt={postfachLaedt} onGelesen={postfachGelesen} onLoeschen={postfachLoeschen} />}
              {subView === "duty" && featureEnabled("duty_roster") && <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Helferplanung"><DutyView members={clubMembers} currentUser={currentUser} events={events} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} onDienstSetzen={dienstSetzen} /></LockedFeature>}
              {subView === "tasks" && <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Aufgaben"><TasksView currentUser={currentUser} members={clubMembers} /></LockedFeature>}
              {subView === "vehicles" && featureEnabled("vehicle_booking") && <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Vereinsfahrzeuge"><VehiclesView currentUser={currentUser} currentClub={currentClub} /></LockedFeature>}

              {!subView && tab === "home" && (
                <Dashboard user={currentUser} members={clubMembers} events={events} feePaid={!!feePaid[currentUser.id]} channels={channels} news={vereinsNews} dutyPlan={dutyPlan} seasonVotes={seasonVotes} tippPredictions={tippPredictions} tippResults={tippResults} polls={polls} setPolls={setPolls} onVote={stimmeAbgeben}
                  werbeplaetze={werbeplaetze} onSponsorImpression={onSponsorImpression} onSponsorClick={onSponsorClick}
                  goEvents={goToMyNextMatch} goSeason={() => setSubView("season")} goTipp={() => setSubView("tipp")} goDuty={() => setSubView("duty")} goTasks={() => setSubView("tasks")} goVehicles={() => setSubView("vehicles")} goNews={currentUserCanEditNews ? goNews : null}
                  currentClub={currentClub} featureEnabled={featureEnabled} dashboardTileOrder={dashboardTileOrder} entitlement={entitlement} goSubscribe={goSubscribe}
                  mannschaften={startseiteAuswahl} gewaehlteMannschaft={startseiteWahl} onMannschaftWechsel={setStartseiteTeam} />
              )}
              {!subView && tab === "events" && (
                <EventsView currentUser={currentUser} members={clubMembers} events={events} setEvents={setEvents} carpools={carpools} setCarpools={setCarpools}
                  dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} onDienstSetzen={dienstSetzen} entitlement={entitlement} goSubscribe={goSubscribe}
                  werbeplaetze={werbeplaetze} onSponsorImpression={onSponsorImpression} onSponsorClick={onSponsorClick}
                  focusRequest={eventFocusRequest} onFocusApplied={()=>setEventFocusRequest(null)}
                  currentClub={currentClub} featureEnabled={featureEnabled} />
              )}
              {!subView && tab === "teams" && <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Teams-Verwaltung"><TeamsView currentUser={currentUser} members={clubMembers} setMembers={setMembers} currentClub={currentClub} /></LockedFeature>}
              {!subView && tab === "fees" && currentUserCanManageFees && <FeesView members={clubMembers} records={feeRecords} setRecords={setFeeRecords} />}
              {!subView && tab === "chat" && <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Chat"><ChatView user={currentUser} channels={channels} setChannels={setChannels} activeId={chatChannelId} setActiveId={setChatChannelId} members={clubMembers} /></LockedFeature>}
              {!subView && tab === "redaktion" && currentUserCanEditNews && <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Redaktion"><RedaktionView user={currentUser} news={vereinsNews} setNews={setVereinsNews} /></LockedFeature>}
              {!subView && tab === "admin" && (currentUserIsAdmin || currentUserCanEditSponsors) && (
                <LockedFeature entitlement={entitlement} goSubscribe={goSubscribe} feature="Verwaltung">
                <AdminView members={clubMembers} setMembers={setMembers} events={events} feePaid={feePaid} setFeePaid={setFeePaid} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} seasonVotes={seasonVotes}
                  currentUser={currentUser} channels={channels} setChannels={setChannels} maintenanceMode={maintenanceMode} setMaintenanceMode={setMaintenanceMode} onResetDemo={resetDemoData}
                  protocols={protocols} setProtocols={setProtocols} remindersSent={remindersSent} setRemindersSent={setRemindersSent}
                  welcomeAutomation={welcomeAutomation} setWelcomeAutomation={setWelcomeAutomation} billingAutomation={billingAutomation} setBillingAutomation={setBillingAutomation}
                  werbeplaetze={werbeplaetze} onWerbeplaetzeGeaendert={ladeWerbeplaetze} polls={polls} setPolls={setPolls}
                  onUmfrageAnlegen={umfrageAnlegen} onUmfrageUmschalten={umfrageUmschalten} onDienstSetzen={dienstSetzen}
                  onProtokollSpeichern={protokollSpeichern} onAufgabeUmschalten={aufgabeUmschalten}
                  onEinstellung={vereinseinstellungSetzen} onErinnerung={erinnerungVermerken}
                  tippResults={tippResults} onSaveTippResult={saveTippResult}
                  dashboardTileOrder={dashboardTileOrder} setDashboardTileOrder={setDashboardTileOrder}
                  currentClub={currentClub} onClubLogoUpdated={updateCurrentClubLogo} onClubColorsUpdated={updateCurrentClubColors} clubFeatures={clubFeatures} onClubFeaturesChanged={loadClubFeatures} />
                </LockedFeature>
              )}
              {!subView && tab === "profile" && <ProfileView ziel={profilZiel} onZielErreicht={() => setProfilZiel("")} user={currentUser} members={clubMembers} setMembers={setMembers} currentClub={currentClub} dutyPlan={dutyPlan} punkteZiel={punkteZiel} punktePraemie={punktePraemie} werbeplaetze={werbeplaetze} onSponsorImpression={onSponsorImpression} onSponsorClick={onSponsorClick} onLogout={logout} clubFeatures={clubFeatures} onClubFeaturesChanged={loadClubFeatures} entitlement={entitlement} goSubscribe={goSubscribe} dashboardTileOrder={dashboardTileOrder} setDashboardTileOrder={setDashboardTileOrder} />}
            </div>

            {!subView && (
              <div ref={navRef} className="erg-navwrap absolute bottom-0 left-0 right-0 px-3 pt-2 pointer-events-none" style={{ display: tastaturOffen ? "none" : undefined }}>
                <div className="flex items-center justify-around rounded-3xl p-1.5 pointer-events-auto" style={{ background: "rgba(255,255,255,0.62)", border: `1px solid ${C.edge}`, boxShadow: "0 14px 34px rgba(60,30,45,0.14)" }}>
                  {TABS.map((t) => {
                    const activeTab = tab === t.id;
                    return (
                      <button key={t.id} onClick={() => navigateTab(t.id)} className="flex flex-col items-center gap-1 flex-1 py-2 rounded-2xl"
                        style={activeTab ? { background: `linear-gradient(155deg, color-mix(in srgb, ${C.red} 78%, #fff), ${C.red})`, boxShadow: `0 8px 18px color-mix(in srgb, ${C.red} 38%, transparent)` } : undefined}>
                        <t.icon size={18} style={{ color: activeTab ? "#fff" : C.textDim }} strokeWidth={activeTab ? 2.4 : 2} />
                        <span className="text-[9px]" style={{ fontFamily: "Inter", fontWeight: activeTab ? 700 : 500, color: activeTab ? "#fff" : C.textDim }}>{t.label}</span>
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
