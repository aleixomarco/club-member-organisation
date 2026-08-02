import { NextResponse } from "next/server";
import { paypalPlanId } from "@/lib/paypal";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    return NextResponse.json({
      clientId: process.env.PAYPAL_CLIENT_ID,
      currency: "EUR",
      plans: {
        member: { monthly: paypalPlanId("member_monthly"), yearly: paypalPlanId("member_yearly") },
        club: { monthly: paypalPlanId("club_monthly"), yearly: paypalPlanId("club_yearly") },
      },
      environment: process.env.PAYPAL_ENVIRONMENT === "live" ? "live" : "sandbox",
    });
  } catch {
    return NextResponse.json({ error: "PayPal ist noch nicht konfiguriert." }, { status: 503 });
  }
}
