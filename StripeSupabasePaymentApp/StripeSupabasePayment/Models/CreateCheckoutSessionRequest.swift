//
//  CreateCheckoutSessionRequest.swift
//  StripeSupabasePayment
//
//  Created by Itsuki on 2026/01/02.
//

import Foundation

struct CreateCheckoutSessionRequest: Codable {
    let price_id: String
    let success_url: String
    let cancelled_url: String
}
