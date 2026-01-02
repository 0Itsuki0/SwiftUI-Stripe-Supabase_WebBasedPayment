// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import Stripe from "stripe"
// import Event from "stripe"
// import Checkout from "stripe"
// import Subscription from "stripe"
// import SubscriptionItem from "stripe"
// import Plan from "stripe"

import { createClient } from "@supabase/supabase-js"
import type { Database } from "../_shared/types/database.types.ts"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {})
const supabaseClient = createClient<Database>(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
)

Deno.serve(async (req: Request) => {
    const signature = req.headers.get("stripe-signature")
    if (!signature) {
        return new Response("Unauthorized", { status: 401 })
    }

    let event: Stripe.Event
    // need the raw request to verify signature
    const raw = await req.text()
    try {
        event = await stripe.webhooks.constructEventAsync(
            raw,
            signature,
            Deno.env.get("STRPIE_ENDPOINT_SECRET") ?? "",
        )
    } catch (err) {
        console.log(`Webhook signature verification failed.`, err)
        return new Response(null, { status: 400 })
    }
    console.log(event.type)

    // other ones we might want to watch
    // - AccountUpdatedEvent: to check if user deleted their account
    switch (event.type) {
        // to handle completion for checkout session we created.
        case "checkout.session.completed": {
            const session: Stripe.Checkout.Session = event.data.object
            if (!session.client_reference_id) {
                break
            }

            let customer = session.customer
            if (typeof customer !== "string") {
                customer = null
            }

            let subscription = session.subscription
            // this will be null for subscription udpate or other payment type, for example, one time
            // we will be handling udpates within the customer.subscription.updated event
            if (subscription === null) {
                break
            }

            if (typeof subscription === "string") {
                subscription = await stripe.subscriptions.retrieve(subscription)
            }

            const subscriptionObject: Stripe.Subscription =
                subscription as Stripe.Subscription
            await updateEntitlement(
                subscriptionObject,
                customer,
                session.client_reference_id,
            )
            break
        }
        case "customer.subscription.updated": {
            const subscription = event.data.object
            const { data, error } = await supabaseClient.from(
                "user_entitlements",
            ).select("id")
                .eq("subscription_id", subscription.id)
            if (error) {
                console.error(error)
                break
            }
            if (data.length === 0) {
                break
            }
            await updateEntitlement(subscription, null, data[0].id)
            break
        }
        case "customer.subscription.deleted": {
            const subscription = event.data.object
            await supabaseClient.from("user_entitlements").update({
                subscription_id: null,
                price_id: null,
                product_id: null,
                subscription_status: null,
                current_period_end: null,
                current_period_start: null,
            })
                .eq("subscription_id", subscription.id)
            break
        }
        default:
            console.log(`Unhandled event type ${event.type}.`)
    }

    return new Response(null, { status: 200 })
})

function timeStampToISO(timestamp: number): string {
    // second to millisecond
    const dateObject: Date = new Date(timestamp * 1000)
    return dateObject.toISOString()
}

async function updateEntitlement(
    subscription: Stripe.Subscription,
    customerId: string | null,
    userId: string,
) {
    let customer: string | null = customerId
    if (customerId === null && typeof subscription.customer === "string") {
        customer = subscription.customer
    }

    const items: { [key: string]: object } = subscription.items as unknown as {
        [key: string]: object
    }
    if (!Object.hasOwn(items, "data")) {
        return
    }
    const data = items.data
    if (!Array.isArray(data) || data.length === 0) {
        return
    }

    const subscriptionItem: { [key: string]: object } = data[0]
    console.log(subscriptionItem)
    if (
        !Object.hasOwn(subscriptionItem, "plan") ||
        !Object.hasOwn(subscriptionItem, "current_period_end") ||
        !Object.hasOwn(subscriptionItem, "current_period_start")
    ) {
        return
    }

    const plan: Stripe.Plan = subscriptionItem.plan as Stripe.Plan
    console.log(plan)

    await supabaseClient.from("user_entitlements").update({
        subscription_id: subscription.id,
        stripe_customer_id: customer,
        price_id: plan.id,
        product_id: plan.product as unknown as string | null,
        subscription_status: subscription.status,
        current_period_end: timeStampToISO(
            subscriptionItem.current_period_end as unknown as number,
        ),
        current_period_start: timeStampToISO(
            subscriptionItem.current_period_start as unknown as number,
        ),
    })
        .eq("id", userId)
}
