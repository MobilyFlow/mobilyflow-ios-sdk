//
//  MobilyCustomerEntitlement.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import Foundation
import StoreKit

@objc public class MobilyCustomerEntitlement: Serializable {
    @objc public let type: String
    @objc public let Product: MobilyProduct
    @objc public let Item: MobilyItem?
    @objc public let Subscription: MobilySubscription?
    @objc public let customerId: String

    @objc init(type: String, Product: MobilyProduct, Item: MobilyItem?, Subscription: MobilySubscription?, customerId: String) {
        self.type = type
        self.Product = Product
        self.Item = Item
        self.Subscription = Subscription
        self.customerId = customerId

        super.init()
    }

    static func parse(jsonEntitlement: [String: Any], storeAccountTransactions: [UInt64: Transaction]) async -> MobilyCustomerEntitlement {
        let type = jsonEntitlement["type"]! as! String
        let jsonEntity = jsonEntitlement["entity"] as! [String: Any]
        let product: MobilyProduct

        var item: MobilyItem? = nil
        var subscription: MobilySubscription? = nil

        if type == ProductType.ONE_TIME {
            item = await MobilyItem.parse(jsonItem: jsonEntity)
            product = item!.Product
        } else {
            subscription = await MobilySubscription.parse(jsonSubscription: jsonEntity, storeAccountTransactions: storeAccountTransactions)
            product = subscription!.Product
        }

        return MobilyCustomerEntitlement(
            type: type,
            Product: product,
            Item: item,
            Subscription: subscription,
            customerId: jsonEntity["customerId"] as! String,
        )
    }
}
