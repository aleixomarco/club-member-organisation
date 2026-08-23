import { NextResponse } from "next/server";
import { paypalPlanId, type PayPalPlanCode } from "@/lib/paypal";

export const dynamic = "force-dynamic";

/* paypalPlanId wirft, wenn die Umgebungsvariable fehlt. Frueher baute diese
   Route alle Stufen unbedingt auf - fehlte eine einzige Kennung, antwortete sie
   mit 503 und PayPal fiel fuer ALLE Stufen aus, auch fuer die vorhandenen.
   Deshalb hier stufenweise: Was hinterlegt ist, wird ausgeliefert; der Rest
   fehlt einfach. Neue Stufen erscheinen automatisch, sobald ihre Kennungen in
   Vercel eingetragen sind - ohne Codeaenderung. */
function planPaar(monthly: PayPalPlanCode, yearly: PayPalPlanCode) {
  try {
    return { monthly: paypalPlanId(monthly), yearly: paypalPlanId(yearly) };
  } catch {
    return null;
  }
}

export async function GET() {
  const clientId = process.env.PAYPAL_CLIENT_ID;
  if (!clientId) {
    return NextResponse.json(
      { error: "PayPal ist noch nicht konfiguriert.", grund: "PAYPAL_CLIENT_ID fehlt" },
      { status: 503 },
    );
  }

  const stufen: Record<string, ReturnType<typeof planPaar>> = {
    basic: planPaar("club_basic_monthly", "club_basic_yearly"),
    plus: planPaar("club_plus_monthly", "club_plus_yearly"),
    pro: planPaar("club_pro_monthly", "club_pro_yearly"),
    // Altbestand aus dem vorherigen Modell, wird auf "plus" abgebildet.
    premium: planPaar("club_premium_monthly", "club_premium_yearly"),
  };

  const plans = Object.fromEntries(Object.entries(stufen).filter(([, wert]) => wert !== null));

  if (Object.keys(plans).length === 0) {
    return NextResponse.json(
      { error: "PayPal ist noch nicht konfiguriert.", grund: "Keine einzige Plan-Kennung hinterlegt" },
      { status: 503 },
    );
  }

  return NextResponse.json({
    clientId,
    currency: "EUR",
    plans,
    environment: process.env.PAYPAL_ENVIRONMENT === "live" ? "live" : "sandbox",
  });
}
