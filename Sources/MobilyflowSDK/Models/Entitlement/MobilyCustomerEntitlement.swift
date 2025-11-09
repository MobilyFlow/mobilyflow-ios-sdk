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
    @objc public let customerId: UUID

    @objc init(type: String, Product: MobilyProduct, Item: MobilyItem?, Subscription: MobilySubscription?, customerId: UUID) {
        self.type = MobilyProductType.parse(type)
        self.Product = Product
        self.Item = Item
        self.Subscription = Subscription
        self.customerId = customerId

        super.init()
    }

    static func parse(_ jsonEntitlement: [String: Any], storeAccountTransactions: [UInt64: Transaction]) async -> MobilyCustomerEntitlement {
        let type = jsonEntitlement["type"] as! String
        let jsonEntity = jsonEntitlement["entity"] as! [String: Any]
        let product: MobilyProduct

        var item: MobilyItem? = nil
        var subscription: MobilySubscription? = nil

        if type == MobilyProductType.ONE_TIME {
            item = await MobilyItem.parse(jsonEntity)
            product = item!.Product!
        } else {
            subscription = await MobilySubscription.parse(jsonEntity, storeAccountTransactions: storeAccountTransactions)
            product = subscription!.Product!
        }

        return MobilyCustomerEntitlement(
            type: type,
            Product: product,
            Item: item,
            Subscription: subscription,
            customerId: parseUUID(jsonEntity["customerId"] as! String)!,
        )
    }
}
