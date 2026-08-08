import { NextResponse } from "next/server";
import { paypalPlanId } from "@/lib/paypal";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    return NextResponse.json({
      clientId: process.env.PAYPAL_CLIENT_ID,
      currency: "EUR",
      plans: {
        basic: { monthly: paypalPlanId("club_basic_monthly"), yearly: paypalPlanId("club_basic_yearly") },
        premium: { monthly: paypalPlanId("club_premium_monthly"), yearly: paypalPlanId("club_premium_yearly") },
      },
      environment: process.env.PAYPAL_ENVIRONMENT === "live" ? "live" : "sandbox",
    });
  } catch {
    return NextResponse.json({ error: "PayPal ist noch nicht konfiguriert." }, { status: 503 });
  }
}
