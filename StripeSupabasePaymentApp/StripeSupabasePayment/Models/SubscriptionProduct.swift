//
//  SubscriptionProduct.swift
//  StripeSupabasePayment
//
//  Created by Itsuki on 2026/01/02.
//

import Foundation

struct SubscriptionProduct: Identifiable {
    var id: String {
        return priceId
    }

    var priceId: String
    var productName: String

    static let allProducts: [SubscriptionProduct] = [
        .init(priceId: "price_xxx", productName: "Free"),
        .init(
            priceId: "price_yyy",
            productName: "Premium"
        ),
    ]

    init(priceId: String, productName: String) {
        self.priceId = priceId
        self.productName = productName
    }

    init?(priceId: String) {
        guard
            let product = Self.allProducts.first(where: {
                $0.priceId == priceId
            })
        else {
            return nil
        }
        self = product
    }
}
