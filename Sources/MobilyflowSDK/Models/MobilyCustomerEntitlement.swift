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
    @objc public let product: MobilyProduct
    @objc public let platformOriginalTransactionId: String?
    @objc public let item: ItemEntitlement?
    @objc public let subscription: SubscriptionEntitlement?
    @objc public let customerId: String

    @objc init(type: String, product: MobilyProduct, platformOriginalTransactionId: String?, item: ItemEntitlement?, subscription: SubscriptionEntitlement?, customerId: String) {
        self.type = type
        self.product = product
        self.platformOriginalTransactionId = platformOriginalTransactionId
        self.item = item
        self.subscription = subscription
        self.customerId = customerId

        super.init()
    }

    static func parse(jsonEntitlement: [String: Any], storeAccountTransactions: [UInt64: Transaction]) async -> MobilyCustomerEntitlement {
        let type = jsonEntitlement["type"] as! String
        let jsonEntity = jsonEntitlement["entity"] as! [String: Any]
        let product = await MobilyProduct.parse(jsonProduct: jsonEntity["Product"] as! [String: Any])
        let platformOriginalTransactionId = jsonEntitlement["platformOriginalTransactionId"] as? String

        var item: ItemEntitlement? = nil
        var subscription: SubscriptionEntitlement? = nil
        let customerId = jsonEntity["customerId"] as! String

        if type == ProductType.one_time {
            item = ItemEntitlement(quantity: jsonEntity["quantity"] as! Int)
        } else {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]

            let platform = Platform.parse(jsonEntity["platform"]! as! String)!

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

            let renewProductJson = jsonEntity["RenewProduct"] as? [String: Any]

            subscription = SubscriptionEntitlement(
                startDate: dateFormatter.date(from: jsonEntity["startDate"]! as! String)!,
                endDate: dateFormatter.date(from: jsonEntity["endDate"]! as! String)!,
                autoRenewEnable: autoRenewEnable,
                platform: Platform.parse(jsonEntity["platform"]! as! String)!,
                isManagedByThisStoreAccount: storeAccountTx != nil,
                renewProduct: renewProductJson != nil ? await MobilyProduct.parse(jsonProduct: renewProductJson!) : nil
            )
        }

        return MobilyCustomerEntitlement(
            type: type,
            product: product,
            platformOriginalTransactionId: platformOriginalTransactionId,
            item: item,
            subscription: subscription,
            customerId: customerId,
        )
    }

    @objc public class ItemEntitlement: Serializable {
        @objc public let quantity: Int

        @objc init(quantity: Int) {
            self.quantity = quantity
            super.init()
        }
    }

    @objc public class SubscriptionEntitlement: Serializable {
        @objc public let startDate: Date
        @objc public let endDate: Date
        @objc public let autoRenewEnable: Bool
        @objc public let platform: Platform
        @objc public let isManagedByThisStoreAccount: Bool
        @objc public let renewProduct: MobilyProduct?

        @objc init(startDate: Date, endDate: Date, autoRenewEnable: Bool, platform: Platform, isManagedByThisStoreAccount: Bool, renewProduct: MobilyProduct?) {
            self.startDate = startDate
            self.endDate = endDate
            self.autoRenewEnable = autoRenewEnable
            self.platform = platform
            self.isManagedByThisStoreAccount = isManagedByThisStoreAccount
            self.renewProduct = renewProduct

            super.init()
        }
    }
}
