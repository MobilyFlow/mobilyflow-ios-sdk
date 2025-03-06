//
//  PurchaseOptions.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 08/01/2025.
//

public class PurchaseOptions: NSObject {
    var offer: MobilySubscriptionOffer?
    var quantity: Int?

    public func setOffer(_ offer: MobilySubscriptionOffer?) -> PurchaseOptions {
        self.offer = offer
        return self
    }

    public func setQuantity(_ quantity: Int?) -> PurchaseOptions {
        self.quantity = quantity
        return self
    }
}
