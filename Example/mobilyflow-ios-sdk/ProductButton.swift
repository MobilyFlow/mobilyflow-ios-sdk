//
//  ProductButton.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 18/07/2024.
//

import mobilyflow_ios_sdk
import SwiftUI

struct ProductButton: View {
    var sdk: MobilyPurchaseSDK
    var product: MobilyProduct
    var offer: MobilySubscriptionOffer?
    var quantity: Int?

    var body: some View {
        Button(action: {
            Task(priority: .high) {
                do {
                    if offer == nil {
                        NSLog("Click \(product.identifier)")
                        try await sdk.purchaseProduct(product, options: PurchaseOptions().setQuantity(quantity))
                    } else {
                        NSLog("Click \(product.identifier) offer \(offer?.ios_offerId ?? "free trial")")
                        try await sdk.purchaseProduct(product, options: PurchaseOptions().setOffer(offer!))
                    }
                } catch {
                    NSLog("Purchase Error \(error)")
                }
            }
        }, label: {
            VStack(spacing: 5) {
                Text(product.name)
                Text(product.description)
                Text(offer?.priceFormatted ?? product.oneTimeProduct?.priceFormatted ?? product.subscriptionProduct?.baseOffer.priceFormatted ?? "-")

                if offer != nil {
                    Text(offer!.ios_offerId ?? "-")
                }
                if quantity != nil {
                    Text("Quantity: \(quantity!)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.all, 10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange, lineWidth: 1))
        })
        .buttonStyle(PlainButtonStyle())
    }
}
