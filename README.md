# SwiftUI + Stripe + Supabase: WebBasedPayment Demo

A demo of integrating Stripe Subscriptions (create & manage) with Supabase,
SwiftUI.

For more details, please refer to my blog
[SwiftUI: Demystify Web Based Payment With Stripe + Supabase](https://medium.com/p/swiftui-demystify-web-based-payment-with-stripe-supabase-77fa7be40de4)

![](./demo.gif)

## Some useful Commands

**Deploy DB to remote**

```bash
supabase db push
```

**Deploy secrets to remote**

```bash
supabase secrets set --env-file 'functions/.env'
# to list secrets
supabase secrets list
```

**Deploy configs to remote**

```bash
supabase config push
```
