//
//  PurchaseOptions.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 08/01/2025.
//

import Foundation

@objc public class PurchaseOptions: NSObject {
    var offer: MobilySubscriptionOffer?
    var quantity: Int?

    @objc override public init() {
        super.init()
    }

    @objc public init(offer: MobilySubscriptionOffer? = nil) {
        self.offer = offer
        super.init()
    }

    @objc public init(quantity: Int) {
        self.quantity = quantity
        super.init()
    }

    @objc public func setOffer(_ offer: MobilySubscriptionOffer?) -> PurchaseOptions {
        self.offer = offer
        return self
    }

    @objc public func setQuantity(_ quantity: Int) -> PurchaseOptions {
        self.quantity = quantity
        return self
    }
}
