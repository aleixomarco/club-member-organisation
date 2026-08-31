import { NextResponse } from "next/server";
import { SITZUNGS_COOKIE, cookieOptionen } from "@/lib/betreiber";

export const dynamic = "force-dynamic";

export async function POST() {
  const antwort = NextResponse.json({ ok: true });
  antwort.cookies.set(SITZUNGS_COOKIE, "", cookieOptionen(0));
  return antwort;
}
