// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient, SupabaseClient } from "@supabase/supabase-js"
import type { Database } from "../_shared/types/database.types.ts"
import { buildErrorResponse } from "../_shared/utils.ts"
import Stripe from "stripe"
// import SessionCreateParams from "stripe"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {})

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") {
        return buildErrorResponse("Method Not Allowed", 405)
    }
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
        return buildErrorResponse("Unauthorized", 401)
    }

    let supabaseClient: SupabaseClient
    try {
        supabaseClient = createClient<Database>(
            Deno.env.get("SUPABASE_URL") ?? "",
            Deno.env.get("SUPABASE_ANON_KEY") ?? "",
            // Create client with Auth context of the user that called the function.
            // This way your row-level-security (RLS) policies are applied.
            {
                global: {
                    headers: { Authorization: authHeader },
                },
            },
        )
    } catch (error) {
        return buildErrorResponse(error, 500)
    }

    const { data, error } = await supabaseClient.from(
        "user_entitlements",
    ).select("*")

    if (error) {
        console.error(error)
        return buildErrorResponse(error, 500)
    }

    if (data.length === 0) {
        return buildErrorResponse("Unknwon User", 400)
    }
    const user = data[0]
    const customerId = user.stripe_customer_id
    let email: string | null
    try {
        email = await getUserEmail(supabaseClient)
    } catch (error) {
        console.error(error)
        return buildErrorResponse(error, 500)
    }

    const body = await req.json()
    if (body.price_id === null) {
        return buildErrorResponse("Price ID is required", 400)
    }
    const priceId = body.price_id as string
    const successURL = body.success_url as string | null
    const cancelledURL = body.cancelled_url as string | null

    const checkoutSession = await createCheckoutSession(
        customerId,
        email,
        user.id,
        priceId,
        successURL,
        cancelledURL,
    )

    return new Response(
        JSON.stringify(checkoutSession),
        { headers: { "Content-Type": "application/json" } },
    )
})

async function getUserEmail(supabaseClient: SupabaseClient): Promise<string> {
    const { data, error } = await supabaseClient.auth.getUser()
    if (error) {
        console.error(error)
        throw error
    }
    if (!data.user.email) {
        throw new Error("Email required.")
    }

    return data.user.email
}

async function createCheckoutSession(
    customerId: string | null,
    customerEmail: string,
    userId: string,
    priceId: string,
    successURL: string | null,
    cancelledURL: string | null,
) {
    const session = await stripe.checkout.sessions.create({
        mode: "subscription",
        // A unique string to reference the Checkout Session.
        // This can be a customer ID, a cart ID, or similar, and can be used to reconcile the Session with your internal systems.
        client_reference_id: userId,
        // only one of the email or id, but not both
        customer_email: customerId === null ? customerEmail : undefined,
        customer: customerId ?? undefined,
        line_items: [{
            price: priceId,
            quantity: 1,
        }],
        // custom URL scheme won't work
        success_url: successURL ?? undefined,
        // custom URL scheme won't work
        cancel_url: cancelledURL ?? undefined,
        expand: ["subscription"],
    })

    return session
}
