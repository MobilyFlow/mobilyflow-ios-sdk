//
//  MobilyCustomerEntitlement.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import Foundation
import StoreKit

public class MobilyCustomerEntitlement {
    let type: ProductType
    let product: MobilyProduct
    let platformOriginalTransactionId: String?
    let item: ItemEntitlement?
    let subscription: SubscriptionEntitlement?

    init(type: ProductType, product: MobilyProduct, platformOriginalTransactionId: String?, item: ItemEntitlement?, subscription: SubscriptionEntitlement?) {
        self.type = type
        self.product = product
        self.platformOriginalTransactionId = platformOriginalTransactionId
        self.item = item
        self.subscription = subscription
    }

    static func parse(jsonEntitlement: [String: Any], storeAccountTransactions: [UInt64: Transaction]) async -> MobilyCustomerEntitlement {
        let type = ProductType(rawValue: jsonEntitlement["type"]! as! String)!
        let jsonEntity = jsonEntitlement["entity"] as! [String: Any]
        let product = await MobilyProduct.parse(jsonProduct: jsonEntity["Product"] as! [String: Any])
        let platformOriginalTransactionId = jsonEntitlement["platformOriginalTransactionId"] as? String

        var item: ItemEntitlement? = nil
        var subscription: SubscriptionEntitlement? = nil

        if type == .one_time {
            item = ItemEntitlement(quantity: jsonEntity["quantity"] as! Int)
        } else {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFractionalSeconds]

            let platform = Platform(rawValue: jsonEntity["platform"]! as! String)!

            var storeAccountTx: Transaction? = nil
            var autoRenewEnable = jsonEntity["autoRenewEnable"]! as! Bool
            if platform == .ios && platformOriginalTransactionId != nil {
                let platformTxIdInt = UInt64(platformOriginalTransactionId!)
                if platformTxIdInt != nil {
                    storeAccountTx = storeAccountTransactions[platformTxIdInt!]
                }
            }

            let renewalInfo = await getRenewalInfo(tx: storeAccountTx)
            if renewalInfo != nil {
                autoRenewEnable = renewalInfo!.willAutoRenew
            }

            subscription = SubscriptionEntitlement(
                startDate: dateFormatter.date(from: jsonEntity["startDate"]! as! String)!,
                expirationDate: dateFormatter.date(from: jsonEntity["expirationDate"]! as! String)!,
                autoRenewEnable: autoRenewEnable,
                platform: Platform(rawValue: jsonEntity["platform"]! as! String)!,
                isManagedByThisStoreAccount: storeAccountTx != nil
            )
        }

        return MobilyCustomerEntitlement(
            type: type,
            product: product,
            platformOriginalTransactionId: platformOriginalTransactionId,
            item: item,
            subscription: subscription
        )
    }

    class ItemEntitlement {
        let quantity: Int

        init(quantity: Int) {
            self.quantity = quantity
        }
    }

    class SubscriptionEntitlement {
        let startDate: Date
        let expirationDate: Date
        let autoRenewEnable: Bool
        let platform: Platform
        let isManagedByThisStoreAccount: Bool

        init(startDate: Date, expirationDate: Date, autoRenewEnable: Bool, platform: Platform, isManagedByThisStoreAccount: Bool) {
            self.startDate = startDate
            self.expirationDate = expirationDate
            self.autoRenewEnable = autoRenewEnable
            self.platform = platform
            self.isManagedByThisStoreAccount = isManagedByThisStoreAccount
        }
    }
}
