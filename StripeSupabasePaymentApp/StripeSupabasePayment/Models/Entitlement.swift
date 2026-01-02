//
//  Entitlement.swift
//  StripeSupabasePayment
//
//  Created by Itsuki on 2026/01/02.
//


import Foundation

struct Entitlement: Identifiable, Hashable, Decodable {
    let id: UUID
    let subscription_id: String?
    let stripe_customer_id: String?
    let price_id: String?
    let product_id: String?
    let subscription_status: String?
    let current_period_start: Date?
    let current_period_end: Date?
}
