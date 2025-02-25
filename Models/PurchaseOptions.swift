//
//  PurchaseOptions.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 08/01/2025.
//

class PurchaseOptions {
    var offer: MobilySubscriptionOffer?
    var quantity: Int?

    init() {}

    func setOffer(_ offer: MobilySubscriptionOffer?) -> PurchaseOptions {
        self.offer = offer
        return self
    }

    func setQuantity(_ quantity: Int?) -> PurchaseOptions {
        self.quantity = quantity
        return self
    }
}
