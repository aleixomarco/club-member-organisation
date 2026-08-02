"use client";
import React, { useState, useEffect } from "react";
import {
  Home, CalendarDays, Wallet, MessageCircle, User, ChevronRight,
  Check, X, Users, Award, Gift, MapPin, Clock, Send,
  Trophy, Flame, Cake, Megaphone, Euro, CheckCircle2, Circle, Car,
  Sparkles, Image as ImageIcon, ChevronDown, Star, Mail, Lock, LogOut,
  ShieldCheck, ArrowRight, ArrowLeft, AlertCircle, UserPlus, Eye, EyeOff,
  Target, ClipboardList, Newspaper
} from "lucide-react";
import { isSupabaseConfigured, supabase } from "@/lib/supabase";

/* ------------------------------------------------------------------ */
/* Tokens                                                              */
/* ------------------------------------------------------------------ */
const C = {
  red: "#C8102E",
  redDark: "#8E0C21",
  ink: "#14151A",
  asphalt: "#202127",
  paper: "#F6F3EC",
  paperDim: "#EDE9DF",
  white: "#FFFFFF",
  amber: "#F2B134",
  green: "#2F9E58",
  line: "#E1DCD0",
  textDim: "#6B6A66",
};

const FONTS = `
@import url('https://fonts.googleapis.com/css2?family=Oswald:wght@500;600;700&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500;700&display=swap');
* { -webkit-tap-highlight-color: transparent; }
html { scroll-behavior: smooth; }
button { transition: transform .12s ease, opacity .12s ease, background-color .15s ease; }
button:active { transform: scale(0.97); }
.tabFade { animation: tabFadeIn .22s ease; }
@keyframes tabFadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }
.erg-app ::-webkit-scrollbar { width: 0px; height: 0px; }
`;

const TEAMS = ["Herren 1", "Herren 2", "Damen 1", "U15", "U11", "Eltern / Angehörige"];
const DEMO_CLUB_ID = "00000000-0000-4000-8000-000000000001";
const STATION_CAP = 2;

/* ------------------------------------------------------------------ */
/* Badge library                                                       */
/* ------------------------------------------------------------------ */
const BADGE_LIBRARY = {
  streak: { icon: Flame, label: "10x in Folge da", desc: "Trainings-Streak" },
  loyalty: { icon: Trophy, label: "Vereinstreue", descFor: (m) => `Mitglied seit ${m.since}` },
  fairplay: { icon: Award, label: "Fair-Play Award", desc: "Saison 2025" },
  referrer: { icon: Users, label: "Werber", desc: "2 Freunde eingeladen" },
};

function initialsOf(name) {
  return name.split(" ").map((p) => p[0]).slice(0, 2).join("").toUpperCase();
}

function ClubLogo({ club, size = 36, rounded = 10 }) {
  return <div className="flex items-center justify-center flex-shrink-0 overflow-hidden" style={{ width: size, height: size, borderRadius: rounded, background: C.red }}>
    {club?.logoUrl
      ? <img src={club.logoUrl} alt={`Vereinslogo ${club.name}`} className="w-full h-full object-cover" />
      : <span style={{ color: "#fff", fontFamily: "Oswald", fontWeight: 700, fontSize: Math.max(13, size * .38) }}>{club?.shortName?.[0] || "V"}</span>}
  </div>;
}

/* Rollen: jedes Profil kann mehrere Rollen gleichzeitig haben */
const ROLE_META = {
  vereinsadmin: { label: "Vereins-Administrator", color: "#1F7A5C", admin: true, formalMember: true, selfService: false },
  sysadmin: { label: "Sys-Admin", color: "#4A4E9E", admin: true, formalMember: true, selfService: false },
  vorstand: { label: "Vorstand", color: C.red, admin: true, formalMember: true, selfService: false },
  geschaeftsfuehrung: { label: "Geschäftsführung", color: C.ink, admin: true, formalMember: true, selfService: false },
  finanzmanager: { label: "Finanzmanager", color: "#176B87", admin: false, formalMember: true, selfService: false },
  redakteur: { label: "Redakteur", color: "#B15CC9", admin: false, formalMember: true, selfService: false },
  sponsorenmanager: { label: "Sponsorenmanager", color: "#B17912", admin: false, formalMember: true, selfService: false },
  trainer: { label: "Trainer/in", color: "#2D6F8E", admin: false, formalMember: true, selfService: false },
  kapitaen: { label: "Kapitän/in", color: "#D66B1F", admin: false, formalMember: true, selfService: false },
  teammanager: { label: "Teammanager/in", color: "#6F5B9A", admin: false, formalMember: true, selfService: false },
  spieler: { label: "Spieler/in", color: C.green, admin: false, formalMember: true, selfService: true },
  eltern: { label: "Eltern", color: C.amber, admin: false, formalMember: true, selfService: true },
  mitglied: { label: "Mitglied", color: "#8B8A85", admin: false, formalMember: true, selfService: true, alwaysOn: true },
};
const isAdmin = (m) => !!m && m.roles.some((r) => ROLE_META[r]?.admin);
const canManageFees = (m) => !!m && m.roles.some((r) => ["geschaeftsfuehrung", "finanzmanager"].includes(r));
const isFormalMember = (m) => !!m && m.roles.some((r) => ROLE_META[r]?.formalMember);
const isSysAdmin = (m) => !!m && m.roles.includes("sysadmin");
const canWriteNews = (m) => isAdmin(m) || (!!m && m.roles.includes("redakteur"));
const canManageSponsors = (m) => isAdmin(m) || (!!m && m.roles.includes("sponsorenmanager"));
function RoleBadges({ user }) {
  if (!user?.roles?.length) return null;
  return <div className="ml-auto flex flex-wrap justify-end gap-1" style={{ maxWidth: 150 }} aria-label="Rollen des Profils">
    {user.roles.map((role) => {
      const meta = ROLE_META[role];
      if (!meta) return null;
      return <span key={role} className="px-1.5 py-1 rounded-md leading-none whitespace-nowrap" style={{ fontSize: 8, fontFamily: "Inter", fontWeight: 700, color: meta.color, background: `${meta.color}14`, border: `1px solid ${meta.color}35` }}>{meta.label}</span>;
    })}
  </div>;
}
function linkFamilyRecords(list, firstId, secondId, firstRelation) {
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
    if (m.id === firstId && !links.some((l) => l.memberId === secondId)) links.push({ memberId: secondId, relation: opposite });
    if (m.id === secondId && !links.some((l) => l.memberId === firstId)) links.push({ memberId: firstId, relation: firstRelation });
    return { ...m, familyId, familyRole: m.id === firstId ? firstRelation : m.id === secondId ? opposite : m.familyRole, familyLinks: links };
  });
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
  { id: "m1", clubId: DEMO_CLUB_ID, name: "Marco Schulte", email: "marco@cmo.app", password: "demo", team: "Herren 1", number: 14, since: 2019, roles: ["sysadmin", "vorstand", "spieler", "mitglied"], color: C.red, points: 740, tippPoints: 14, badges: ["streak", "loyalty", "fairplay", "referrer"], birthdate: "1994-05-12" },
  { id: "m2", clubId: DEMO_CLUB_ID, name: "Jasmin Reiter", email: "jasmin@cmo.app", password: "demo", team: "Damen 1", number: 7, since: 2021, roles: ["kapitaen", "spieler", "mitglied"], color: C.amber, points: 410, tippPoints: 9, badges: ["loyalty"], birthdate: "1998-03-02" },
  { id: "m3", clubId: DEMO_CLUB_ID, name: "Sabine Thomas", email: "sabine@cmo.app", password: "demo", team: "Eltern / Angehörige", managedTeam: "U11", number: null, since: 2023, roles: ["eltern", "teammanager", "mitglied"], color: C.green, points: 120, tippPoints: 5, badges: [], birthdate: "1985-09-14", familyId: "fam-thomas", familyRole: "eltern" },
  { id: "v1", clubId: DEMO_CLUB_ID, name: "Peter Vogt", email: "vorstand@cmo.app", password: "demo", team: "Vorstand", number: null, since: 2015, roles: ["vorstand", "mitglied"], color: C.ink, points: 60, tippPoints: 2, badges: ["loyalty"], birthdate: "1975-01-20" },
  { id: "m4", clubId: DEMO_CLUB_ID, name: "Mia Thomas", email: "mia@cmo.app", password: "demo", team: "U11", number: 5, since: 2024, roles: ["spieler", "mitglied"], color: "#7C6FE0", points: 30, tippPoints: 0, badges: [], birthdate: "2015-06-01", familyId: "fam-thomas", familyRole: "kind" },
  { id: "m5", clubId: DEMO_CLUB_ID, name: "Helga Thomas", email: "helga@cmo.app", password: "demo", team: "Eltern / Angehörige", number: null, since: 2023, roles: ["mitglied"], color: "#B98B3E", points: 20, tippPoints: 0, badges: [], birthdate: "1952-02-11", familyId: "fam-thomas", familyRole: "grosseltern" },
  { id: "m6", clubId: DEMO_CLUB_ID, name: "Claudia Berg", email: "geschaeftsfuehrung@cmo.app", password: "demo", team: "Geschäftsstelle", number: null, since: 2020, roles: ["geschaeftsfuehrung", "mitglied"], color: "#3E7CB1", points: 60, tippPoints: 4, badges: [], birthdate: "1980-11-03" },
  { id: "m7", clubId: DEMO_CLUB_ID, name: "Nina Weber", email: "redaktion@cmo.app", password: "demo", team: "Geschäftsstelle", number: null, since: 2022, roles: ["redakteur", "sponsorenmanager", "mitglied"], color: "#B15CC9", points: 40, tippPoints: 0, badges: [], birthdate: "1990-07-08" },
  { id: "m8", clubId: DEMO_CLUB_ID, name: "Daniel Krüger", email: "finanzen@cmo.app", password: "demo", team: "Geschäftsstelle", number: null, since: 2024, roles: ["finanzmanager", "mitglied"], color: "#176B87", points: 20, tippPoints: 0, badges: [], birthdate: "1988-04-19" },
  { id: "m9", clubId: DEMO_CLUB_ID, name: "Tobias Kern", email: "trainer@cmo.app", password: "demo", team: "Herren 1", teams: ["Herren 1", "U15"], number: null, since: 2021, roles: ["trainer", "mitglied"], color: "#2D6F8E", points: 35, tippPoints: 0, badges: [], birthdate: "1983-02-08" },
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
  if (days >= 10) return { n: 2, label: "Mahnung", color: C.amber };
  if (days >= 3) return { n: 1, label: "Freundliche Erinnerung", color: C.green };
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
const EVENTS = [
  { id: 1, type: "training", team: "Herren 1", title: "Training Herren 1", date: "2026-08-04T18:30:00", location: "Hemberghalle, Iserlohn", desc: "Reguläres Mannschaftstraining. Schienbeinschoner nicht vergessen!", carpool: false, youthClassIds: ["herren1"] },
  { id: 2, type: "spiel", team: "Herren 1", title: "Heimspiel vs. Herringen", date: "2026-08-09T19:00:00", location: "Hemberghalle, Iserlohn", desc: "Bundesliga, Spieltag 3. Support von den Rängen ist gewünscht!", carpool: false, home: true, helperSlots: ["Theke", "Zeitnahme", "Grill", "Kasse"] },
  { id: 3, type: "spiel", team: "Herren 1", title: "Auswärtsspiel bei ERC Wimbern", date: "2026-08-16T20:00:00", location: "Wimbern · 85 km", desc: "Gemeinsame Abfahrt ab Hemberghalle. Fahrgemeinschaft bitte eintragen.", carpool: true, home: false },
  { id: 4, type: "event", title: "Sommerfest & Saisonabschluss", date: "2026-08-23T15:00:00", location: "Vereinsheim am Hemberg", desc: "Grillen, Siegerehrung U11–U15, abends DJ. Familien sind herzlich willkommen.", carpool: false, helperSlots: ["Aufbau", "Kuchenbuffet", "Abbau"] },
  { id: 5, type: "training", team: "Herren 1", title: "Torwarttraining Spezial", date: "2026-08-11T19:00:00", location: "Hemberghalle", desc: "Extra-Einheit mit Torwarttrainer Miguel Costa.", carpool: false, youthClassIds: ["herren1", "damen1"] },
  { id: 6, type: "spiel", team: "Herren 1", title: "Heimspiel vs. Cronenberg", date: "2026-08-30T19:00:00", location: "Hemberghalle, Iserlohn", desc: "Bundesliga, Spieltag 5.", carpool: false, home: true, helperSlots: ["Theke", "Zeitnahme", "Grill", "Kasse"] },
  { id: 7, type: "spiel", team: "U11", title: "U11 Heimspiel vs. Hüls", date: "2026-08-15T11:00:00", location: "Hemberghalle, Iserlohn", desc: "Jugendspieltag der U11.", carpool: false, home: true },
  { id: 8, type: "spiel", team: "U15", title: "U15 bei RSC Cronenberg", date: "2026-08-22T13:30:00", location: "Wuppertal", desc: "Auswärtsspiel der U15.", carpool: true, home: false },
  { id: 9, type: "spiel", team: "Herren 2", title: "Herren 2 vs. SC Bison Calenberg", date: "2026-08-23T18:00:00", location: "Hemberghalle, Iserlohn", desc: "Heimspiel der zweiten Mannschaft.", carpool: false, home: true },
  { id: 10, type: "spiel", team: "Damen 1", title: "Damen 1 vs. RSC Gera", date: "2026-08-29T16:00:00", location: "Hemberghalle, Iserlohn", desc: "Heimspiel der Damenmannschaft.", carpool: false, home: true },
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
function getNextTraining(user) {
  const ycId = TEAM_TO_YOUTHCLASS[user.team];
  if (!ycId) return null;
  const now = new Date();
  const upcoming = EVENTS.filter((e) => e.type === "training" && e.youthClassIds?.includes(ycId) && new Date(e.date) > now)
    .sort((a, b) => new Date(a.date) - new Date(b.date));
  if (!upcoming.length) return null;
  return { event: upcoming[0], trainers: TRAINERS.filter((t) => t.youthClassIds.includes(ycId)), youthClass: YOUTH_CLASSES.find((y) => y.id === ycId) };
}
function getNextMatch() {
  const now = new Date();
  const upcoming = EVENTS.filter((e) => e.type === "spiel" && new Date(e.date) > now).sort((a, b) => new Date(a.date) - new Date(b.date));
  return upcoming[0] || null;
}

/* Sponsor-Slots: reservierte, buchbare Werbeflächen zwischen den Layout-Bereichen */
const SPONSOR_SLOT_DEFS = [
  { key: "dashboard_top", label: "Dashboard oben" },
  { key: "dashboard_bottom", label: "Dashboard – nach Vereins-News" },
  { key: "events_header", label: "Termine – Kopfbereich" },
  { key: "profile_bottom", label: "Profil unten" },
];
const INITIAL_SPONSOR_BOOKINGS = {
  dashboard_top: { title: "Sparkasse Iserlohn", text: "Gemeinsam für den Sport in unserer Region.", imageUrl: "", landingUrl: "https://www.sparkasse-iserlohn.de" },
  dashboard_bottom: { title: "Autohaus Meyer", text: "Mobilität für den Verein und die Region.", imageUrl: "", landingUrl: "" },
  events_header: { title: "Stadtwerke Iserlohn", text: "Energie, die unsere Mannschaften bewegt.", imageUrl: "", landingUrl: "https://www.stadtwerke-iserlohn.de" },
};

const BIRTHDAYS_TODAY = ["Lena K. (U15)", "Timo B. (Herren 1)"];
const INITIAL_POLLS = [{ id: "poll-1", title: "Termin für die Weihnachtsfeier", active: true, options: [{ label: "Fr, 11.12.", votes: 23 }, { label: "Sa, 12.12.", votes: 31 }, { label: "Fr, 18.12.", votes: 9 }], voterIds: [] }];
const SPONSORS = ["Sparkasse Iserlohn", "Stadtwerke Iserlohn", "Autohaus Meyer", "Fitness Point Hemberg", "Bäckerei Sauerland"];

const INITIAL_CHANNELS = [
  {
    id: "team", name: "Herren 1", emoji: "🏒", team: "Herren 1", adminOnly: false, visibleRoles: ["spieler", "trainer", "kapitaen"], writeRoles: ["spieler", "trainer", "kapitaen"],
    messages: [
      { who: "Marco S.", init: "MS", color: C.red, text: "Denkt an die Schienbeinschoner morgen, Trainer checkt das 😅", time: "09:14" },
      { who: "Jasmin R.", init: "JR", color: C.amber, text: "Bin heute 10 Min später da, hab Meeting.", time: "09:20" },
    ],
  },
  {
    id: "damen1", name: "Damen 1", emoji: "🏒", team: "Damen 1", adminOnly: false, visibleRoles: ["spieler", "trainer", "kapitaen"], writeRoles: ["spieler", "trainer", "kapitaen"],
    messages: [{ who: "Jasmin R.", init: "JR", color: C.amber, text: "Trainingsstart heute um 19 Uhr — bis später!", time: "08:45" }],
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
      { who: "Sabine T.", init: "ST", color: C.green, text: "Wer kann Samstag zum Turnier nach Hagen mitfahren?", time: "18:02" },
    ],
  },
];

const FEE_HISTORY = [
  { month: "Juli 2026", amount: "45,00 €", date: "02.07.2026" },
  { month: "Juni 2026", amount: "45,00 €", date: "01.06.2026" },
  { month: "Mai 2026", amount: "45,00 €", date: "03.05.2026" },
];

/* ------------------------------------------------------------------ */
/* Spieler der Saison                                                  */
/* ------------------------------------------------------------------ */
const SEASON_VOTE_DEADLINE = "2026-08-31T23:59:59";
const CANDIDATES = [
  { id: "c1", name: "Marco Schulte", team: "Herren 1", number: 14 },
  { id: "c2", name: "Jasmin Reiter", team: "Damen 1", number: 7 },
  { id: "c3", name: "Luca Fischer", team: "Herren 1", number: 9 },
  { id: "c4", name: "Nina König", team: "Damen 1", number: 11 },
  { id: "c5", name: "Elias Brandt", team: "Herren 1", number: 3 },
];
const BASE_VOTE_COUNTS = { c1: 34, c2: 29, c3: 41, c4: 22, c5: 18 };
function seasonResults(seasonVotes) {
  const counts = CANDIDATES.reduce((acc, c) => {
    acc[c.id] = (BASE_VOTE_COUNTS[c.id] || 0) + Object.values(seasonVotes).filter((v) => v === c.id).length;
    return acc;
  }, {});
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  const sorted = [...CANDIDATES].sort((a, b) => counts[b.id] - counts[a.id]);
  return { counts, total, sorted };
}

/* ------------------------------------------------------------------ */
/* Tippspiel                                                            */
/* ------------------------------------------------------------------ */
const TIPP_MATCHES = [
  { id: 1, home: "Club Member Organisation", away: "Herringen", date: "2026-08-09T19:00:00" },
  { id: 2, home: "ERC Wimbern", away: "Club Member Organisation", date: "2026-08-16T20:00:00" },
  { id: 3, home: "Club Member Organisation", away: "Cronenberg", date: "2026-08-30T19:00:00" },
  { id: 4, home: "SG Bielefeld", away: "Club Member Organisation", date: "2026-09-06T19:00:00" },
];

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

function totalTippPoints(userId, predictions, results) {
  return TIPP_MATCHES.reduce((sum, match) => sum + predictionPoints(predictions[userId]?.[match.id], results[match.id]), 0);
}

/* ------------------------------------------------------------------ */
/* Vorstandsprotokolle                                                  */
/* ------------------------------------------------------------------ */
const INITIAL_PROTOCOLS = [
  {
    id: "p1",
    title: "Vorstandssitzung Juli",
    date: "2026-07-14",
    attendees: ["v1", "m6", "m1"],
    rawText: "Kurzprotokoll Vorstandssitzung 14.07.2026, anwesend: Peter, Claudia, Marco. TOP 1 Bandenwerbung: Peter holt bis 15.08. drei Angebote für neue Bandenwerbung ein. TOP 2 Hallenzeiten: Claudia klärt bis 10.08. mit der Stadt die Hallenzeiten für September. TOP 3 Sommerfest: Planung läuft nach Plan, keine offenen Punkte.",
    tasks: [
      { id: "t1", text: "Angebote für neue Bandenwerbung einholen", assignee: "v1", due: "2026-08-15", done: false },
      { id: "t2", text: "Hallenzeiten für September mit der Stadt klären", assignee: "m6", due: "2026-08-10", done: true },
    ],
  },
];

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
  event: { label: "Vereinsevent", color: C.amber },
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
    <div className="flex items-end justify-between mb-3">
      <div>
        {eyebrow && <div className="text-xs font-semibold tracking-widest uppercase mb-0.5" style={{ color: C.red, fontFamily: "Inter" }}>{eyebrow}</div>}
        <div className="text-lg" style={{ fontFamily: "Oswald", fontWeight: 600, color: C.ink }}>{title}</div>
      </div>
      {right}
    </div>
  );
}

function DashboardSection({ children, accent, background, className = "" }) {
  return (
    <section className={`relative overflow-hidden rounded-3xl p-4 mb-5 ${className}`} style={{ background, border: `1px solid ${accent}26`, boxShadow: "0 7px 20px rgba(20,21,26,0.055)" }}>
      <div className="absolute left-0 top-5 bottom-5 w-1 rounded-r-full" style={{ background: accent }} />
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
function FeatureRow({ icon: Icon, title, subtitle, onClick, accent }) {
  return (
    <button onClick={onClick} className="w-full flex items-center justify-between px-4 py-3 rounded-2xl mb-2" style={{ background: C.white, border: `1px solid ${C.line}` }}>
      <span className="flex items-center gap-3">
        <span className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: C.paper }}>
          <Icon size={15} style={{ color: accent || C.red }} />
        </span>
        <span className="text-left">
          <span className="block text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{title}</span>
          <span className="block text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{subtitle}</span>
        </span>
      </span>
      <ChevronRight size={15} style={{ color: C.textDim, flexShrink: 0 }} />
    </button>
  );
}
function StatCard({ icon: Icon, label, value, sub, accent, onClick }) {
  const Tag = onClick ? "button" : "div";
  return (
    <Tag onClick={onClick} className="rounded-2xl p-3.5 text-left w-full" style={{ background: C.white, border: `1px solid ${C.line}` }}>
      <div className="w-8 h-8 rounded-full flex items-center justify-center mb-2.5" style={{ background: C.paper }}>
        <Icon size={15} style={{ color: accent || C.red }} />
      </div>
      <div className="text-lg leading-tight" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{value}</div>
      <div className="text-[11px]" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{label}</div>
      {sub && <div className="text-[10px] mt-0.5" style={{ color: C.textDim, fontFamily: "Inter" }}>{sub}</div>}
    </Tag>
  );
}
function ToggleCard({ title, desc, value, onChange }) {
  return (
    <div>
      <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{title}</div>
      <button onClick={() => onChange((v) => !v)} className="w-full flex items-center justify-between gap-3 px-4 py-3 rounded-2xl" style={{ background: C.white, border: `1px solid ${C.line}` }}>
        <span className="text-xs text-left" style={{ fontFamily: "Inter", color: C.textDim }}>{desc}</span>
        <span className="w-10 h-6 rounded-full relative flex-shrink-0" style={{ background: value ? C.green : C.paperDim }}>
          <span className="absolute top-0.5 w-5 h-5 rounded-full" style={{ background: "#fff", left: value ? 18 : 2, transition: "left .2s" }} />
        </span>
      </button>
    </div>
  );
}
function SponsorSlot({ slotKey, bookings, onImpression, onClick }) {
  const sponsor = bookings[slotKey];
  const [showDetails, setShowDetails] = useState(false);
  useEffect(() => { if (sponsor) onImpression(slotKey); }, [sponsor, slotKey]);
  if (!sponsor) return null;
  const data = typeof sponsor === "string" ? { title: sponsor, text: "", imageUrl: "", landingUrl: "" } : sponsor;
  const open = () => { onClick(slotKey); setShowDetails(true); };
  return (
    <>
    <button onClick={open} className="w-full rounded-2xl px-4 py-3 mb-5 flex items-center gap-3 text-left overflow-hidden" style={{ background: C.paperDim, border: `1px dashed ${C.line}` }}>
      <div className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: C.white, border: `1px solid ${C.line}` }}>
        {data.imageUrl ? <img src={data.imageUrl} alt="" className="w-full h-full object-cover rounded-lg"/> : <Sparkles size={14} style={{ color: C.amber }} />}
      </div>
      <div className="flex-1 min-w-0">
        <div className="text-[9px] uppercase tracking-widest font-semibold" style={{ color: C.textDim, fontFamily: "Inter" }}>Anzeige</div>
        <div className="text-xs truncate" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{data.title}</div>
        {data.text&&<div className="text-[10px] truncate mt-0.5" style={{color:C.textDim}}>{data.text}</div>}
      </div>
      <ChevronRight size={14} style={{ color: C.textDim, flexShrink: 0 }} />
    </button>
    {showDetails&&<div className="absolute inset-0 z-50 flex items-end p-3" style={{background:"rgba(20,21,26,.72)"}} onClick={()=>setShowDetails(false)}>
      <div role="dialog" aria-modal="true" aria-label={`Sponsor ${data.title}`} onClick={(e)=>e.stopPropagation()} className="w-full rounded-3xl overflow-hidden" style={{background:C.white,maxHeight:"88%"}}>
        <div className="p-4 flex items-start justify-between"><div><div className="text-[9px] uppercase tracking-widest font-bold mb-1" style={{color:C.amber}}>Sponsor der ERG</div><h2 className="text-xl m-0" style={{fontFamily:"Oswald",color:C.ink}}>{data.title}</h2></div><button onClick={()=>setShowDetails(false)} aria-label="Overlay schließen" className="w-8 h-8 rounded-full flex items-center justify-center" style={{background:C.paperDim}}><X size={15}/></button></div>
        {data.text&&<p className="px-4 pb-3 text-sm leading-relaxed" style={{color:C.textDim}}>{data.text}</p>}
        {data.landingUrl&&<div className="px-4 pb-4"><a href={data.landingUrl} target="_blank" rel="noopener noreferrer" className="flex items-center justify-between rounded-xl px-3 py-2.5 text-xs font-bold" style={{background:"#FCEBEE",color:C.red}}>Zur Landingpage des Sponsors <ArrowRight size={14}/></a></div>}
        {data.imageUrl?<img src={data.imageUrl} alt={`Anzeige von ${data.title}`} className="w-full block" style={{maxHeight:280,objectFit:"cover"}}/>:<div className="h-36 flex flex-col items-center justify-center" style={{background:C.paperDim,color:C.textDim}}><ImageIcon size={28}/><span className="text-xs mt-2">Kein Anzeigenbild hinterlegt</span></div>}
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

function ClubSelectScreen({ clubs, onSelect, goNewClub }) {
  const [query, setQuery] = useState("");
  const filtered = query.trim()
    ? clubs.filter((c) => c.name.toLowerCase().includes(query.trim().toLowerCase()) || c.shortName.toLowerCase().includes(query.trim().toLowerCase()))
    : clubs;

  return (
    <div className="flex flex-col h-full px-6 pt-10 pb-6 overflow-y-auto" style={{ background: C.paper }}>
      <div className="flex flex-col items-center mb-8">
        <div className="w-14 h-14 rounded-2xl flex items-center justify-center mb-3" style={{ background: C.ink }}>
          <Users size={22} style={{ color: "#fff" }} />
        </div>
        <div className="text-xl text-center" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>Willkommen</div>
        <div className="text-xs text-center mt-1" style={{ color: C.textDim, fontFamily: "Inter" }}>Wähle deinen Verein, um dich anzumelden oder zu registrieren.</div>
      </div>

      <div className="flex items-center gap-2 rounded-xl px-3.5 py-3 mb-4" style={{ background: C.paperDim }}>
        <Users size={16} style={{ color: C.textDim, flexShrink: 0 }} />
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Verein auswählen …"
          className="flex-1 bg-transparent outline-none text-sm" style={{ fontFamily: "Inter", color: C.ink }} autoFocus />
      </div>

      <div className="space-y-2 mb-6">
        {filtered.length === 0 ? (
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Kein Verein gefunden.</div>
        ) : filtered.map((c) => (
          <button key={c.id} onClick={() => onSelect(c.id)} className="w-full flex items-center gap-3 rounded-xl px-3 py-2.5" style={{ background: C.white, border: `1px solid ${C.line}` }}>
            <ClubLogo club={c} size={36} rounded={9} />
            <div className="text-left flex-1">
              <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{c.name}</div>
              <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{c.city} · seit {c.foundedYear}</div>
            </div>
            <ChevronRight size={16} style={{ color: C.textDim, flexShrink: 0 }} />
          </button>
        ))}
      </div>

      {!isSupabaseConfigured && <button onClick={goNewClub} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm mb-6" style={{ background: C.ink, color: "#fff", fontFamily: "Inter", fontWeight: 700 }}>
        <UserPlus size={15} /> Neuen Verein registrieren
      </button>}

      <div className="mt-auto pt-2 text-center text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>
        Bereits registrierter Verein? Einfach oben auswählen.
      </div>
    </div>
  );
}

function NewClubScreen({ onCreate, goBack }) {
  const [form, setForm] = useState({ name: "", shortName: "", city: "" });
  const [error, setError] = useState("");
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));

  const submit = (e) => {
    e.preventDefault();
    if (!form.name.trim() || !form.shortName.trim()) { setError("Bitte Vereinsname und Kurzname angeben."); return; }
    onCreate({
      id: form.name.trim().toLowerCase().replace(/[^a-z0-9äöüß]+/g, "-").replace(/^-+|-+$/g, "") + "-" + Date.now(),
      name: form.name.trim(),
      shortName: form.shortName.trim().toUpperCase(),
      city: form.city.trim() || "—",
      foundedYear: new Date().getFullYear(),
    });
  };

  return (
    <AuthShell footer={<div className="text-center text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}><button onClick={goBack} className="font-bold" style={{ color: C.red }}>Zurück zur Vereinsauswahl</button></div>}>
      <div className="text-xl mb-1" style={{ fontFamily: "Oswald", fontWeight: 600, color: C.ink }}>Neuen Verein registrieren</div>
      <div className="text-xs mb-5" style={{ color: C.textDim, fontFamily: "Inter" }}>Danach legst du das erste Konto an — es wird automatisch Vereins-Administrator.</div>
      <form onSubmit={submit}>
        <Field icon={Users} placeholder="Vereinsname, z. B. TuS Beispieldorf" value={form.name} onChange={set("name")} />
        <Field icon={ShieldCheck} placeholder="Kurzname, z. B. TUSB" value={form.shortName} onChange={set("shortName")} maxLength={6} />
        <Field icon={MapPin} placeholder="Stadt" value={form.city} onChange={set("city")} />
        {error && <div className="flex items-center gap-1.5 text-xs mb-3" style={{ color: C.red, fontFamily: "Inter" }}><AlertCircle size={13} /> {error}</div>}
        <button type="submit" className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700 }}>
          Verein anlegen <ArrowRight size={15} />
        </button>
      </form>
    </AuthShell>
  );
}

function LoginScreen({ onLogin, members, club, goRegister, goChangeClub }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
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
          Neu bei {club.shortName}?{" "}
          <button onClick={goRegister} className="font-bold" style={{ color: C.red }}>Jetzt registrieren</button>
        </div>
      }
    >
      <div className="flex items-center justify-between mb-5">
        <div className="text-xl" style={{ fontFamily: "Oswald", fontWeight: 600, color: C.ink }}>Willkommen zurück</div>
        <button onClick={goChangeClub} className="text-[11px] font-bold px-2.5 py-1 rounded-full" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>Verein wechseln</button>
      </div>
      <form onSubmit={submit}>
        <Field icon={Mail} type="email" placeholder="E-Mail-Adresse" value={email} onChange={(e) => setEmail(e.target.value)} />
        <div className="flex items-center gap-2 rounded-xl px-3.5 py-3 mb-2" style={{ background: C.paperDim }}>
          <Lock size={16} style={{ color: C.textDim, flexShrink: 0 }} />
          <input type={showPw ? "text" : "password"} placeholder="Passwort" value={password} onChange={(e) => setPassword(e.target.value)}
            className="flex-1 bg-transparent outline-none text-sm" style={{ fontFamily: "Inter", color: C.ink }} />
          <button type="button" onClick={() => setShowPw((s) => !s)}>{showPw ? <EyeOff size={15} style={{ color: C.textDim }} /> : <Eye size={15} style={{ color: C.textDim }} />}</button>
        </div>
        {error && <div className="flex items-center gap-1.5 text-xs mb-3" style={{ color: C.red, fontFamily: "Inter" }}><AlertCircle size={13} /> {error}</div>}
        <button type="button" className="text-xs mb-4" style={{ color: C.textDim, fontFamily: "Inter" }}>Passwort vergessen?</button>
        <button type="submit" disabled={busy} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm" style={{ background: C.ink, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: busy ? 0.65 : 1 }}>
          {busy ? "Anmeldung läuft …" : "Anmelden"} {!busy && <ArrowRight size={15} />}
        </button>
      </form>

      <div className="mt-8">
        <div className="text-xs uppercase tracking-widest font-semibold mb-2.5" style={{ color: C.textDim, fontFamily: "Inter" }}>Demo-Zugänge zum Ausprobieren</div>
        <div className="space-y-2">
          {members.filter((m) => !m.accountPending).map((m) => (
            <button key={m.id} onClick={() => quick(m)} className="w-full flex items-center gap-3 rounded-xl px-3 py-2.5" style={{ background: C.white, border: `1px solid ${C.line}` }}>
              <div className="w-8 h-8 rounded-full flex items-center justify-center text-[11px] font-bold flex-shrink-0" style={{ background: m.color, color: "#fff", fontFamily: "Inter" }}>{initialsOf(m.name)}</div>
              <div className="text-left flex-1">
                <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{m.name}</div>
                <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.roles.map((r) => ROLE_META[r].label).join(" · ")}</div>
              </div>
              {isAdmin(m) && <ShieldCheck size={14} style={{ color: C.red }} />}
            </button>
          ))}
        </div>
      </div>
    </AuthShell>
  );
}

const SELF_SERVICE_ROLES = Object.keys(ROLE_META).filter((r) => ROLE_META[r].selfService && !ROLE_META[r].alwaysOn);

function RegisterScreen({ onRegister, members, club, goLogin }) {
  const [form, setForm] = useState({ name: "", email: "", team: TEAMS[0], birthdate: "", password: "", password2: "", accountType: "mitglied", relativeId: "", childName: "", childBirthdate: "", childTeam: "U11" });
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));
  const [relativeSearch, setRelativeSearch] = useState("");
  const possibleRelatives = members.filter((m) => !m.accountPending && m.id && (
    form.accountType === "eltern" ? m.roles.includes("spieler") : form.accountType === "spieler" ? m.roles.includes("eltern") : false
  )).filter((m) => m.name.toLowerCase().includes(relativeSearch.toLowerCase()));
  const isFirstAccount = members.length === 0;

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim() || !form.email.trim() || !form.password || !form.birthdate) { setError("Bitte fülle alle Pflichtfelder aus."); return; }
    if (form.password !== form.password2) { setError("Die Passwörter stimmen nicht überein."); return; }
    if (members.some((m) => m.email.toLowerCase() === form.email.trim().toLowerCase())) { setError("Für diese E-Mail existiert bei diesem Verein bereits ein Konto."); return; }
    setError("");
    const typeRoles = form.accountType === "spieler" ? ["mitglied", "spieler"] : form.accountType === "eltern" ? ["mitglied", "eltern"] : ["mitglied"];
    setBusy(true);
    const result = await onRegister({
      id: "m" + Date.now(),
      clubId: club.id,
      name: form.name.trim(),
      email: form.email.trim(),
      password: form.password,
      team: form.team,
      number: null,
      since: new Date().getFullYear(),
      roles: isFirstAccount ? ["vereinsadmin", ...typeRoles] : typeRoles,
      color: [C.red, C.amber, C.green, C.ink, "#7C6FE0", "#B98B3E"][Math.floor(Math.random() * 6)],
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
        {isFirstAccount ? `Du bist das erste Konto bei ${club.name} — automatisch Vereins-Administrator.` : `Für aktive Mitglieder von ${club.name}`}
      </div>

      <form onSubmit={submit}>
        <Field icon={User} placeholder="Vor- und Nachname" value={form.name} onChange={set("name")} />
        <Field icon={Mail} type="email" placeholder="E-Mail-Adresse" value={form.email} onChange={set("email")} />
        <Field icon={Cake} type="date" value={form.birthdate} onChange={set("birthdate")} />

        <div className="text-xs font-semibold mb-2" style={{ color: C.ink, fontFamily: "Inter" }}>Ich registriere mich als</div>
        <div className="grid grid-cols-3 gap-2 mb-4">
          {[{ id: "mitglied", label: "Mitglied", icon: User }, { id: "spieler", label: "Spieler/in", icon: Trophy }, { id: "eltern", label: "Elternteil", icon: Users }].map((type) => {
            const Icon = type.icon; const active = form.accountType === type.id;
            return <button type="button" key={type.id} onClick={() => setForm((f) => ({ ...f, accountType: type.id, relativeId: "" }))} className="rounded-xl py-3 px-1 flex flex-col items-center gap-1.5"
              style={{ background: active ? "#FCEBEE" : C.paperDim, border: active ? `1px solid ${C.red}` : "1px solid transparent", color: active ? C.red : C.textDim }}><Icon size={17}/><span className="text-[11px] font-bold">{type.label}</span></button>;
          })}
        </div>

        <div className="flex items-center gap-2 rounded-xl px-3.5 py-3 mb-3" style={{ background: C.paperDim }}>
          <Users size={16} style={{ color: C.textDim, flexShrink: 0 }} />
          <select value={form.team} onChange={set("team")} className="flex-1 bg-transparent outline-none text-sm" style={{ fontFamily: "Inter", color: C.ink }}>
            {TEAMS.map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
        </div>

        {form.accountType !== "mitglied" && <div className="rounded-2xl p-3 mb-4" style={{ background: C.white, border: `1px solid ${C.line}` }}>
          <div className="text-xs font-bold mb-1" style={{ color: C.ink }}>{form.accountType === "eltern" ? "Kind / Spieler verknüpfen" : "Elternteil verknüpfen"}</div>
          <div className="text-[11px] mb-2" style={{ color: C.textDim }}>Ist das Profil bereits vorhanden, suche es hier. Die Verbindung wird automatisch auf beiden Profilen angezeigt.</div>
          <div className="flex items-center gap-2 rounded-xl px-3 py-2 mb-2" style={{ background: C.paperDim }}><Users size={14}/><input value={relativeSearch} onChange={(e)=>setRelativeSearch(e.target.value)} placeholder={form.accountType === "eltern" ? "Spieler suchen …" : "Elternteil suchen …"} className="flex-1 bg-transparent outline-none text-xs"/></div>
          {relativeSearch && <div className="space-y-1 mb-2">{possibleRelatives.slice(0,4).map((m)=><button type="button" key={m.id} onClick={()=>setForm((f)=>({...f,relativeId:m.id}))} className="w-full flex items-center justify-between p-2 rounded-lg text-xs" style={{ background: form.relativeId===m.id ? "#FCEBEE" : C.paperDim, color:C.ink }}><span>{m.name} · {m.team}</span>{form.relativeId===m.id&&<Check size={13}/>}</button>)}</div>}
          {form.accountType === "eltern" && !form.relativeId && <div className="pt-2" style={{ borderTop:`1px solid ${C.line}` }}>
            <div className="text-[11px] font-bold mb-2" style={{color:C.ink}}>Kind noch nicht registriert? Optional vorläufig anlegen</div>
            <input value={form.childName} onChange={set("childName")} placeholder="Name des Kindes" className="w-full px-3 py-2 rounded-lg text-xs mb-2 outline-none" style={{background:C.paperDim}}/>
            {form.childName && <div className="grid grid-cols-2 gap-2"><input type="date" value={form.childBirthdate} onChange={set("childBirthdate")} className="px-2 py-2 rounded-lg text-xs" style={{background:C.paperDim}}/><select value={form.childTeam} onChange={set("childTeam")} className="px-2 py-2 rounded-lg text-xs" style={{background:C.paperDim}}>{TEAMS.filter(t=>t!=="Eltern / Angehörige").map(t=><option key={t}>{t}</option>)}</select></div>}
          </div>}
        </div>}

        <Field icon={Lock} type="password" placeholder="Passwort" value={form.password} onChange={set("password")} />
        <Field icon={Lock} type="password" placeholder="Passwort bestätigen" value={form.password2} onChange={set("password2")} />

        {error && <div className="flex items-center gap-1.5 text-xs mb-3" style={{ color: C.red, fontFamily: "Inter" }}><AlertCircle size={13} /> {error}</div>}
        {notice && <div className="flex items-center gap-1.5 text-xs mb-3" style={{ color: C.green, fontFamily: "Inter" }}><CheckCircle2 size={13} /> {notice}</div>}

        <button type="submit" disabled={busy} className="w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: busy ? 0.65 : 1 }}>
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
function Scoreboard({ nextEvent, goTo }) {
  const { d, h, m } = useCountdown(nextEvent.date);
  const digit = (n) => String(n).padStart(2, "0");
  return (
    <div className="rounded-2xl p-4 mb-5 relative overflow-hidden cursor-pointer" style={{ background: `linear-gradient(160deg, ${C.ink} 0%, ${C.asphalt} 100%)` }} onClick={goTo}>
      <div className="absolute inset-0 opacity-[0.06] pointer-events-none" style={{ backgroundImage: `repeating-linear-gradient(115deg, ${C.white} 0px, ${C.white} 2px, transparent 2px, transparent 26px)` }} />
      <div className="relative flex items-center justify-between mb-3">
        <Pill bg={typeMeta[nextEvent.type].color}>NÄCHSTES SPIEL</Pill>
        <span className="text-xs" style={{ color: "#9A9AA2", fontFamily: "Inter" }}>{formatDate(nextEvent.date)} · {formatTime(nextEvent.date)}</span>
      </div>
      <div className="relative text-white text-base mb-3" style={{ fontFamily: "Oswald", fontWeight: 600 }}>{nextEvent.title}</div>
      <div className="relative flex items-center gap-1.5" style={{ fontFamily: "JetBrains Mono" }}>
        {[["TAGE", d], ["STD", h], ["MIN", m]].map(([label, val], i) => (
          <React.Fragment key={label}>
            <div className="flex flex-col items-center">
              <div className="rounded-md px-2.5 py-1.5 text-2xl font-bold" style={{ background: "#000", color: C.red, minWidth: 46, textAlign: "center", boxShadow: `inset 0 0 0 1px ${C.redDark}` }}>{digit(val)}</div>
              <div className="text-[9px] mt-1 tracking-widest" style={{ color: "#8B8B93" }}>{label}</div>
            </div>
            {i < 2 && <span className="text-xl pb-4" style={{ color: C.red }}>:</span>}
          </React.Fragment>
        ))}
      </div>
      <div className="relative flex items-center gap-1 mt-3 text-xs" style={{ color: "#9A9AA2", fontFamily: "Inter" }}><MapPin size={12} /> {nextEvent.location}</div>
    </div>
  );
}
function PollWidget({ poll, userId, setPolls }) {
  const options = poll.options;
  const voted = poll.voterIds?.includes(userId);
  const total = options.reduce((a, o) => a + o.votes, 0);
  const vote = (i) => { if (voted) return; setPolls((ps)=>ps.map((p)=>p.id===poll.id?{...p,options:p.options.map((x,idx)=>idx===i?{...x,votes:x.votes+1}:x),voterIds:[...(p.voterIds||[]),userId]}:p)); };
  return (
    <div className="rounded-2xl p-4" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
function NextTrainingCard({ user }) {
  const isPlayer = user.roles.includes("spieler");
  const info = isPlayer ? getNextTraining(user) : null;
  const { d, h, m } = useCountdown(info ? info.event.date : "2099-01-01T00:00:00");
  if (!isPlayer || !info) return null;
  const digit = (n) => String(n).padStart(2, "0");
  return (
    <div className="rounded-2xl p-4 mb-5" style={{ background: `linear-gradient(160deg, ${C.green}, #237A44)` }}>
      <div className="text-xs uppercase tracking-widest font-semibold mb-2" style={{ color: "#D9F2E1", fontFamily: "Inter" }}>Nächstes Training · {info.youthClass?.name}</div>
      <div className="text-white text-base mb-2" style={{ fontFamily: "Oswald", fontWeight: 600 }}>{formatDate(info.event.date)} · {formatTime(info.event.date)}</div>
      <div className="flex items-center gap-1 text-xs mb-3" style={{ color: "#D9F2E1", fontFamily: "Inter" }}><MapPin size={12} /> {info.event.location}</div>
      <div className="flex items-center gap-1.5" style={{ fontFamily: "JetBrains Mono" }}>
        {[["TAGE", d], ["STD", h], ["MIN", m]].map(([label, val], i) => (
          <React.Fragment key={label}>
            <div className="flex flex-col items-center">
              <div className="rounded-md px-2.5 py-1.5 text-xl font-bold" style={{ background: "#0C3D22", color: "#fff", minWidth: 42, textAlign: "center" }}>{digit(val)}</div>
              <div className="text-[8px] mt-1 tracking-widest" style={{ color: "#B9E6CB" }}>{label}</div>
            </div>
            {i < 2 && <span className="text-lg pb-4" style={{ color: "#B9E6CB" }}>:</span>}
          </React.Fragment>
        ))}
      </div>
      {info.trainers.length > 0 && (
        <div className="flex items-center gap-3 mt-3 pt-3" style={{ borderTop: "1px solid rgba(255,255,255,0.2)" }}>
          {info.trainers.map((t) => (
            <div key={t.id} className="flex items-center gap-1.5">
              <div className="w-6 h-6 rounded-full flex items-center justify-center text-[9px] font-bold" style={{ background: "#fff", color: C.green }}>{initialsOf(t.name)}</div>
              <span className="text-xs" style={{ color: "#fff", fontFamily: "Inter", fontWeight: 600 }}>{t.name}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
function Dashboard({ user, members, feePaid, channels, dutyPlan, seasonVotes, polls, setPolls, sponsorBookings, onSponsorImpression, onSponsorClick, goEvents, goSeason, goTipp, goDuty, goNews }) {
  const nextEvent = EVENTS.filter((e) => e.type === "spiel" && e.team === user.team && new Date(e.date) > new Date()).sort((a,b)=>new Date(a.date)-new Date(b.date))[0] || getNextMatch();
  const newsMsgs = (channels.find((c) => c.id === "news")?.messages || []).slice(-2).reverse();

  const seasonClosed = new Date() > new Date(SEASON_VOTE_DEADLINE);
  const seasonSubtitle = seasonClosed ? `🏆 ${seasonResults(seasonVotes).sorted[0]?.name}` : "Bis 31.08. abstimmen";

  const leaderboard = [...members].sort((a, b) => b.tippPoints - a.tippPoints);
  const myRank = leaderboard.findIndex((m) => m.id === user.id) + 1;
  const tippSubtitle = `Platz ${myRank} von ${leaderboard.length} · Gewinn: CMO-Artikel`;

  let dutySubtitle = isFormalMember(user) ? "Theke, Grill, Kuchenbuffet …" : "Nur für Vereinsmitglieder";
  if (isFormalMember(user)) {
    let assigned = null;
    Object.entries(dutyPlan).forEach(([eid, stations]) => {
      Object.entries(stations).forEach(([station, list]) => { if (list.includes(user.id)) assigned = { eid, station }; });
    });
    dutySubtitle = assigned ? `${assigned.station} · ${formatDate(EVENTS.find((e) => e.id === Number(assigned.eid))?.date)}` : "Jetzt eintragen";
  }

  return (
    <div className="px-4 pt-4 pb-24">
      <div className="mb-1" style={{ fontFamily: "Inter", color: C.textDim, fontSize: 13 }}>Willkommen zurück,</div>
      <div className="mb-4" style={{ fontFamily: "Oswald", fontWeight: 700, fontSize: 24, color: C.ink }}>{user.name.split(" ")[0]} 👋</div>

      <SponsorSlot slotKey="dashboard_top" bookings={sponsorBookings} onImpression={onSponsorImpression} onClick={onSponsorClick} />

      <Scoreboard nextEvent={nextEvent} goTo={goEvents} />
      <NextTrainingCard user={user} />

      {BIRTHDAYS_TODAY.length > 0 && (
        <div className="flex items-center gap-2 rounded-xl px-3 py-2.5 mb-5" style={{ background: "#FFF6E4", border: `1px solid #F2DDA8` }}>
          <Cake size={16} style={{ color: C.amber }} />
          <div className="text-sm" style={{ fontFamily: "Inter", color: C.ink }}><b>Heute Geburtstag:</b> {BIRTHDAYS_TODAY.join(" · ")} 🎉</div>
        </div>
      )}

      <DashboardSection accent={C.red} background="#FBEDEF">
        <SectionTitle eyebrow="Mitmachen" title="Aktionen & Abstimmungen" />
        <div>
          <FeatureRow icon={Trophy} title="Spieler der Saison" subtitle={seasonSubtitle} onClick={goSeason} accent={C.amber} />
          <FeatureRow icon={Target} title="Tippspiel" subtitle={tippSubtitle} onClick={goTipp} accent={C.red} />
          <FeatureRow icon={ClipboardList} title="Helferplanung" subtitle={dutySubtitle} onClick={goDuty} accent={C.green} />
        </div>
      </DashboardSection>

      <DashboardSection accent="#2D6F8E" background="#EEF5F8">
        <SectionTitle eyebrow="Vereins-News" title="Neueste Nachrichten" right={<button onClick={goNews} className="text-xs font-bold" style={{ color: "#2D6F8E", fontFamily: "Inter" }}>Alle ansehen</button>} />
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

      <SponsorSlot slotKey="dashboard_bottom" bookings={sponsorBookings} onImpression={onSponsorImpression} onClick={onSponsorClick} />

      <DashboardSection accent={C.amber} background="#FFF7E7">
        <SectionTitle eyebrow="Mitmachen" title="Deine Stimme zählt" />
        <div className="space-y-3">{polls.filter((p)=>p.active).map((poll)=><PollWidget key={poll.id} poll={poll} userId={user.id} setPolls={setPolls}/>)}</div>
      </DashboardSection>

      <DashboardSection accent={C.green} background="#EDF7F0">
        <SectionTitle eyebrow="Partner" title="Unsere Sponsoren" />
        <div className="flex gap-2 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
          {SPONSORS.map((s) => <div key={s} className="flex-shrink-0 px-3 py-2.5 rounded-xl text-xs whitespace-nowrap" style={{ background: C.white, border: "1px solid #D8EBDD", color: C.textDim, fontFamily: "Inter", fontWeight: 600 }}>{s}</div>)}
        </div>
      </DashboardSection>

    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Helferplanung (wiederverwendbar: Event-Karte, Helferplanung-Tab, Admin) */
/* ------------------------------------------------------------------ */
function toggleHelperSelf(setDutyPlan, eventId, station, userId) {
  setDutyPlan((dp) => {
    const plan = dp[eventId] || {};
    const list = plan[station] || [];
    const already = list.includes(userId);
    let nextList;
    if (already) nextList = list.filter((id) => id !== userId);
    else { if (list.length >= STATION_CAP) return dp; nextList = [...list, userId]; }
    return { ...dp, [eventId]: { ...plan, [station]: nextList } };
  });
}
function HelperSlots({ ev, members, currentUser, dutyPlan, setDutyPlan, eligible }) {
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
              <button onClick={() => toggleHelperSelf(setDutyPlan, ev.id, station, currentUser.id)} disabled={!imIn && full}
                className="px-2.5 py-1 rounded-full text-[11px] flex-shrink-0"
                style={{ fontFamily: "Inter", fontWeight: 700, background: imIn ? C.green : full ? C.paperDim : C.ink, color: imIn ? "#fff" : full ? C.textDim : "#fff" }}>
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
function EventCard({ ev, carpoolOn, onCarpool, currentUser, members, isAdminUser, dutyPlan, setDutyPlan, canCancelTraining, onCancelTraining }) {
  const [open, setOpen] = useState(false);
  const meta = typeMeta[ev.type];

  const helperEligible = ev.helperSlots ? (isFormalMember(currentUser) && (ev.type !== "spiel" || age(currentUser.birthdate) >= 16)) : false;

  return (
    <div className="rounded-2xl mb-3 overflow-hidden" style={{ background: C.white, border: `1px solid ${C.line}` }}>
      <button className="w-full text-left p-4" onClick={() => setOpen((o) => !o)}>
        <div className="flex items-start justify-between">
          <div className="flex gap-3">
            <div className="flex flex-col items-center justify-center rounded-xl px-2.5 py-1.5" style={{ background: C.paper, minWidth: 50 }}>
              <span className="text-[10px] uppercase font-bold" style={{ color: C.red, fontFamily: "Inter" }}>{formatDate(ev.date).split(" ")[0]}</span>
              <span className="text-lg" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{new Date(ev.date).getDate()}</span>
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
          {ev.cancelled&&<div className="rounded-xl p-3 mb-3 text-xs font-bold" style={{background:"#FCEBEE",color:C.red,border:"1px solid #F3B9B9"}}>Dieses Training wurde für {ev.team} abgesagt.</div>}
          <p className="text-sm mb-3" style={{ color: C.textDim, fontFamily: "Inter" }}>{ev.desc}</p>
          {canCancelTraining&&!ev.cancelled&&<button onClick={()=>onCancelTraining(ev.id)} className="w-full py-2.5 rounded-xl text-xs font-bold mb-3" style={{background:"#FCEBEE",color:C.red,border:"1px solid #F3B9B9"}}>Training für {ev.team} absagen</button>}

          {ev.carpool && (
            <button onClick={() => onCarpool(ev.id)} className="w-full flex items-center justify-center gap-2 py-2 rounded-lg text-xs mb-1"
              style={{ fontFamily: "Inter", fontWeight: 700, background: carpoolOn ? "#E7F3EC" : C.ink, color: carpoolOn ? C.green : C.white, border: carpoolOn ? `1px solid ${C.green}` : "none" }}>
              <Car size={14} /> {carpoolOn ? "Du bietest einen Platz an ✓" : "Fahrgemeinschaft: Platz anbieten"}
            </button>
          )}

          {ev.helperSlots && (
            <div className="mt-3">
              <div className="text-xs font-semibold mb-2" style={{ fontFamily: "Inter", color: C.ink }}>Helfer:innen gesucht</div>
              <HelperSlots ev={ev} members={members} currentUser={currentUser} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} eligible={helperEligible} />
            </div>
          )}
        </div>
      )}
    </div>
  );
}
function EventsView({ currentUser, members, events, setEvents, carpools, setCarpools, dutyPlan, setDutyPlan, sponsorBookings, onSponsorImpression, onSponsorClick, focusRequest, onFocusApplied }) {
  const [filter, setFilter] = useState("alle");
  const [showCreate, setShowCreate] = useState(false);
  const [eventDraft, setEventDraft] = useState({ type: "training", team: "", title: "", date: "", location: "", desc: "" });
  const preferenceKey = `cmo-match-team-${currentUser.id}`;
  const [teamFilter, setTeamFilter] = useState(() => {
    if (typeof window === "undefined") return "alle";
    try { return window.localStorage.getItem(preferenceKey) || "alle"; } catch { return "alle"; }
  });
  const [savedTeam, setSavedTeam] = useState(teamFilter);
  useEffect(() => {
    if (!focusRequest) return;
    setFilter("spiel");
    setTeamFilter(focusRequest.team || "alle");
    onFocusApplied?.();
  }, [focusRequest]);
  const filterTeams = YOUTH_CLASSES.map((t) => t.name);
  const teamFilterActive = filter === "spiel" || filter === "training";
  const filtered = events.filter((e) => {
    if (filter !== "alle" && e.type !== filter) return false;
    if (!teamFilterActive || teamFilter === "alle") return true;
    if (filter === "spiel") return e.team === teamFilter;
    return e.youthClassIds?.includes(TEAM_TO_YOUTHCLASS[teamFilter]);
  });
  const userId = currentUser.id;
  const myCarpools = carpools[userId] || {};
  const isAdminUser = isAdmin(currentUser);
  const canCreateSportEvent = isSysAdmin(currentUser) || currentUser.roles.includes("trainer") || currentUser.roles.includes("kapitaen");
  const allowedEventTeams = isSysAdmin(currentUser) ? filterTeams : currentUser.roles.includes("trainer") ? (currentUser.teams?.length ? currentUser.teams : [currentUser.team]).filter((team) => filterTeams.includes(team)) : [currentUser.team].filter((team) => filterTeams.includes(team));
  const openCreate = () => {
    setEventDraft((draft) => ({ ...draft, team: allowedEventTeams[0] || "" }));
    setShowCreate(true);
  };
  const createSportEvent = (event) => {
    event.preventDefault();
    if (!eventDraft.team || !allowedEventTeams.includes(eventDraft.team) || !eventDraft.title.trim() || !eventDraft.date || !eventDraft.location.trim()) return;
    const created = { id: Date.now(), type: eventDraft.type, team: eventDraft.team, title: eventDraft.title.trim(), date: eventDraft.date, location: eventDraft.location.trim(), desc: eventDraft.desc.trim(), carpool: false, home: true, ...(eventDraft.type === "training" ? { youthClassIds: [TEAM_TO_YOUTHCLASS[eventDraft.team]] } : {}) };
    setEvents((all) => [...all, created].sort((a, b) => new Date(a.date) - new Date(b.date)));
    setFilter(eventDraft.type);
    setTeamFilter(eventDraft.team);
    setEventDraft({ type: "training", team: allowedEventTeams[0] || "", title: "", date: "", location: "", desc: "" });
    setShowCreate(false);
  };
  const cancelTraining = (eventId) => setEvents((all) => all.map((item) => item.id === eventId ? { ...item, cancelled: true, cancelledBy: currentUser.id } : item));
  const saveDefaultTeam = () => {
    try { window.localStorage.setItem(preferenceKey, teamFilter); } catch {}
    setSavedTeam(teamFilter);
  };

  const handleCarpool = (id) => setCarpools((c) => ({ ...c, [userId]: { ...(c[userId] || {}), [id]: !myCarpools[id] } }));

  return (
    <div className="px-4 pt-4 pb-24">
      <div className="flex items-start justify-between gap-3"><SectionTitle title="Termine" />{canCreateSportEvent&&<button onClick={openCreate} className="px-3 py-1.5 rounded-full text-xs flex-shrink-0" style={{background:C.red,color:C.white,fontWeight:700}}>＋ Eintragen</button>}</div>
      {showCreate&&<form onSubmit={createSportEvent} className="rounded-2xl p-4 mb-4 space-y-2.5" style={{background:C.white,border:`1px solid ${C.line}`}}><div className="text-sm font-bold">Training oder Spiel eintragen</div><div className="text-[10px]" style={{color:C.textDim}}>{isSysAdmin(currentUser)?"Als Vereins-Sysadmin kannst du jede Mannschaft auswählen.":currentUser.roles.includes("trainer")?"Du kannst nur deine im Profil hinterlegten Mannschaften auswählen.":"Als Kapitän kannst du nur für deine Profilmannschaft eintragen."}</div><div className="grid grid-cols-2 gap-2"><select value={eventDraft.type} onChange={(e)=>setEventDraft({...eventDraft,type:e.target.value})} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}><option value="training">Training</option><option value="spiel">Spiel</option></select><select value={eventDraft.team} onChange={(e)=>setEventDraft({...eventDraft,team:e.target.value})} className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}>{allowedEventTeams.map((team)=><option key={team} value={team}>{team}</option>)}</select></div><input value={eventDraft.title} onChange={(e)=>setEventDraft({...eventDraft,title:e.target.value})} placeholder={eventDraft.type==="training"?"Titel des Trainings":"Titel des Spiels"} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/><input type="datetime-local" value={eventDraft.date} onChange={(e)=>setEventDraft({...eventDraft,date:e.target.value})} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/><input value={eventDraft.location} onChange={(e)=>setEventDraft({...eventDraft,location:e.target.value})} placeholder="Ort" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.paperDim}}/><textarea value={eventDraft.desc} onChange={(e)=>setEventDraft({...eventDraft,desc:e.target.value})} placeholder="Beschreibung (optional)" rows={2} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none resize-none" style={{background:C.paperDim}}/><div className="flex gap-2"><button type="submit" className="flex-1 py-2.5 rounded-xl text-xs font-bold" style={{background:C.ink,color:C.white}}>Speichern</button><button type="button" onClick={()=>setShowCreate(false)} className="px-4 py-2.5 rounded-xl text-xs font-bold" style={{background:C.paperDim,color:C.textDim}}>Abbrechen</button></div></form>}
      <SponsorSlot slotKey="events_header" bookings={sponsorBookings} onImpression={onSponsorImpression} onClick={onSponsorClick} />
      <div className="flex gap-2 mb-4 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {[["alle", "Alle"], ["training", "Training"], ["spiel", "Spiele"], ["event", "Events"]].map(([k, l]) => (
          <button key={k} onClick={() => setFilter(k)} className="px-3 py-1.5 rounded-full text-xs flex-shrink-0"
            style={{ fontFamily: "Inter", fontWeight: 700, background: filter === k ? C.ink : C.paperDim, color: filter === k ? C.white : C.textDim }}>{l}</button>
        ))}
      </div>
      {teamFilterActive && <div className="flex items-center gap-2 mb-4 px-2.5 py-2 rounded-xl" style={{background:C.white,border:`1px solid ${C.line}`}}>
        <Users size={13} style={{color:C.textDim,flexShrink:0}}/>
        <select aria-label="Mannschaft filtern" value={teamFilter} onChange={(e)=>setTeamFilter(e.target.value)} className="flex-1 min-w-0 bg-transparent text-[11px] font-bold outline-none" style={{color:C.ink}}>
          <option value="alle">Alle Mannschaften</option>{filterTeams.map((team)=><option key={team} value={team}>{team}</option>)}
        </select>
        <button aria-label="Als Standardansicht speichern" title="Als Standard speichern" onClick={saveDefaultTeam} disabled={savedTeam===teamFilter} className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" style={{background:savedTeam===teamFilter?"#E7F3EC":C.paperDim,color:savedTeam===teamFilter?C.green:C.textDim}}><Star size={13} fill={savedTeam===teamFilter?C.green:"none"}/></button>
      </div>}
      {filtered.map((ev) => (
        (() => {
          const trainerTeams = currentUser.teams?.length ? currentUser.teams : [currentUser.team];
          const canCancelTraining = ev.type === "training" && ((currentUser.roles.includes("trainer") && trainerTeams.includes(ev.team)) || (currentUser.roles.includes("kapitaen") && currentUser.team === ev.team) || (currentUser.roles.includes("teammanager") && currentUser.managedTeam === ev.team));
          return (
        <EventCard key={ev.id} ev={ev}
          carpoolOn={!!myCarpools[ev.id]} onCarpool={handleCarpool}
          currentUser={currentUser} members={members} isAdminUser={isAdminUser}
          dutyPlan={dutyPlan} setDutyPlan={setDutyPlan}
          canCancelTraining={canCancelTraining} onCancelTraining={cancelTraining}
        />
          );
        })()
      ))}
      {filtered.length===0&&<div className="rounded-2xl p-6 text-center text-xs" style={{background:C.paperDim,color:C.textDim}}>Für diese Mannschaft sind aktuell keine {filter === "training" ? "Trainingstermine" : "Spiele"} hinterlegt.</div>}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Beiträge                                                             */
/* ------------------------------------------------------------------ */
function FeesView({ members, records, setRecords }) {
  const [selectedMemberId, setSelectedMemberId] = useState(null);
  const [form, setForm] = useState({ year: "2026", type: "Mitgliedsbeitrag", amount: "", paid: "offen", invoiceNumber: "", linkedMemberIds: [], manualNames: "", personCount: "1" });
  const selectedMember = members.find((member) => member.id === selectedMemberId);
  const memberRecords = records.filter((record) => record.memberId === selectedMemberId);
  const addRecord = (event) => {
    event.preventDefault();
    if (!selectedMemberId || !form.year || !form.type.trim() || !form.amount.trim()) return;
    const manualNames = form.type === "Familienbeitrag" ? form.manualNames.split(",").map((name) => name.trim()).filter(Boolean) : [];
    setRecords((all) => [{ id: `fee-${Date.now()}`, memberId: selectedMemberId, year: form.year, type: form.type, amount: form.amount.trim(), paid: form.paid === "bezahlt", invoiceNumber: form.invoiceNumber.trim(), linkedMemberIds: form.type === "Familienbeitrag" ? form.linkedMemberIds : [], manualNames, personCount: form.type === "Familienbeitrag" ? Math.max(1, Number(form.personCount) || 1) : 1 }, ...all]);
    setForm((current) => ({ ...current, amount: "", invoiceNumber: "", linkedMemberIds: [], manualNames: "", personCount: current.type === "Familienbeitrag" ? "2" : "1" }));
  };
  const toggleFamilyMember = (memberId) => setForm((current) => ({ ...current, linkedMemberIds: current.linkedMemberIds.includes(memberId) ? current.linkedMemberIds.filter((id) => id !== memberId) : [...current.linkedMemberIds, memberId] }));

  if (!selectedMember) {
    return (
      <div className="px-4 pt-4 pb-24">
        <SectionTitle eyebrow="Geschäftsführung & Finanzmanagement" title="Beiträge" />
        <div className="rounded-2xl p-4 mb-4" style={{ background: C.ink }}>
          <div className="text-white text-sm" style={{ fontFamily: "Inter", fontWeight: 700 }}>{members.length} Vereinsmitglieder</div>
          <div className="text-xs mt-1" style={{ color: "#B7B6BC" }}>Mitglied auswählen, um Beiträge und Rechnungen zu verwalten.</div>
        </div>
        <div className="space-y-2">
          {members.map((member) => {
            const entries = records.filter((record) => record.memberId === member.id);
            const open = entries.filter((record) => !record.paid).length;
            return (
              <button key={member.id} onClick={() => setSelectedMemberId(member.id)} className="w-full flex items-center gap-3 p-3 rounded-2xl text-left" style={{ background: C.white, border: `1px solid ${C.line}` }}>
                <div className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0" style={{ background: member.color, color: C.white }}>{initialsOf(member.name)}</div>
                <div className="flex-1 min-w-0">
                  <div className="text-sm truncate" style={{ fontWeight: 700, color: C.ink }}>{member.name}</div>
                  <div className="text-[11px]" style={{ color: C.textDim }}>{member.team} · {entries.length} Datensätze</div>
                </div>
                <Pill bg={open ? C.red : C.green}>{open ? `${open} offen` : "bezahlt"}</Pill>
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
          <div key={record.id} className="rounded-2xl p-3.5" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
            <button onClick={() => setRecords((all) => all.map((item) => item.id === record.id ? { ...item, paid: !item.paid } : item))} className="mt-2 px-2.5 py-1 rounded-full text-[11px]" style={{ background: record.paid ? "#E7F3EC" : "#FCEBEE", color: record.paid ? C.green : C.red, fontWeight: 700 }}>{record.paid ? "Bezahlt ✓" : "Noch nicht bezahlt"}</button>
          </div>
        ))}
        {memberRecords.length === 0 && <div className="rounded-2xl p-4 text-xs text-center" style={{ background: C.paperDim, color: C.textDim }}>Noch keine Beitragsdatensätze vorhanden.</div>}
      </div>
      <SectionTitle eyebrow="Neuer Datensatz" title="Beitrag hinterlegen" />
      <form onSubmit={addRecord} className="rounded-2xl p-4 space-y-3" style={{ background: C.white, border: `1px solid ${C.line}` }}>
        <div className="grid grid-cols-2 gap-2">
          <input value={form.year} onChange={(e) => setForm({ ...form, year: e.target.value })} placeholder="Jahr" inputMode="numeric" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
          <input value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="Beitragshöhe €" inputMode="decimal" className="px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
        </div>
        <div>
          <label className="block text-[10px] mb-1" style={{ color: C.textDim, fontWeight: 700 }}>Beitragsart</label>
          <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value, linkedMemberIds: [], manualNames: "", personCount: e.target.value === "Familienbeitrag" ? "2" : "1" })} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}><option value="Mitgliedsbeitrag">Mitgliedsbeitrag</option><option value="Familienbeitrag">Familienbeitrag</option></select>
        </div>
        {form.type === "Familienbeitrag" && (
          <div className="rounded-xl p-3 space-y-3" style={{ background: "#F3F0E8", border: `1px solid ${C.line}` }}>
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
              <textarea value={form.manualNames} onChange={(e) => setForm({ ...form, manualNames: e.target.value })} placeholder="z. B. Max Mustermann, Lea Mustermann" rows={2} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none resize-none" style={{ background: C.white }} />
              <div className="text-[9px] mt-1" style={{ color: C.textDim }}>Mehrere Namen bitte durch Komma trennen.</div>
            </div>
            <div>
              <label className="block text-[10px] mb-1" style={{ color: C.textDim, fontWeight: 700 }}>Anzahl der Personen insgesamt</label>
              <input value={form.personCount} onChange={(e) => setForm({ ...form, personCount: e.target.value })} min="1" type="number" inputMode="numeric" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.white }} />
            </div>
          </div>
        )}
        <input value={form.invoiceNumber} onChange={(e) => setForm({ ...form, invoiceNumber: e.target.value })} placeholder="Rechnungsnummer (optional)" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }} />
        <select value={form.paid} onChange={(e) => setForm({ ...form, paid: e.target.value })} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{ background: C.paperDim }}><option value="offen">Noch nicht bezahlt</option><option value="bezahlt">Bezahlt</option></select>
        <button type="submit" className="w-full py-2.5 rounded-xl text-xs" style={{ background: C.ink, color: C.white, fontWeight: 700 }}>Datensatz anlegen</button>
      </form>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Chat                                                                  */
/* ------------------------------------------------------------------ */
function ChatView({ user, channels, setChannels, activeId, setActiveId }) {
  const [text, setText] = useState("");
  const visibleChannels = channels.filter((c) => isAdmin(user) || ((!c.team || c.team === user.team) && (!c.visibleRoles || c.visibleRoles.some((r) => user.roles.includes(r)))));
  const active = visibleChannels.find((c) => c.id === activeId) || visibleChannels[0];
  const canPost = isAdmin(user) || (active.id === "news" && user.roles.includes("redakteur")) || (!active.adminOnly && (!active.writeRoles || active.writeRoles.some((r) => user.roles.includes(r))));

  const send = () => {
    if (!text.trim() || !canPost) return;
    setChannels((cs) => cs.map((c) => c.id === active.id
      ? { ...c, messages: [...c.messages, { who: user.name, init: initialsOf(user.name), color: user.color, text, time: "jetzt", me: true }].slice(active.id === "news" ? -10 : -200) }
      : c));
    setText("");
  };

  return (
    <div className="pt-4 pb-24 flex flex-col" style={{ height: "calc(100% - 16px)" }}>
      <div className="px-4"><SectionTitle title="Chat" /></div>
      <div className="flex gap-2 px-4 mb-3 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {visibleChannels.map((c) => (
          <button key={c.id} onClick={() => setActiveId(c.id)} className="px-3 py-1.5 rounded-full text-xs flex-shrink-0"
            style={{ fontFamily: "Inter", fontWeight: 700, background: activeId === c.id ? C.ink : C.paperDim, color: activeId === c.id ? C.white : C.textDim }}>
            {c.emoji} {c.name}
          </button>
        ))}
      </div>
      <div className="flex-1 overflow-y-auto px-4 space-y-3">
        {active.messages.map((m, i) => {
          const mine = m.who === user.name;
          return (
            <div key={i} className={`flex gap-2 ${mine ? "flex-row-reverse" : ""}`}>
              <div className="w-7 h-7 rounded-full flex items-center justify-center text-[10px] font-bold flex-shrink-0" style={{ background: m.color, color: C.white, fontFamily: "Inter" }}>{m.init}</div>
              <div className={`max-w-[75%] ${mine ? "items-end" : "items-start"} flex flex-col`}>
                {!mine && <div className="text-[11px] mb-0.5" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.who}</div>}
                <div className="rounded-2xl text-sm overflow-hidden" style={{ fontFamily: "Inter", background: mine ? C.red : C.white, color: mine ? C.white : C.ink, border: mine ? "none" : `1px solid ${C.line}`, borderBottomRightRadius: mine ? 4 : 16, borderBottomLeftRadius: mine ? 16 : 4 }}>
                  {m.imageUrl && <img src={m.imageUrl} alt="" className="w-full block" style={{ maxHeight: 180, objectFit: "cover" }} />}
                  <div className="px-3 py-2">
                    {m.title && <div className="mb-1" style={{ fontFamily: "Oswald", fontWeight: 700, fontSize: 14 }}>{m.title}</div>}
                    {m.text}
                  </div>
                </div>
                <div className="text-[10px] mt-0.5" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.time}</div>
              </div>
            </div>
          );
        })}
      </div>
      <div className="px-4 pt-3">
        {!canPost ? (
          <div className="text-xs text-center py-2 rounded-lg" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>{active.writeRoles ? "In dieser Gruppe schreiben Trainer, Kapitäne und freigegebene Teammitglieder." : "Nur berechtigte Rollen können hier schreiben."}</div>
        ) : (
          <div className="flex items-center gap-2">
            <input value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === "Enter" && send()} placeholder="Nachricht schreiben…"
              className="flex-1 px-3 py-2.5 rounded-full text-sm outline-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
            <button onClick={send} className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: C.red }}><Send size={16} color="#fff" /></button>
          </div>
        )}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Redaktion (News schreiben)                                           */
/* ------------------------------------------------------------------ */
function RedaktionView({ user, channels, setChannels }) {
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState("");
  const [text, setText] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const news = channels.find((c) => c.id === "news");
  const items = (news?.messages || []).map((m, idx) => ({ ...m, idx })).reverse();

  const deleteNews = (idx) => {
    setChannels((cs) => cs.map((c) => (c.id === "news" ? { ...c, messages: c.messages.filter((_, i) => i !== idx) } : c)));
  };

  const onFile = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => setImageUrl(reader.result);
    reader.readAsDataURL(file);
  };

  const publish = () => {
    if (!title.trim() || !text.trim()) return;
    setChannels((cs) => cs.map((c) => (c.id === "news"
      ? { ...c, messages: [...c.messages, { who: user.name, init: initialsOf(user.name), color: user.color, title: title.trim(), text: text.trim(), imageUrl: imageUrl || undefined, time: "jetzt" }].slice(-10) }
      : c)));
    setTitle(""); setText(""); setImageUrl(""); setShowForm(false);
  };

  return (
    <div className="px-4 pt-4 pb-24">
      <SectionTitle title="Redaktion" eyebrow="Vereins-News" right={
        !showForm && <button onClick={() => setShowForm(true)} className="text-xs font-bold px-3 py-1.5 rounded-full" style={{ background: C.ink, color: "#fff", fontFamily: "Inter" }}>+ Neue News</button>
      } />

      {showForm && (
        <div className="rounded-2xl p-3 mb-5 space-y-2.5" style={{ background: C.white, border: `1px solid ${C.line}` }}>
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Titel"
            className="w-full px-3 py-2 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
          <textarea value={text} onChange={(e) => setText(e.target.value)} placeholder="Text der News…" rows={4}
            className="w-full px-3 py-2.5 rounded-lg text-sm outline-none resize-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
          <label className="flex items-center gap-2 px-3 py-2 rounded-lg text-xs cursor-pointer" style={{ background: C.paperDim, fontFamily: "Inter", color: C.textDim }}>
            <ImageIcon size={14} /> {imageUrl ? "Bild ändern" : "Bild auswählen (optional)"}
            <input type="file" accept="image/*" onChange={onFile} className="hidden" />
          </label>
          {imageUrl && <img src={imageUrl} alt="" className="w-full rounded-lg" style={{ maxHeight: 160, objectFit: "cover" }} />}
          <div className="flex gap-2">
            <button onClick={publish} disabled={!title.trim() || !text.trim()} className="flex-1 py-2.5 rounded-lg text-xs" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700, opacity: (!title.trim() || !text.trim()) ? 0.5 : 1 }}>Veröffentlichen</button>
            <button onClick={() => { setShowForm(false); setTitle(""); setText(""); setImageUrl(""); }} className="px-4 py-2.5 rounded-lg text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter", fontWeight: 700 }}>Abbrechen</button>
          </div>
        </div>
      )}

      <SectionTitle eyebrow="Veröffentlicht" title="Alle News" />
      <div className="space-y-2">
        {items.length === 0 ? (
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Noch keine News veröffentlicht.</div>
        ) : items.map((m) => (
          <div key={m.idx} className="rounded-2xl overflow-hidden" style={{ background: C.white, border: `1px solid ${C.line}` }}>
            {m.imageUrl && <img src={m.imageUrl} alt="" className="w-full block" style={{ maxHeight: 160, objectFit: "cover" }} />}
            <div className="p-3">
              <div className="flex items-center justify-between mb-1">
                <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.who} · {m.time}</div>
                <button onClick={() => deleteNews(m.idx)} className="text-[11px] px-2 py-1 rounded-full" style={{ background: "#FDECEC", color: C.red, fontFamily: "Inter", fontWeight: 700 }}>Löschen</button>
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
    <div className="rounded-2xl p-4" style={{ background: C.white, border: `1px solid ${C.line}` }}>
      {rows.map((r, i) => (
        <div key={r.role}>
          <div className="text-[10px] uppercase tracking-widest font-semibold mb-2" style={{ color: C.textDim, fontFamily: "Inter" }}>{r.label}</div>
          <div className="flex flex-wrap gap-2 mb-2">
            {r.list.map((m) => (
              <div key={m.id} className="flex items-center gap-2 px-2.5 py-1.5 rounded-full" style={{ background: m.id === user.id ? "#FCEBEE" : C.paperDim, border: m.id === user.id ? `1px solid ${C.red}` : "none" }}>
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
  const userIsParent = relationMode === "eltern";
  const wantedRole = userIsParent ? "spieler" : "eltern";
  const familyConnections = user.familyId ? members.filter((member) => member.familyId === user.familyId && member.id !== user.id) : [];
  const linkedIds = (user.familyLinks || []).map((l) => l.memberId);
  const results = members.filter((m) => m.id !== user.id && !linkedIds.includes(m.id) && !m.accountPending && m.roles.includes(wantedRole) && m.name.toLowerCase().includes(query.toLowerCase())).slice(0, 5);
  const connect = (targetId) => {
    setMembers((ms) => linkFamilyRecords(ms, user.id, targetId, userIsParent ? "eltern" : "kind"));
    setQuery(""); setOpen(false);
  };
  const createDependent = () => {
    if (!newName.trim() || !userIsParent) return;
    const id = `dependent-${Date.now()}`;
    const child = { id, clubId: user.clubId, name: newName.trim(), email: "", password: "", team: "U11", number: null, since: new Date().getFullYear(), roles: ["mitglied", "spieler"], color: "#7C6FE0", points: 0, tippPoints: 0, badges: [], birthdate: "", accountPending: true };
    setMembers((ms) => linkFamilyRecords([...ms, child], user.id, id, "eltern"));
    setNewName(""); setOpen(false);
  };
  const removeConnection = (target) => {
    if (!window.confirm(`Familienverknüpfung zu ${target.name} wirklich löschen? Die Verbindung wird in beiden Profilen entfernt.`)) return;
    setMembers((all) => unlinkFamilyRecords(all, user.id, target.id));
  };
  return <div className="rounded-2xl p-4 mb-5" style={{background:C.white,border:`1px solid ${C.line}`}}>
    <div className="flex items-center justify-between"><div><div className="text-sm font-bold" style={{color:C.ink}}>Familienverknüpfung</div><div className="text-[11px]" style={{color:C.textDim}}>{adminMode ? `Sysadmin bearbeitet das Profil von ${user.name}.` : "Du verwaltest dein Familienprofil selbst."} Verknüpfungen gelten automatisch für beide Profile.</div></div><button onClick={()=>setOpen(!open)} className="px-3 py-1.5 rounded-full text-xs font-bold" style={{background:C.paperDim,color:C.ink}}>{open?"Schließen":"＋ Verknüpfen"}</button></div>
    {familyConnections.length>0&&<div className="mt-3 pt-3 space-y-1.5" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[10px] font-bold mb-1" style={{color:C.textDim}}>BESTEHENDE VERKNÜPFUNGEN</div>{familyConnections.map((member)=><div key={member.id} className="flex items-center gap-2 px-3 py-2 rounded-xl" style={{background:C.paperDim}}><div className="w-6 h-6 rounded-full flex items-center justify-center text-[9px] font-bold" style={{background:member.color,color:C.white}}>{initialsOf(member.name)}</div><div className="flex-1 min-w-0"><div className="text-xs font-bold truncate" style={{color:C.ink}}>{member.name}</div><div className="text-[10px]" style={{color:C.textDim}}>{member.familyRole||"Familie"}</div></div><button onClick={()=>removeConnection(member)} className="px-2.5 py-1.5 rounded-lg text-[10px] font-bold" style={{background:"#FCEBEE",color:C.red}}>Löschen</button></div>)}</div>}
    {open&&<div className="mt-3 pt-3" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[11px] font-bold mb-1">Rolle in der Verknüpfung</div><select value={relationMode} onChange={(e)=>{setRelationMode(e.target.value);setQuery("");}} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{background:C.paperDim}}><option value="eltern">Elternteil – Spieler oder Kind hinzufügen</option><option value="kind">Spieler/Kind – Elternteil hinzufügen</option></select><input value={query} onChange={(e)=>setQuery(e.target.value)} placeholder={userIsParent?"Vorhandenen Spieler suchen …":"Vorhandenes Elternteil suchen …"} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{background:C.paperDim}}/>{query&&<div className="space-y-1">{results.map(m=><button key={m.id} onClick={()=>connect(m.id)} className="w-full flex items-center justify-between px-3 py-2 rounded-lg text-xs" style={{background:C.paperDim,color:C.ink}}><span>{m.name} · {m.team}</span><span style={{color:C.red}}>Verbinden</span></button>)}{results.length===0&&<div className="text-[11px] py-2" style={{color:C.textDim}}>Kein passendes Profil gefunden.</div>}</div>}{userIsParent&&<div className="mt-3 pt-3" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[11px] font-bold mb-2">Kind ohne Account vorläufig anlegen</div><div className="flex gap-2"><input value={newName} onChange={(e)=>setNewName(e.target.value)} placeholder="Vor- und Nachname" className="flex-1 px-3 py-2 rounded-lg text-xs outline-none" style={{background:C.paperDim}}/><button onClick={createDependent} disabled={!newName.trim()} className="px-3 rounded-lg text-xs font-bold" style={{background:newName.trim()?C.red:C.line,color:"#fff"}}>Anlegen</button></div><div className="text-[10px] mt-2" style={{color:C.textDim}}>Das Kind kann sein vorläufiges Profil später beim Erstellen des eigenen Kontos übernehmen.</div></div>}</div>}
  </div>;
}

function AdminFamilyPanel({ members, setMembers }) {
  const [selectedId, setSelectedId] = useState("");
  const selected = members.find((member) => member.id === selectedId);
  return <div className="space-y-3"><div className="text-xs" style={{color:C.textDim}}>Nur der Sysadmin kann Familienprofile anderer Mitglieder ergänzen. Vorstand und weitere Verwaltungsrollen haben keinen Zugriff.</div><select value={selectedId} onChange={(e)=>setSelectedId(e.target.value)} className="w-full px-3 py-2.5 rounded-xl text-xs outline-none" style={{background:C.white,border:`1px solid ${C.line}`}}><option value="">Mitglied auswählen …</option>{members.map((member)=><option key={member.id} value={member.id}>{member.name} · {member.team}</option>)}</select>{selected&&<><FamilyTree user={selected} members={members}/><FamilyLinkManager user={selected} members={members} setMembers={setMembers} adminMode /></>}</div>;
}

/* ------------------------------------------------------------------ */
/* Profil                                                                */
/* ------------------------------------------------------------------ */
function PlayerDataCard({ user, setMembers }) {
  const [editing, setEditing] = useState(false);
  const [number, setNumber] = useState(user.number ?? "");

  const save = () => {
    setMembers((ms) => ms.map((m) => (m.id === user.id ? { ...m, number: number === "" ? null : Number(number) } : m)));
    setEditing(false);
  };
  const cancel = () => { setNumber(user.number ?? ""); setEditing(false); };

  return (
    <div className="rounded-2xl p-4 mb-5" style={{ background: C.white, border: `1px solid ${C.line}` }}>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2 text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}><Star size={15} style={{ color: C.green }} /> Spielerdaten</div>
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

function ProfileView({ user, members, setMembers, sponsorBookings, onSponsorImpression, onSponsorClick, onLogout }) {
  const goal = 1000;
  const eligible = isFormalMember(user) && age(user.birthdate) >= 16;
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const [deleting, setDeleting] = useState(false);
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
          <div className="text-xs" style={{ color: "#B7B6BC", fontFamily: "Inter" }}>{user.team}{user.number ? ` · Rückennummer ${user.number}` : ""}</div>
          <div className="text-xs mt-0.5 mb-2" style={{ color: "#B7B6BC", fontFamily: "Inter" }}>Dabei seit {user.since} · {age(user.birthdate)} Jahre</div>
          <div className="flex flex-wrap gap-1.5">
            {user.roles.map((r) => <Pill key={r} bg={ROLE_META[r].color}>{ROLE_META[r].label}</Pill>)}
          </div>
        </div>
      </div>

      {user.roles.includes("spieler") && <PlayerDataCard user={user} setMembers={setMembers} />}

      <div className="rounded-2xl p-4 mb-5" style={{ background: C.white, border: `1px solid ${C.line}` }}>
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2 text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}><Sparkles size={15} style={{ color: C.amber }} /> Vereinspunkte</div>
          <span className="text-xs" style={{ color: C.textDim, fontFamily: "JetBrains Mono" }}>{user.points} / {goal}</span>
        </div>
        <div className="h-2.5 rounded-full overflow-hidden" style={{ background: C.paperDim }}>
          <div className="h-full rounded-full" style={{ width: `${Math.min(100, (user.points / goal) * 100)}%`, background: C.amber, transition: "width .4s" }} />
        </div>
        <div className="text-xs mt-2" style={{ color: C.textDim, fontFamily: "Inter" }}>
          {user.points >= goal ? "Prämie freigeschaltet — sprich den Vorstand an! 🎉" : `Noch ${goal - user.points} Punkte bis zum kostenlosen Vereins-Hoodie 🧥`}
        </div>
      </div>

      <SectionTitle eyebrow="Auszeichnungen" title="Deine Badges" />
      {user.badges.length === 0 ? (
        <div className="rounded-2xl p-4 mb-5 text-xs" style={{ background: C.paperDim, color: C.textDim, fontFamily: "Inter" }}>Noch keine Badges — sag bei Trainings zu, um deine erste Auszeichnung zu sammeln!</div>
      ) : (
        <div className="grid grid-cols-2 gap-3 mb-5">
          {user.badges.map((bid) => {
            const b = BADGE_LIBRARY[bid];
            return (
              <div key={bid} className="rounded-2xl p-3" style={{ background: C.white, border: `1px solid ${C.line}` }}>
                <div className="w-8 h-8 rounded-full flex items-center justify-center mb-2" style={{ background: C.paper }}><b.icon size={15} style={{ color: C.red }} /></div>
                <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{b.label}</div>
                <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{b.descFor ? b.descFor(user) : b.desc}</div>
              </div>
            );
          })}
        </div>
      )}

      <SectionTitle eyebrow="Familie" title="Stammbaum" />
      <div className="mb-2"><FamilyTree user={user} members={members} /></div>
      <div className="text-[11px] mb-5" style={{ color: C.textDim, fontFamily: "Inter" }}>
        {eligible ? "Helferdienst-berechtigt ✓ (16+)" : "Für Heimspiel-Helferdienste noch nicht 16 Jahre alt — beim Sommerfest darfst du trotzdem schon anpacken."}
      </div>
      <FamilyLinkManager user={user} members={members} setMembers={setMembers} />

      <div className="rounded-2xl p-4 mb-5 flex items-center gap-3" style={{ background: "#FFF6E4", border: `1px solid #F2DDA8` }}>
        <Gift size={22} style={{ color: C.amber, flexShrink: 0 }} />
        <div>
          <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Mitglied wirbt Mitglied</div>
          <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Lade Freunde ein — für jede Anmeldung gibt's 100 Vereinspunkte. Code: <b>CMO-{initialsOf(user.name)}</b></div>
        </div>
      </div>

      <button className="w-full flex items-center justify-between px-4 py-3 rounded-2xl mb-2" style={{ background: C.white, border: `1px solid ${C.line}` }}>
        <span className="flex items-center gap-2 text-sm" style={{ fontFamily: "Inter", fontWeight: 600, color: C.ink }}><ImageIcon size={15} /> Fotogalerie · Sommerfest 2025</span>
        <ChevronRight size={15} style={{ color: C.textDim }} />
      </button>
      <button className="w-full flex items-center justify-between px-4 py-3 rounded-2xl mb-5" style={{ background: C.white, border: `1px solid ${C.line}` }}>
        <span className="flex items-center gap-2 text-sm" style={{ fontFamily: "Inter", fontWeight: 600, color: C.ink }}><Star size={15} /> Anwesenheitsquote: 92%</span>
        <ChevronRight size={15} style={{ color: C.textDim }} />
      </button>

      <SponsorSlot slotKey="profile_bottom" bookings={sponsorBookings} onImpression={onSponsorImpression} onClick={onSponsorClick} />

      <div className="grid grid-cols-3 gap-2 mb-4 text-center">
        <a href="/datenschutz" className="py-2 rounded-xl text-[10px] font-bold" style={{ background: C.white, border: `1px solid ${C.line}`, color: C.textDim }}>Datenschutz</a>
        <a href="/impressum" className="py-2 rounded-xl text-[10px] font-bold" style={{ background: C.white, border: `1px solid ${C.line}`, color: C.textDim }}>Impressum</a>
        <a href="/nutzungsbedingungen" className="py-2 rounded-xl text-[10px] font-bold" style={{ background: C.white, border: `1px solid ${C.line}`, color: C.textDim }}>Bedingungen</a>
      </div>

      {!deleteConfirm ? <button onClick={() => setDeleteConfirm(true)} className="w-full py-2.5 rounded-2xl text-xs mb-2" style={{ background: C.white, border: "1px solid #F3B9B9", color: C.red, fontWeight: 700 }}>Konto und persönliche Daten löschen</button> :
        <div className="rounded-2xl p-3 mb-2" style={{ background: "#FDECEC", border: "1px solid #F3B9B9" }}>
          <div className="text-xs mb-3" style={{ color: C.ink }}>Das Konto, Vereinsprofile und persönliche Inhalte werden dauerhaft gelöscht. Ein aktives PayPal-Abo wird beendet. Dieser Schritt kann nicht rückgängig gemacht werden.</div>
          {deleteError && <div className="text-xs mb-2" style={{ color: C.red }}>{deleteError}</div>}
          <div className="flex gap-2"><button disabled={deleting} onClick={deleteAccount} className="flex-1 py-2 rounded-lg text-xs font-bold" style={{ background: C.red, color: C.white }}>{deleting ? "Wird gelöscht …" : "Endgültig löschen"}</button><button onClick={() => { setDeleteConfirm(false); setDeleteError(""); }} className="px-3 py-2 rounded-lg text-xs font-bold" style={{ background: C.white, color: C.textDim }}>Abbrechen</button></div>
        </div>}

      <button onClick={onLogout} className="w-full flex items-center justify-center gap-2 py-3 rounded-2xl text-sm" style={{ background: C.paperDim, color: C.red, fontFamily: "Inter", fontWeight: 700 }}>
        <LogOut size={15} /> Abmelden
      </button>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Spieler der Saison — Wahl                                            */
/* ------------------------------------------------------------------ */
function SeasonVoteView({ currentUser, seasonVotes, setSeasonVotes }) {
  const closed = new Date() > new Date(SEASON_VOTE_DEADLINE);
  const { d, h, m } = useCountdown(SEASON_VOTE_DEADLINE);
  const myVote = seasonVotes[currentUser.id];
  const { counts, total, sorted } = seasonResults(seasonVotes);
  const vote = (id) => !closed && setSeasonVotes((v) => ({ ...v, [currentUser.id]: id }));

  return (
    <div className="px-4 pt-4 pb-10">
      <div className="rounded-2xl p-4 mb-5" style={{ background: `linear-gradient(160deg, ${C.ink}, ${C.asphalt})` }}>
        <div className="flex items-center gap-2 mb-2"><Trophy size={16} style={{ color: C.amber }} /><span className="text-white text-sm" style={{ fontFamily: "Inter", fontWeight: 700 }}>Spieler der Saison 2025/26</span></div>
        {!closed ? (
          <div className="text-xs" style={{ color: "#B7B6BC", fontFamily: "Inter" }}>Abstimmung endet am 31.08.2026 · noch {d}T {h}Std {m}Min</div>
        ) : (
          <div className="text-xs" style={{ color: "#B7B6BC", fontFamily: "Inter" }}>Abstimmung beendet — Ergebnis final</div>
        )}
      </div>

      {!closed && <div className="text-xs mb-3" style={{ color: C.textDim, fontFamily: "Inter" }}>{total} Stimmen bisher abgegeben. Ergebnisse werden erst nach dem Stichtag veröffentlicht.</div>}

      {closed && sorted[0] && (
        <div className="rounded-2xl p-4 mb-5 flex items-center gap-3" style={{ background: "#FFF6E4", border: "1px solid #F2DDA8" }}>
          <Trophy size={22} style={{ color: C.amber }} />
          <div>
            <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>🏆 {sorted[0].name}</div>
            <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>Spieler der Saison — Ehrung beim Sommerfest</div>
          </div>
        </div>
      )}

      <div className="space-y-2">
        {sorted.map((c, i) => {
          const pct = total ? Math.round((counts[c.id] / total) * 100) : 0;
          const mine = myVote === c.id;
          return (
            <button key={c.id} onClick={() => vote(c.id)} disabled={closed} className="w-full text-left relative overflow-hidden rounded-xl" style={{ border: `1px solid ${mine ? C.red : C.line}`, cursor: closed ? "default" : "pointer" }}>
              {closed && <div className="absolute inset-y-0 left-0" style={{ width: `${pct}%`, background: i === 0 ? "#FCEBEE" : C.paperDim }} />}
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
function TippView({ members, currentUser, tippPredictions, setTippPredictions, tippResults }) {
  const mine = tippPredictions[currentUser.id] || {};
  const setPred = (matchId, side, val) => {
    setTippPredictions((tp) => {
      const userPreds = tp[currentUser.id] || {};
      const cur = userPreds[matchId] || { home: "", away: "" };
      return { ...tp, [currentUser.id]: { ...userPreds, [matchId]: { ...cur, [side]: val } } };
    });
  };
  const leaderboard = members.map((member) => ({ ...member, calculatedTippPoints: totalTippPoints(member.id, tippPredictions, tippResults) }))
    .sort((a, b) => b.calculatedTippPoints - a.calculatedTippPoints);

  return (
    <div className="px-4 pt-4 pb-10">
      <div className="rounded-2xl p-4 mb-5 flex items-center gap-3" style={{ background: "#FFF6E4", border: "1px solid #F2DDA8" }}>
        <Gift size={20} style={{ color: C.amber }} />
        <div className="text-xs" style={{ color: C.ink, fontFamily: "Inter" }}><b>Platz 1</b> am Saisonende gewinnt einen CMO-Artikel nach Wahl — Schal, Trikot oder mehr.</div>
      </div>

      <SectionTitle eyebrow="Rangliste" title="Tippspiel-Tabelle" />
      <div className="rounded-2xl overflow-hidden mb-6" style={{ border: `1px solid ${C.line}` }}>
        {leaderboard.map((m, i) => (
          <div key={m.id} className="flex items-center gap-3 px-4 py-2.5" style={{ background: m.id === currentUser.id ? "#FCEBEE" : C.white, borderBottom: i < leaderboard.length - 1 ? `1px solid ${C.line}` : "none" }}>
            <div className="w-6 text-center text-sm" style={{ fontFamily: "JetBrains Mono", fontWeight: 700, color: i === 0 ? C.amber : C.textDim }}>{i === 0 ? "🥇" : i === 1 ? "🥈" : i === 2 ? "🥉" : i + 1}</div>
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
      {TIPP_MATCHES.map((match) => {
        const result = tippResults[match.id];
        const locked = new Date(match.date) < new Date() || !!result;
        const pred = mine[match.id] || { home: "", away: "" };
        const earned = predictionPoints(pred, result);
        return (
          <div key={match.id} className="rounded-2xl p-4 mb-3" style={{ background: C.white, border: `1px solid ${C.line}` }}>
            <div className="flex items-center justify-between mb-3">
              <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>{formatDate(match.date)} · {formatTime(match.date)}</div>
              {result ? <Pill bg={C.green}>Endstand {result.home}:{result.away} · +{earned} P</Pill> : locked ? <Pill bg={C.textDim}>Wartet auf Ergebnis</Pill> : null}
            </div>
            <div className="flex items-center justify-center gap-3">
              <span className="text-sm flex-1 text-right" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{match.home}</span>
              <input type="number" min="0" disabled={locked} value={pred.home} onChange={(e) => setPred(match.id, "home", e.target.value)}
                className="w-12 text-center py-1.5 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", fontWeight: 700 }} />
              <span style={{ color: C.textDim }}>:</span>
              <input type="number" min="0" disabled={locked} value={pred.away} onChange={(e) => setPred(match.id, "away", e.target.value)}
                className="w-12 text-center py-1.5 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", fontWeight: 700 }} />
              <span className="text-sm flex-1" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{match.away}</span>
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
function DutyView({ members, currentUser, dutyPlan, setDutyPlan }) {
  const helperEvents = EVENTS.filter((e) => e.helperSlots && e.helperSlots.length);
  const formalMember = isFormalMember(currentUser);
  const oldEnough = age(currentUser.birthdate) >= 16;
  const familyHelpers = (!formalMember || !oldEnough) ? members.filter((m) => m.familyId && m.familyId === currentUser.familyId && m.id !== currentUser.id && isFormalMember(m) && age(m.birthdate) >= 16) : [];

  return (
    <div className="px-4 pt-4 pb-10">
      <div className="text-xs mb-4" style={{ color: C.textDim, fontFamily: "Inter" }}>Von der Theke beim Heimspiel bis zum Kuchenbuffet auf dem Sommerfest — hier findest du alle offenen Helferstellen. Trag dich direkt ein!</div>

      {!oldEnough && (
        <div className="rounded-2xl p-4 mb-5 text-xs" style={{ background: "#FFF6E4", border: "1px solid #F2DDA8", color: C.ink, fontFamily: "Inter" }}>
          An Theke, Zeitnahme, Grill und Kasse bei Heimspielen helfen erst ab 16 Jahren mit — beim Sommerfest kannst du trotzdem schon zupacken.
          {familyHelpers.length > 0 && <> Für Heimspiele kann deine Familie einspringen: {familyHelpers.map((f) => f.name).join(", ")}.</>}
        </div>
      )}

      {helperEvents.map((ev) => {
        const eligible = formalMember && (ev.type !== "spiel" || oldEnough);
        return (
          <div key={ev.id} className="rounded-2xl mb-4 p-4" style={{ background: C.white, border: `1px solid ${C.line}` }}>
            <div className="flex items-center justify-between mb-3">
              <div>
                <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{ev.title}</div>
                <div className="text-xs" style={{ color: C.textDim, fontFamily: "Inter" }}>{formatDate(ev.date)} · {formatTime(ev.date)}</div>
              </div>
              <Pill bg={ev.home ? C.red : typeMeta[ev.type].color}>{ev.home ? "Heimspiel" : typeMeta[ev.type].label}</Pill>
            </div>
            <HelperSlots ev={ev} members={members} currentUser={currentUser} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} eligible={eligible} />
          </div>
        );
      })}
    </div>
  );
}
function AdminDutyPanel({ members, dutyPlan, setDutyPlan }) {
  const helperEvents = EVENTS.filter((e) => e.helperSlots && e.helperSlots.length);
  const formalMembers = members.filter((m) => isFormalMember(m));
  const add = (eventId, station, memberId) => {
    if (!memberId) return;
    setDutyPlan((dp) => {
      const plan = dp[eventId] || {};
      const list = plan[station] || [];
      if (list.includes(memberId) || list.length >= STATION_CAP) return dp;
      return { ...dp, [eventId]: { ...plan, [station]: [...list, memberId] } };
    });
  };
  const remove = (eventId, station, memberId) => {
    setDutyPlan((dp) => {
      const plan = dp[eventId] || {};
      return { ...dp, [eventId]: { ...plan, [station]: (plan[station] || []).filter((id) => id !== memberId) } };
    });
  };
  return (
    <div>
      <div className="text-xs mb-4" style={{ color: C.textDim, fontFamily: "Inter" }}>{formalMembers.length} Vereinsmitglieder sind hinterlegt und einteilbar (Heimspiel-Stationen zusätzlich ab 16 Jahren).</div>
      {helperEvents.map((ev) => {
        const plan = dutyPlan[ev.id] || {};
        const pool = ev.type === "spiel" ? formalMembers.filter((m) => age(m.birthdate) >= 16) : formalMembers;
        return (
          <div key={ev.id} className="rounded-2xl mb-4 p-4" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
    <div className="rounded-2xl overflow-hidden" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
                  <button onClick={() => onToggleTask(protocol.id, t.id)} className="w-4 h-4 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: t.done ? C.green : "transparent", border: `1.5px solid ${t.done ? C.green : C.line}` }}>
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
function ProtokollePanel({ members, protocols, setProtocols }) {
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
    setProtocols((ps) => ps.map((p) => (p.id !== protocolId ? p : { ...p, tasks: p.tasks.map((t) => (t.id === taskId ? { ...t, done: !t.done } : t)) })));
  };

  const addDraftTask = () => {
    if (!newTaskText.trim()) return;
    setDraftTasks((ts) => [...ts, { id: "d" + Date.now(), text: newTaskText.trim(), assignee: newTaskAssignee, due: newTaskDue, done: false }]);
    setNewTaskText(""); setNewTaskAssignee(""); setNewTaskDue("");
  };
  const updateDraftTask = (id, patch) => setDraftTasks((ts) => ts.map((t) => (t.id === id ? { ...t, ...patch } : t)));
  const removeDraftTask = (id) => setDraftTasks((ts) => ts.filter((t) => t.id !== id));

  const saveProtocol = () => {
    if (!title.trim() || !rawText.trim()) return;
    setProtocols((ps) => [
      { id: "p" + Date.now(), title: title.trim(), date, attendees, rawText, tasks: draftTasks.filter((t) => t.text.trim()) },
      ...ps,
    ]);
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
                <div key={t.id} className="flex items-center gap-2.5 px-3 py-2.5 rounded-xl" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
        <div className="rounded-2xl p-3 space-y-2.5" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
        <div className="rounded-2xl p-3 mb-3" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
              <div key={t.id} className="rounded-xl p-3" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
function AutomationsPanel({ members, feePaid, remindersSent, setRemindersSent, welcomeAutomation, setWelcomeAutomation, billingAutomation, setBillingAutomation }) {
  const openMembers = members.filter((m) => isFormalMember(m) && !feePaid[m.id]);
  const sendReminder = (id) => setRemindersSent((r) => ({ ...r, [id]: true }));

  return (
    <div className="space-y-6">
      <div>
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
                <div key={m.id} className="flex items-center justify-between px-3 py-2.5 rounded-xl" style={{ background: C.white, border: `1px solid ${C.line}` }}>
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
      </div>

      <ToggleCard title="Automatische Beitragsperioden" desc="Am 1. jedes Monats werden neue Beitragsposten für alle aktiven Mitglieder erzeugt. Nächster Lauf: 01.09.2026." value={billingAutomation} onChange={setBillingAutomation} />
      <ToggleCard title="Willkommens-Automatik" desc="Neue Mitglieder erhalten automatisch eine Begrüßung im Kanal „Vereins-News“." value={welcomeAutomation} onChange={setWelcomeAutomation} />
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Übersicht (Vorstands-Dashboard)                                      */
/* ------------------------------------------------------------------ */
function OverviewPanel({ members, feePaid, protocols, dutyPlan, seasonVotes, goPanel, showFees }) {
  const paidCount = members.filter((m) => feePaid[m.id]).length;
  const feeRate = members.length ? Math.round((paidCount / members.length) * 100) : 100;
  const openTasks = protocols.flatMap((p) => p.tasks.filter((t) => !t.done)).length;

  const helperEvents = EVENTS.filter((e) => e.helperSlots && e.helperSlots.length);
  let openSlots = 0, totalSlots = 0;
  helperEvents.forEach((ev) => {
    const plan = dutyPlan[ev.id] || {};
    ev.helperSlots.forEach((s) => { totalSlots += STATION_CAP; openSlots += STATION_CAP - (plan[s]?.length || 0); });
  });
  const { total: seasonTotal } = seasonResults(seasonVotes);
  const nextEvent = EVENTS[0];

  return (
    <div className="grid grid-cols-2 gap-3">
      <StatCard icon={Users} label="Mitglieder" value={members.length} sub="alle formale Mitglieder" accent={C.ink} />
      {showFees && <StatCard icon={Euro} label="Beitragsquote" value={`${feeRate}%`} sub={`${members.length - paidCount} offen`} accent={C.green} />}
      <StatCard icon={ClipboardList} label="Offene Aufgaben" value={openTasks} sub="aus Protokollen" accent={C.red} onClick={() => goPanel("protokolle")} />
      <StatCard icon={AlertCircle} label="Helfer-Lücken" value={openSlots} sub={`von ${totalSlots} Plätzen offen`} accent={C.amber} onClick={() => goPanel("duty")} />
      <StatCard icon={Trophy} label="Saison-Stimmen" value={seasonTotal} sub="Spieler der Saison" accent={C.amber} onClick={() => goPanel("season")} />
      <StatCard icon={CalendarDays} label="Nächstes Event" value={formatDate(nextEvent.date)} sub={nextEvent.title} accent={C.red} />
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Sponsoring                                                            */
/* ------------------------------------------------------------------ */
function SponsoringPanel({ bookings, setBookings, stats }) {
  const update = (key, field, value) => setBookings((all) => ({ ...all, [key]: { ...(typeof all[key] === "object" ? all[key] : { title: all[key] || "" }), [field]: value } }));
  const uploadImage = (key, file) => {
    if (!file) return;
    if (!file.type.startsWith("image/")) return;
    const reader = new FileReader();
    reader.onload = () => update(key, "imageUrl", reader.result);
    reader.readAsDataURL(file);
  };
  return (
    <div className="space-y-3">
      <div className="text-xs mb-1" style={{ color: C.textDim, fontFamily: "Inter" }}>Erstelle Anzeigen mit Titel, Text, Bild und optionaler Landingpage. Leere Slots bleiben für Mitglieder unsichtbar.</div>
      {SPONSOR_SLOT_DEFS.map((slot) => {
        const s = stats[slot.key] || { impressions: 0, clicks: 0 };
        const ctr = s.impressions ? ((s.clicks / s.impressions) * 100).toFixed(1) : "0.0";
        const raw = bookings[slot.key];
        const ad = typeof raw === "object" && raw ? raw : { title: raw || "", text: "", imageUrl: "", landingUrl: "" };
        return (
          <div key={slot.key} className="rounded-2xl p-3" style={{ background: C.white, border: `1px solid ${C.line}` }}>
            <div className="flex items-center justify-between mb-2">
              <div className="text-xs" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{slot.label}</div>
              <span className="text-[10px]" style={{ fontFamily: "JetBrains Mono", color: C.textDim }}>{slot.key}</span>
            </div>
            <input value={ad.title} onChange={(e)=>update(slot.key,"title",e.target.value)} placeholder="Titel des Sponsors" className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-2" style={{background:C.paperDim,border:`1px solid ${C.line}`}}/>
            <textarea value={ad.text||""} onChange={(e)=>update(slot.key,"text",e.target.value)} placeholder="Beschreibung / Anzeigentext" rows={3} className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-2 resize-none" style={{background:C.paperDim,border:`1px solid ${C.line}`}}/>
            <input type="url" value={ad.landingUrl||""} onChange={(e)=>update(slot.key,"landingUrl",e.target.value)} placeholder="https://landingpage.de" className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-2" style={{background:C.paperDim,border:`1px solid ${C.line}`}}/>
            <label className="flex items-center gap-2 px-3 py-2 rounded-lg text-xs cursor-pointer mb-2" style={{background:C.paperDim,color:C.ink,border:`1px solid ${C.line}`}}><ImageIcon size={14}/><span className="flex-1">{ad.imageUrl?"Bild ersetzen":"Anzeigenbild hochladen"}</span><input type="file" accept="image/*" className="hidden" onChange={(e)=>uploadImage(slot.key,e.target.files?.[0])}/></label>
            {ad.imageUrl&&<div className="relative mb-2"><img src={ad.imageUrl} alt="Vorschau" className="w-full h-24 object-cover rounded-lg"/><button onClick={()=>update(slot.key,"imageUrl","")} className="absolute top-1 right-1 w-7 h-7 rounded-full flex items-center justify-center" style={{background:"rgba(20,21,26,.8)",color:"white"}}><X size={13}/></button></div>}
            <button onClick={()=>setBookings((b)=>({...b,[slot.key]:undefined}))} className="text-[10px] mb-2" style={{color:C.red}}>Slot leeren</button>
            <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{s.impressions} Impressionen · {s.clicks} Klicks · {ctr}% CTR</div>
          </div>
        );
      })}
    </div>
  );
}

function PollManagerPanel({ polls, setPolls }) {
  const [title, setTitle] = useState("");
  const [options, setOptions] = useState(["", ""]);
  const create = () => {
    const clean = options.map((o)=>o.trim()).filter(Boolean);
    if (!title.trim() || clean.length < 2) return;
    setPolls((ps)=>[{ id:`poll-${Date.now()}`, title:title.trim(), active:true, options:clean.map((label)=>({label,votes:0})), voterIds:[] },...ps]);
    setTitle(""); setOptions(["",""]);
  };
  return <div className="space-y-4"><div className="rounded-2xl p-4" style={{background:C.white,border:`1px solid ${C.line}`}}><div className="text-sm font-bold mb-1">Neue Mitmach-Umfrage</div><div className="text-[11px] mb-3" style={{color:C.textDim}}>Mindestens zwei Antwortmöglichkeiten eintragen.</div><input value={title} onChange={(e)=>setTitle(e.target.value)} placeholder="Frage oder Titel" className="w-full px-3 py-2.5 rounded-xl text-xs outline-none mb-2" style={{background:C.paperDim}}/>{options.map((o,i)=><input key={i} value={o} onChange={(e)=>setOptions((all)=>all.map((x,idx)=>idx===i?e.target.value:x))} placeholder={`Antwort ${i+1}`} className="w-full px-3 py-2 rounded-lg text-xs outline-none mb-2" style={{background:C.paperDim}}/>)}<div className="flex gap-2"><button onClick={()=>setOptions((o)=>[...o,""])} className="px-3 py-2 rounded-lg text-xs font-bold" style={{background:C.paperDim,color:C.ink}}>＋ Antwort</button><button onClick={create} className="flex-1 py-2 rounded-lg text-xs font-bold" style={{background:C.red,color:C.white}}>Veröffentlichen</button></div></div><div className="space-y-2">{polls.map((poll)=><div key={poll.id} className="rounded-xl p-3 flex items-center gap-3" style={{background:C.white,border:`1px solid ${C.line}`}}><div className="flex-1"><div className="text-xs font-bold">{poll.title}</div><div className="text-[10px] mt-1" style={{color:C.textDim}}>{poll.options.length} Antworten · {poll.options.reduce((n,o)=>n+o.votes,0)} Stimmen</div></div><button onClick={()=>setPolls((ps)=>ps.map((p)=>p.id===poll.id?{...p,active:!p.active}:p))} className="px-2.5 py-1.5 rounded-full text-[10px] font-bold" style={{background:poll.active?"#E7F3EC":C.paperDim,color:poll.active?C.green:C.textDim}}>{poll.active?"Aktiv":"Inaktiv"}</button></div>)}</div></div>;
}

function MatchResultsPanel({ results, onSave }) {
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
      <div className="rounded-2xl p-4 mb-4" style={{ background: "#EDF7F0", border: "1px solid #CFE8D6" }}>
        <div className="text-sm font-bold mb-1" style={{ color: C.ink }}>Ergebnisse & Punkte</div>
        <div className="text-xs" style={{ color: C.textDim }}>Endstand nach dem Spiel eintragen. Das System wertet danach alle Tipps aus: exakt 3 Punkte, richtige Tendenz 1 Punkt.</div>
      </div>
      <div className="space-y-3">
        {TIPP_MATCHES.map((match) => {
          const values = drafts[match.id] || results[match.id] || { home: "", away: "" };
          return (
            <div key={match.id} className="rounded-2xl p-4" style={{ background: C.white, border: `1px solid ${results[match.id] ? "#A9D8B6" : C.line}` }}>
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs" style={{ color: C.textDim }}>{formatDate(match.date)} · {formatTime(match.date)}</span>
                {results[match.id] && <Pill bg={C.green}>ausgewertet</Pill>}
              </div>
              <div className="flex items-center gap-2 mb-3">
                <span className="text-xs font-bold flex-1 text-right" style={{ color: C.ink }}>{match.home}</span>
                <input aria-label={`Tore ${match.home}`} type="number" min="0" value={values.home} onChange={(event) => update(match.id, "home", event.target.value)} className="w-12 text-center py-2 rounded-lg outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", fontWeight: 700 }} />
                <span style={{ color: C.textDim }}>:</span>
                <input aria-label={`Tore ${match.away}`} type="number" min="0" value={values.away} onChange={(event) => update(match.id, "away", event.target.value)} className="w-12 text-center py-2 rounded-lg outline-none" style={{ background: C.paperDim, fontFamily: "JetBrains Mono", fontWeight: 700 }} />
                <span className="text-xs font-bold flex-1" style={{ color: C.ink }}>{match.away}</span>
              </div>
              <button onClick={() => save(match)} className="w-full py-2 rounded-lg text-xs font-bold" style={{ background: savedId === match.id ? C.green : C.ink, color: C.white }}>
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
  const toggleRole = (memberId, role) => {
    if (ROLE_META[role]?.alwaysOn) return; // "Mitglied" ist Basisrolle für alle
    setMembers((ms) => ms.map((m) => {
      if (m.id !== memberId) return m;
      const has = m.roles.includes(role);
      if (has && m.roles.length === 1) return m; // mindestens eine Rolle behalten
      return { ...m, roles: has ? m.roles.filter((r) => r !== role) : [...m.roles, role], ...(role === "teammanager" && has ? { managedTeam: null } : {}) };
    }));
  };
  const assignManagedTeam = (memberId, team) => setMembers((all) => all.map((member) => {
    if (member.id === memberId) return { ...member, managedTeam: team };
    if (team && member.managedTeam === team && member.roles.includes("teammanager")) return { ...member, managedTeam: null, roles: member.roles.filter((role) => role !== "teammanager") };
    return member;
  }));
  return (
    <div className="space-y-3">
      <div className="text-xs mb-1" style={{ color: C.textDim, fontFamily: "Inter" }}>Tippe eine Rolle an, um sie zu vergeben oder zu entziehen. Vereins-Administrator, Vorstand & Geschäftsführung können nur hier zugewiesen werden.</div>
      {members.map((m) => (
        <div key={m.id} className="rounded-2xl p-3" style={{ background: C.white, border: `1px solid ${C.line}` }}>
          <div className="flex items-center gap-2 mb-2.5">
            <div className="w-7 h-7 rounded-full flex items-center justify-center text-[10px] font-bold flex-shrink-0" style={{ background: m.color, color: "#fff", fontFamily: "Inter" }}>{initialsOf(m.name)}</div>
            <div className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{m.name}</div>
          </div>
          <div className="flex flex-wrap gap-1.5">
            {Object.keys(ROLE_META).map((r) => {
              const active = m.roles.includes(r);
              return (
                <button key={r} onClick={() => toggleRole(m.id, r)} className="px-2.5 py-1 rounded-full text-[11px]"
                  style={{ fontFamily: "Inter", fontWeight: 700, background: active ? ROLE_META[r].color : C.paperDim, color: active ? "#fff" : C.textDim }}>
                  {ROLE_META[r].label}
                </button>
              );
            })}
          </div>
          {m.roles.includes("teammanager")&&<div className="mt-2.5 pt-2.5" style={{borderTop:`1px solid ${C.line}`}}><div className="text-[10px] mb-1 font-bold" style={{color:C.textDim}}>Betreute Mannschaft · maximal ein Teammanager je Mannschaft</div><select value={m.managedTeam||""} onChange={(e)=>assignManagedTeam(m.id,e.target.value)} className="w-full px-3 py-2 rounded-lg text-xs outline-none" style={{background:C.paperDim}}><option value="">Mannschaft auswählen …</option>{YOUTH_CLASSES.map((team)=><option key={team.name} value={team.name}>{team.name}</option>)}</select></div>}
        </div>
      ))}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* System (Sys-Admin)                                                   */
/* ------------------------------------------------------------------ */
function SystemPanel({ members, channels, setChannels, maintenanceMode, setMaintenanceMode, onResetDemo }) {
  const [chName, setChName] = useState("");
  const [chEmoji, setChEmoji] = useState("💬");
  const [chRoles, setChRoles] = useState([]);
  const [confirmReset, setConfirmReset] = useState(false);
  const toggleChRole = (r) => setChRoles((rs) => (rs.includes(r) ? rs.filter((x) => x !== r) : [...rs, r]));

  const createChannel = () => {
    if (!chName.trim()) return;
    const slug = chName.trim().toLowerCase().replace(/[^a-z0-9äöüß]+/g, "-").replace(/^-+|-+$/g, "") || "kanal";
    const id = channels.some((c) => c.id === slug) ? `${slug}-${Date.now()}` : slug;
    setChannels((cs) => [...cs, { id, name: chName.trim(), emoji: chEmoji || "💬", adminOnly: false, visibleRoles: chRoles.length ? chRoles : null, messages: [] }]);
    setChName(""); setChEmoji("💬"); setChRoles([]);
  };

  return (
    <div className="space-y-6">
      <ToggleCard title="Wartungsmodus" desc="Hinweis-Banner für alle Nutzer:innen einblenden." value={maintenanceMode} onChange={setMaintenanceMode} />

      <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Neuen Chat-Kanal anlegen</div>
        <div className="rounded-2xl p-3" style={{ background: C.white, border: `1px solid ${C.line}` }}>
          <div className="flex gap-2 mb-2">
            <input value={chEmoji} onChange={(e) => setChEmoji(e.target.value)} placeholder="🏒" maxLength={2}
              className="w-12 text-center py-2 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "Inter" }} />
            <input value={chName} onChange={(e) => setChName(e.target.value)} placeholder="Kanalname, z. B. U15 Team"
              className="flex-1 px-3 py-2 rounded-lg text-sm outline-none" style={{ background: C.paperDim, fontFamily: "Inter", color: C.ink }} />
          </div>
          <div className="text-[11px] mb-1.5" style={{ color: C.textDim, fontFamily: "Inter" }}>Sichtbar für (leer = alle Rollen):</div>
          <div className="flex flex-wrap gap-1.5 mb-3">
            {Object.keys(ROLE_META).map((r) => {
              const active = chRoles.includes(r);
              return (
                <button key={r} type="button" onClick={() => toggleChRole(r)} className="px-2.5 py-1 rounded-full text-[11px]"
                  style={{ fontFamily: "Inter", fontWeight: 700, background: active ? ROLE_META[r].color : C.paperDim, color: active ? "#fff" : C.textDim }}>
                  {ROLE_META[r].label}
                </button>
              );
            })}
          </div>
          <button onClick={createChannel} className="w-full py-2 rounded-lg text-xs" style={{ background: C.ink, color: "#fff", fontFamily: "Inter", fontWeight: 700 }}>Kanal anlegen</button>
        </div>
      </div>

      <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Konten-Übersicht</div>
        <div className="rounded-2xl overflow-hidden" style={{ border: `1px solid ${C.line}` }}>
          {members.map((m, i) => (
            <div key={m.id} className="px-4 py-2.5" style={{ background: C.white, borderBottom: i < members.length - 1 ? `1px solid ${C.line}` : "none" }}>
              <div className="flex items-center justify-between">
                <span className="text-sm" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>{m.name}</span>
                <span className="text-[10px]" style={{ fontFamily: "JetBrains Mono", color: C.textDim }}>{m.id}</span>
              </div>
              <div className="text-[11px]" style={{ color: C.textDim, fontFamily: "Inter" }}>{m.email} · {m.roles.map((r) => ROLE_META[r].label).join(", ")}</div>
            </div>
          ))}
        </div>
      </div>

      <div>
        <div className="text-sm mb-2" style={{ fontFamily: "Inter", fontWeight: 700, color: C.ink }}>Demo-Daten</div>
        {!confirmReset ? (
          <button onClick={() => setConfirmReset(true)} className="w-full py-3 rounded-2xl text-sm" style={{ background: C.paperDim, color: C.red, fontFamily: "Inter", fontWeight: 700 }}>
            Tipps, Beiträge & Helfer zurücksetzen
          </button>
        ) : (
          <div className="rounded-2xl p-3" style={{ background: "#FDECEC", border: "1px solid #F3B9B9" }}>
            <div className="text-xs mb-2" style={{ color: C.ink, fontFamily: "Inter" }}>Wirklich alle Aktivitätsdaten zurücksetzen? Konten, Rollen und Protokolle bleiben erhalten.</div>
            <div className="flex gap-2">
              <button onClick={() => { onResetDemo(); setConfirmReset(false); }} className="flex-1 py-2 rounded-lg text-xs" style={{ background: C.red, color: "#fff", fontFamily: "Inter", fontWeight: 700 }}>Ja, zurücksetzen</button>
              <button onClick={() => setConfirmReset(false)} className="flex-1 py-2 rounded-lg text-xs" style={{ background: C.white, color: C.textDim, fontFamily: "Inter", fontWeight: 700, border: `1px solid ${C.line}` }}>Abbrechen</button>
            </div>
          </div>
        )}
      </div>
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

  return <div className="rounded-2xl p-4" style={{ background: C.white, border: `1px solid ${C.line}` }}>
    <div className="flex items-center gap-3 mb-3">
      <ClubLogo club={club} size={58} rounded={15} />
      <div><div className="text-sm font-bold" style={{ color: C.ink }}>Profilbild des Vereins</div><div className="text-[11px]" style={{ color: C.textDim }}>JPG, PNG oder WebP · maximal 2 MB</div></div>
    </div>
    <label className="w-full py-2.5 rounded-xl text-xs font-bold flex items-center justify-center gap-2 cursor-pointer" style={{ background: C.ink, color: C.white, opacity: busy ? .6 : 1 }}>
      <ImageIcon size={15} /> {busy ? "Wird gespeichert …" : "Vereinslogo auswählen"}
      <input type="file" accept="image/jpeg,image/png,image/webp" onChange={uploadLogo} disabled={busy} className="hidden" />
    </label>
    {message && <div className="text-[11px] mt-2" role="status" style={{ color: message.includes("gespeichert") ? C.green : C.red }}>{message}</div>}
  </div>;
}

function AdminView({
  members, setMembers, feePaid, setFeePaid, dutyPlan, setDutyPlan, seasonVotes, currentUser,
  channels, setChannels, maintenanceMode, setMaintenanceMode, onResetDemo,
  protocols, setProtocols, remindersSent, setRemindersSent,
  welcomeAutomation, setWelcomeAutomation, billingAutomation, setBillingAutomation,
  sponsorBookings, setSponsorBookings, sponsorStats, polls, setPolls, tippResults, onSaveTippResult,
  currentClub, onClubLogoUpdated,
}) {
  const sponsorOnly = !isAdmin(currentUser) && canManageSponsors(currentUser);
  const canSeeFees = canManageFees(currentUser);
  const [panel, setPanel] = useState(sponsorOnly ? "sponsoring" : "overview");
  const openCount = members.filter((m) => !feePaid[m.id]).length;
  const panels = sponsorOnly ? [["sponsoring", "Sponsoring"], ["polls", "Umfragen"]] : [["overview", "Übersicht"], ["automation", "Automatisierung"], ["duty", "Helferplanung"], ["protokolle", "Protokolle"], ["polls", "Umfragen"], ["sponsoring", "Sponsoring"], ["season", "Spieler der Saison"], ["roles", "Rollen"]];
  if (currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role))) panels.splice(1, 0, ["clubprofile", "Vereinsprofil"]);
  if (currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role))) panels.splice(1, 0, ["results", "Spielergebnisse"]);
  if (isSysAdmin(currentUser)) panels.push(["families", "Familienprofile"], ["system", "System"]);

  return (
    <div className="px-4 pt-4 pb-24">
      <SectionTitle title={sponsorOnly ? "Sponsorenmanager" : "Verwaltung"} eyebrow={sponsorOnly ? "Anzeigen & Kampagnen" : "Vorstand"} />
      {!sponsorOnly && <div className="rounded-2xl p-4 mb-5 flex items-center gap-3" style={{ background: C.ink }}>
        <ShieldCheck size={22} style={{ color: C.amber }} />
        <div>
          <div className="text-white text-sm" style={{ fontFamily: "Inter", fontWeight: 700 }}>{members.length} Mitglieder</div>
          <div className="text-xs" style={{ color: "#B7B6BC", fontFamily: "Inter" }}>{canSeeFees ? `${openCount} Beiträge noch offen` : "Vereinsverwaltung"}</div>
        </div>
      </div>}

      <div className="flex gap-2 mb-4 overflow-x-auto pb-1" style={{ scrollbarWidth: "none" }}>
        {panels.map(([k, l]) => (
          <button key={k} onClick={() => setPanel(k)} className="px-3 py-1.5 rounded-full text-xs flex-shrink-0"
            style={{ fontFamily: "Inter", fontWeight: 700, background: panel === k ? C.ink : C.paperDim, color: panel === k ? C.white : C.textDim }}>{l}</button>
        ))}
      </div>

      {panel === "overview" && <OverviewPanel members={members} feePaid={feePaid} protocols={protocols} dutyPlan={dutyPlan} seasonVotes={seasonVotes} goPanel={setPanel} showFees={canSeeFees} />}
      {panel === "clubprofile" && currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role)) && <ClubLogoPanel club={currentClub} onLogoUpdated={onClubLogoUpdated} />}

      {panel === "automation" && (
        <AutomationsPanel members={members} feePaid={feePaid} remindersSent={remindersSent} setRemindersSent={setRemindersSent}
          welcomeAutomation={welcomeAutomation} setWelcomeAutomation={setWelcomeAutomation}
          billingAutomation={billingAutomation} setBillingAutomation={setBillingAutomation} />
      )}

      {panel === "duty" && <AdminDutyPanel members={members} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} />}
      {panel === "protokolle" && <ProtokollePanel members={members} protocols={protocols} setProtocols={setProtocols} />}
      {panel === "sponsoring" && <SponsoringPanel bookings={sponsorBookings} setBookings={setSponsorBookings} stats={sponsorStats} />}
      {panel === "polls" && <PollManagerPanel polls={polls} setPolls={setPolls} />}
      {panel === "roles" && <RolesPanel members={members} setMembers={setMembers} />}
      {panel === "results" && currentUser.roles.some((role) => ["vereinsadmin", "sysadmin"].includes(role)) && <MatchResultsPanel results={tippResults} onSave={onSaveTippResult} />}
      {panel === "families" && isSysAdmin(currentUser) && <AdminFamilyPanel members={members} setMembers={setMembers} />}
      {panel === "system" && isSysAdmin(currentUser) && (
        <SystemPanel members={members} channels={channels} setChannels={setChannels} maintenanceMode={maintenanceMode} setMaintenanceMode={setMaintenanceMode} onResetDemo={onResetDemo} />
      )}

      {panel === "season" && (() => {
        const { counts, total, sorted } = seasonResults(seasonVotes);
        return (
          <div>
            <div className="text-xs mb-3" style={{ color: C.textDim, fontFamily: "Inter" }}>Nur für den Vorstand sichtbar — {total} Stimmen bisher.</div>
            <div className="space-y-2">
              {sorted.map((c, i) => {
                const pct = total ? Math.round((counts[c.id] / total) * 100) : 0;
                return (
                  <div key={c.id} className="relative overflow-hidden rounded-xl" style={{ border: `1px solid ${C.line}` }}>
                    <div className="absolute inset-y-0 left-0" style={{ width: `${pct}%`, background: i === 0 ? "#FCEBEE" : C.paperDim }} />
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
function baseTabs(isAdminUser, canEditNews, canEditSponsors, canManageFees) {
  const tabs = [
    { id: "home", label: "Home", icon: Home },
    { id: "events", label: "Termine", icon: CalendarDays },
    { id: "chat", label: "Chat", icon: MessageCircle },
    { id: "profile", label: "Profil", icon: User },
  ];
  if (canManageFees) tabs.splice(tabs.findIndex((tab) => tab.id === "chat"), 0, { id: "fees", label: "Beiträge", icon: Wallet });
  if (canEditNews) tabs.splice(tabs.findIndex((tab) => tab.id === "chat"), 0, { id: "redaktion", label: "Redaktion", icon: Newspaper });
  if (isAdminUser || canEditSponsors) tabs.splice(tabs.findIndex((tab) => tab.id === "profile"), 0, { id: "admin", label: canEditSponsors && !isAdminUser ? "Sponsoren" : "Verwaltung", icon: ShieldCheck });
  return tabs;
}
const SUBVIEW_TITLES = { season: "Spieler der Saison", tipp: "Tippspiel", duty: "Helferplanung" };

export default function ClubMemberOrganisationApp() {
  const [clubs, setClubs] = useState(INITIAL_CLUBS);
  const [selectedClubId, setSelectedClubId] = useState(null);
  const [members, setMembers] = useState(INITIAL_MEMBERS);
  const [currentUserId, setCurrentUserId] = useState(null);
  const [authScreen, setAuthScreen] = useState("club"); // club | newclub | login | register
  const [tab, setTab] = useState("home");
  const [tabHistory, setTabHistory] = useState([]);
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

  const [feePaid, setFeePaid] = useState(INITIAL_FEE_PAID);
  const [feeRecords, setFeeRecords] = useState(INITIAL_FEE_RECORDS);
  const [events, setEvents] = useState(EVENTS);
  const [carpools, setCarpools] = useState({});
  const [channels, setChannels] = useState(INITIAL_CHANNELS);
  const [chatChannelId, setChatChannelId] = useState("team");
  const [seasonVotes, setSeasonVotes] = useState({});
  const [tippPredictions, setTippPredictions] = useState({});
  const [tippResults, setTippResults] = useState({});
  const [dutyPlan, setDutyPlan] = useState(INITIAL_DUTY_PLAN);
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [protocols, setProtocols] = useState(INITIAL_PROTOCOLS);
  const [remindersSent, setRemindersSent] = useState({});
  const [welcomeAutomation, setWelcomeAutomation] = useState(true);
  const [billingAutomation, setBillingAutomation] = useState(true);
  const [sponsorBookings, setSponsorBookings] = useState(INITIAL_SPONSOR_BOOKINGS);
  const [sponsorStats, setSponsorStats] = useState({});
  const [polls, setPolls] = useState(INITIAL_POLLS);

  useEffect(() => {
    if (!supabase) return;
    supabase.from("clubs").select("id,name,short_name,city,founded_year,logo_url").order("name").then(({ data }) => {
      if (data?.length) setClubs(data.map((club) => ({
        id: club.id,
        name: club.name,
        shortName: club.short_name,
        city: club.city || "—",
        foundedYear: club.founded_year || new Date().getFullYear(),
        logoUrl: club.logo_url || null,
      })));
    });
  }, []);

  const currentUser = members.find((m) => m.id === currentUserId);
  const currentClub = clubs.find((c) => c.id === selectedClubId) || clubs.find((c) => c.id === currentUser?.clubId);
  const clubMembers = members.filter((m) => m.clubId === selectedClubId);

  const selectClub = (clubId) => { setSelectedClubId(clubId); setAuthScreen("login"); };
  const createClub = (club) => { setClubs((cs) => [...cs, club]); setSelectedClubId(club.id); setAuthScreen("register"); };
  const changeClub = () => { setSelectedClubId(null); setAuthScreen("club"); };
  const updateCurrentClubLogo = (logoUrl) => setClubs((items) => items.map((club) => club.id === currentClub?.id ? { ...club, logoUrl } : club));

  const enterApp = (member) => {
    setMembers((current) => [...current.filter((item) => item.id !== member.id), member]);
    setSelectedClubId(member.clubId);
    setCurrentUserId(member.id);
    setTab("home"); setTabHistory([]); setSubView(null);
  };
  const loadSupabaseMembership = async (profileId, clubId) => {
    const { data, error } = await supabase.from("club_memberships")
      .select("id,club_id,display_name,email,member_since,status,membership_roles(role),team_members(function,teams(name))")
      .eq("profile_id", profileId).eq("club_id", clubId).maybeSingle();
    if (error) return { error: "Das Vereinsprofil konnte nicht geladen werden." };
    if (!data) return { error: "Für dieses Konto besteht noch keine Mitgliedschaft in diesem Verein.", code: "membership_missing" };
    if (data.status === "pending") return { error: "Deine Registrierung wartet noch auf die Freigabe durch den Vereins-Administrator." };
    if (data.status !== "active") return { error: "Dieses Vereinsprofil ist derzeit nicht aktiv." };
    const roles = (data.membership_roles || []).map((entry) => entry.role);
    const assignments = data.team_members || [];
    const teamNames = assignments.map((entry) => entry.teams?.name).filter(Boolean);
    const primaryTeam = teamNames[0] || "Mitglied";
    const member = {
      id: data.id, authProfileId: profileId, clubId: data.club_id,
      name: data.display_name, email: data.email || "", password: "",
      team: primaryTeam, teams: teamNames, number: null,
      since: data.member_since || new Date().getFullYear(), roles,
      color: C.red, points: 0, tippPoints: 0, badges: [], birthdate: "",
    };
    enterApp(member);
    return { ok: true };
  };
  const login = async (email, password) => {
    const demoMember = members.find((m) => m.email.toLowerCase() === email.toLowerCase() && m.password === password && m.clubId === selectedClubId);
    if (demoMember) {
      enterApp(demoMember);
      return { ok: true };
    }
    if (!supabase) {
      return { error: "E-Mail oder Passwort ist falsch." };
    }
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error || !data.user) return { error: "E-Mail oder Passwort ist falsch." };
    const loaded = await loadSupabaseMembership(data.user.id, selectedClubId);
    if (loaded?.code !== "membership_missing") return loaded;
    const metadata = data.user.user_metadata || {};
    if (metadata.pending_club_id !== selectedClubId) return loaded;
    const { error: registrationError } = await supabase.rpc("register_for_club", {
      target_club: selectedClubId,
      member_name: metadata.full_name || email.split("@")[0],
      account_role: metadata.account_role || "mitglied",
      member_birthdate: metadata.birthdate || null,
    });
    if (registrationError) return { error: "Das Vereinsprofil konnte nicht fertiggestellt werden." };
    return loadSupabaseMembership(data.user.id, selectedClubId);
  };
  const register = async (draft, familySetup) => {
    if (supabase) {
      const { data, error } = await supabase.auth.signUp({
        email: draft.email,
        password: draft.password,
        options: { data: {
          full_name: draft.name,
          pending_club_id: draft.clubId,
          account_role: familySetup?.accountType || "mitglied",
          birthdate: draft.birthdate || null,
        } },
      });
      if (error) return { error: error.message === "User already registered" ? "Für diese E-Mail existiert bereits ein Konto." : error.message };
      if (!data.session || !data.user) {
        return { ok: true, message: "Bitte bestätige jetzt die E-Mail. Danach kannst du dich anmelden und die Vereinsregistrierung abschließen." };
      }
      const { data: registration, error: registrationError } = await supabase.rpc("register_for_club", {
        target_club: draft.clubId,
        member_name: draft.name,
        account_role: familySetup?.accountType || "mitglied",
        member_birthdate: draft.birthdate || null,
      });
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
        const child = { id: childId, clubId: draft.clubId, name: familySetup.child.name, email: "", password: "", team: familySetup.child.team || "U11", number: null, since: new Date().getFullYear(), roles: ["mitglied", "spieler"], color: "#7C6FE0", points: 0, tippPoints: 0, badges: [], birthdate: familySetup.child.birthdate || "", accountPending: true, familyLinks: [] };
        next = linkFamilyRecords([...next, child], draft.id, childId, "eltern");
      }
      return next;
    });
    setFeePaid((f) => ({ ...f, [draft.id]: false }));
    if (welcomeAutomation) {
      setChannels((cs) => cs.map((c) => (c.id === "news"
        ? { ...c, messages: [...c.messages, { who: "System", init: "🤖", color: C.green, text: `Herzlich willkommen im Verein, ${draft.name.split(" ")[0]}! 👋`, time: "jetzt" }].slice(-10) }
        : c)));
    }
    setCurrentUserId(draft.id);
    setTab("home");
    return { ok: true };
  };
  const logout = async () => { if (supabase) await supabase.auth.signOut(); setCurrentUserId(null); setSelectedClubId(null); setAuthScreen("club"); setTab("home"); setTabHistory([]); setSubView(null); };
  const returnToClubOverview = () => { setCurrentUserId(null); setSelectedClubId(null); setAuthScreen("club"); setTab("home"); setTabHistory([]); setSubView(null); setEventFocusRequest(null); };
  const goNews = () => { setChatChannelId("news"); navigateTab("chat"); };
  const goToMyNextMatch = () => { setEventFocusRequest({ team: currentUser?.team || "alle", requestedAt: Date.now() }); navigateTab("events"); };
  const onSponsorImpression = (slotKey) => setSponsorStats((s) => ({ ...s, [slotKey]: { impressions: (s[slotKey]?.impressions || 0) + 1, clicks: s[slotKey]?.clicks || 0 } }));
  const onSponsorClick = (slotKey) => setSponsorStats((s) => ({ ...s, [slotKey]: { impressions: s[slotKey]?.impressions || 0, clicks: (s[slotKey]?.clicks || 0) + 1 } }));
  const resetDemoData = () => {
    setCarpools({}); setSeasonVotes({}); setTippPredictions({}); setTippResults({});
    setRemindersSent({});
    setFeePaid(INITIAL_FEE_PAID); setFeeRecords(INITIAL_FEE_RECORDS); setEvents(EVENTS); setDutyPlan(INITIAL_DUTY_PLAN); setChannels(INITIAL_CHANNELS);
  };
  const saveTippResult = (matchId, result) => {
    setTippResults((currentResults) => {
      const nextResults = { ...currentResults, [matchId]: result };
      setMembers((currentMembers) => currentMembers.map((member) => ({
        ...member,
        tippPoints: totalTippPoints(member.id, tippPredictions, nextResults),
      })));
      return nextResults;
    });
  };

  const currentUserIsAdmin = isAdmin(currentUser);
  const currentUserCanEditNews = canWriteNews(currentUser);
  const currentUserCanEditSponsors = canManageSponsors(currentUser);
  const currentUserCanManageFees = canManageFees(currentUser);
  const TABS = baseTabs(currentUserIsAdmin, currentUserCanEditNews, currentUserCanEditSponsors, currentUserCanManageFees);

  return (
    <div className="erg-app w-full min-h-screen flex items-center justify-center p-4" style={{ background: "#DEDAD0", fontFamily: "Inter" }}>
      <style>{FONTS}</style>
      <div className="relative w-full flex flex-col overflow-hidden" style={{ maxWidth: 400, height: 820, background: C.paper, borderRadius: 36, boxShadow: "0 30px 60px rgba(0,0,0,0.25)", border: `8px solid ${C.ink}` }}>
        {!currentUser ? (
          authScreen === "club" ? (
            <ClubSelectScreen clubs={clubs} onSelect={selectClub} goNewClub={() => setAuthScreen("newclub")} />
          ) : authScreen === "newclub" ? (
            <NewClubScreen onCreate={createClub} goBack={() => setAuthScreen("club")} />
          ) : authScreen === "login" ? (
            <LoginScreen onLogin={login} members={clubMembers} club={currentClub} goRegister={() => setAuthScreen("register")} goChangeClub={changeClub} />
          ) : (
            <RegisterScreen onRegister={register} members={clubMembers} club={currentClub} goLogin={() => setAuthScreen("login")} />
          )
        ) : (
          <>
            {subView ? (
              <div className="flex items-start gap-3 px-4 pt-3 pb-2 flex-shrink-0" style={{ background: C.paper }}>
                <button onClick={() => setSubView(null)} className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: C.white, border: `1px solid ${C.line}` }}>
                  <ArrowLeft size={15} style={{ color: C.ink }} />
                </button>
                <div className="text-sm" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink }}>{SUBVIEW_TITLES[subView]}</div>
                <RoleBadges user={currentUser} />
              </div>
            ) : (
              <div className="flex items-start px-4 pt-3 pb-2 flex-shrink-0" style={{ background: C.paper }}>
                <div className="flex items-center gap-2">
                  {tabHistory.length > 0 ? (
                    <button onClick={goBack} className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: C.white, border: `1px solid ${C.line}` }}>
                      <ArrowLeft size={15} style={{ color: C.ink }} />
                    </button>
                  ) : (
                    <ClubLogo club={currentClub} size={32} rounded={8} />
                  )}
                  <div>
                    <div className="text-xs leading-none" style={{ fontFamily: "Oswald", fontWeight: 700, color: C.ink, letterSpacing: 0.5 }}>{currentClub?.shortName}</div>
                    <div className="text-[10px]" style={{ color: C.textDim }}>seit {currentClub?.foundedYear}</div>
                  </div>
                  <button onClick={returnToClubOverview} className="ml-1 px-2 py-1.5 rounded-lg text-[9px] leading-tight font-bold text-left" style={{background:C.paperDim,color:C.textDim,maxWidth:88}}>Zur Vereinsübersicht</button>
                </div>
                <RoleBadges user={currentUser} />
              </div>
            )}

            {maintenanceMode && (
              <div className="px-4 py-2 text-xs text-center flex-shrink-0" style={{ background: "#FDECEC", color: C.red, fontFamily: "Inter", fontWeight: 600, borderBottom: "1px solid #F3B9B9" }}>
                🔧 Wartungsmodus aktiv — einige Inhalte können sich kurzfristig ändern.
              </div>
            )}

            <div key={`${tab}-${subView || ""}`} className="tabFade flex-1 overflow-y-auto" style={{ background: C.paper }}>
              {subView === "season" && <SeasonVoteView currentUser={currentUser} seasonVotes={seasonVotes} setSeasonVotes={setSeasonVotes} />}
              {subView === "tipp" && <TippView members={clubMembers} currentUser={currentUser} tippPredictions={tippPredictions} setTippPredictions={setTippPredictions} tippResults={tippResults} />}
              {subView === "duty" && <DutyView members={clubMembers} currentUser={currentUser} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} />}

              {!subView && tab === "home" && (
                <Dashboard user={currentUser} members={clubMembers} feePaid={!!feePaid[currentUser.id]} channels={channels} dutyPlan={dutyPlan} seasonVotes={seasonVotes} polls={polls} setPolls={setPolls}
                  sponsorBookings={sponsorBookings} onSponsorImpression={onSponsorImpression} onSponsorClick={onSponsorClick}
                  goEvents={goToMyNextMatch} goSeason={() => setSubView("season")} goTipp={() => setSubView("tipp")} goDuty={() => setSubView("duty")} goNews={goNews} />
              )}
              {!subView && tab === "events" && (
                <EventsView currentUser={currentUser} members={clubMembers} events={events} setEvents={setEvents} carpools={carpools} setCarpools={setCarpools}
                  dutyPlan={dutyPlan} setDutyPlan={setDutyPlan}
                  sponsorBookings={sponsorBookings} onSponsorImpression={onSponsorImpression} onSponsorClick={onSponsorClick}
                  focusRequest={eventFocusRequest} onFocusApplied={()=>setEventFocusRequest(null)} />
              )}
              {!subView && tab === "fees" && currentUserCanManageFees && <FeesView members={clubMembers} records={feeRecords} setRecords={setFeeRecords} />}
              {!subView && tab === "chat" && <ChatView user={currentUser} channels={channels} setChannels={setChannels} activeId={chatChannelId} setActiveId={setChatChannelId} />}
              {!subView && tab === "redaktion" && currentUserCanEditNews && <RedaktionView user={currentUser} channels={channels} setChannels={setChannels} />}
              {!subView && tab === "admin" && (currentUserIsAdmin || currentUserCanEditSponsors) && (
                <AdminView members={clubMembers} setMembers={setMembers} feePaid={feePaid} setFeePaid={setFeePaid} dutyPlan={dutyPlan} setDutyPlan={setDutyPlan} seasonVotes={seasonVotes}
                  currentUser={currentUser} channels={channels} setChannels={setChannels} maintenanceMode={maintenanceMode} setMaintenanceMode={setMaintenanceMode} onResetDemo={resetDemoData}
                  protocols={protocols} setProtocols={setProtocols} remindersSent={remindersSent} setRemindersSent={setRemindersSent}
                  welcomeAutomation={welcomeAutomation} setWelcomeAutomation={setWelcomeAutomation} billingAutomation={billingAutomation} setBillingAutomation={setBillingAutomation}
                  sponsorBookings={sponsorBookings} setSponsorBookings={setSponsorBookings} sponsorStats={sponsorStats} polls={polls} setPolls={setPolls}
                  tippResults={tippResults} onSaveTippResult={saveTippResult}
                  currentClub={currentClub} onClubLogoUpdated={updateCurrentClubLogo} />
              )}
              {!subView && tab === "profile" && <ProfileView user={currentUser} members={clubMembers} setMembers={setMembers} sponsorBookings={sponsorBookings} onSponsorImpression={onSponsorImpression} onSponsorClick={onSponsorClick} onLogout={logout} />}
            </div>

            {!subView && (
              <div className="absolute bottom-0 left-0 right-0 flex items-center justify-around py-2.5 px-1" style={{ background: "rgba(246,243,236,0.92)", backdropFilter: "blur(8px)", borderTop: `1px solid ${C.line}` }}>
                {TABS.map((t) => {
                  const activeTab = tab === t.id;
                  return (
                    <button key={t.id} onClick={() => navigateTab(t.id)} className="flex flex-col items-center gap-0.5 px-1.5 py-1 transition-colors duration-150">
                      <t.icon size={18} style={{ color: activeTab ? C.red : "#A6A49C" }} strokeWidth={activeTab ? 2.4 : 2} />
                      <span className="text-[9px]" style={{ fontFamily: "Inter", fontWeight: activeTab ? 700 : 500, color: activeTab ? C.red : "#A6A49C" }}>{t.label}</span>
                    </button>
                  );
                })}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
