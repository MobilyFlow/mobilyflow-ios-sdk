//
//  MobilyCustomerEntitlement.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import Foundation
import StoreKit

@objc public class MobilyCustomerEntitlement: Serializable {
    @objc public let type: ProductType
    @objc public let product: MobilyProduct
    @objc public let platformOriginalTransactionId: String?
    @objc public let item: ItemEntitlement?
    @objc public let subscription: SubscriptionEntitlement?
    @objc public let customerId: String

    @objc init(type: ProductType, product: MobilyProduct, platformOriginalTransactionId: String?, item: ItemEntitlement?, subscription: SubscriptionEntitlement?, customerId: String) {
        self.type = type
        self.product = product
        self.platformOriginalTransactionId = platformOriginalTransactionId
        self.item = item
        self.subscription = subscription
        self.customerId = customerId

        super.init()
    }

    static func parse(jsonEntitlement: [String: Any], storeAccountTransactions: [UInt64: Transaction], currentRegion: String?) async -> MobilyCustomerEntitlement {
        let type = ProductType.parse(jsonEntitlement["type"]! as! String)!
        let jsonEntity = jsonEntitlement["entity"] as! [String: Any]
        let product = await MobilyProduct.parse(jsonProduct: jsonEntity["Product"] as! [String: Any], currentRegion: currentRegion)
        let platformOriginalTransactionId = jsonEntitlement["platformOriginalTransactionId"] as? String

        var item: ItemEntitlement? = nil
        var subscription: SubscriptionEntitlement? = nil
        let customerId = jsonEntity["customerId"] as! String

        if type == .one_time {
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
            let renewProductOfferJson = jsonEntity["RenewProductOffer"] as? [String: Any]

            subscription = SubscriptionEntitlement(
                startDate: dateFormatter.date(from: jsonEntity["startDate"]! as! String)!,
                endDate: dateFormatter.date(from: jsonEntity["endDate"]! as! String)!,
                autoRenewEnable: autoRenewEnable,
                isInGracePeriod: jsonEntity["isInGracePeriod"] as! Bool,
                isInBillingIssue: jsonEntity["isInBillingIssue"] as! Bool,
                isExpiredOrRevoked: jsonEntity["isExpiredOrRevoked"] as! Bool,
                isPaused: jsonEntity["isPaused"] as! Bool,
                hasPauseScheduled: jsonEntity["hasPauseScheduled"] as! Bool,
                resumeDate: jsonEntity["resumeDate"] == nil ? nil : dateFormatter.date(from: jsonEntity["resumeDate"]! as! String)!,
                offerExpiryDate: jsonEntity["offerExpiryDate"] == nil ? nil : dateFormatter.date(from: jsonEntity["offerExpiryDate"]! as! String)!,
                offerRemainingCycle: jsonEntity["offerRemainingCycle"] as! Int,
                currency: jsonEntity["currency"] as! String,
                lastPriceMillis: jsonEntity["lastPriceMillis"] as! Int,
                regularPriceMillis: jsonEntity["regularPriceMillis"] as! Int,
                renewPriceMillis: jsonEntity["renewPriceMillis"] as! Int,
                platform: Platform.parse(jsonEntity["platform"]! as! String)!,
                isManagedByThisStoreAccount: storeAccountTx != nil,
                renewProduct: renewProductJson != nil ? await MobilyProduct.parse(jsonProduct: renewProductJson!, currentRegion: currentRegion) : nil,
                renewProductOffer: renewProductJson != nil && renewProductOfferJson != nil ?
                    await MobilySubscriptionOffer.parse(
                        jsonBase: renewProductJson!,
                        jsonOffer: renewProductOfferJson,
                        iosProduct: MobilyPurchaseRegistry.getIOSProduct(renewProductJson!["ios_sku"]! as! String),
                        currentRegion: currentRegion
                    ) : nil,
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
        @objc public let isInGracePeriod: Bool
        @objc public let isInBillingIssue: Bool
        @objc public let isExpiredOrRevoked: Bool
        @objc public let isPaused: Bool
        @objc public let hasPauseScheduled: Bool
        @objc public let resumeDate: Date?
        @objc public let offerExpiryDate: Date?
        @objc public let offerRemainingCycle: Int
        @objc public let currency: String
        @objc public let lastPriceMillis: Int
        @objc public let regularPriceMillis: Int
        @objc public let renewPriceMillis: Int
        @objc public let platform: Platform
        @objc public let isManagedByThisStoreAccount: Bool
        @objc public let renewProduct: MobilyProduct?
        @objc public let renewProductOffer: MobilySubscriptionOffer?

        @objc init(
            startDate: Date,
            endDate: Date,
            autoRenewEnable: Bool,
            isInGracePeriod: Bool,
            isInBillingIssue: Bool,
            isExpiredOrRevoked: Bool,
            isPaused: Bool,
            hasPauseScheduled: Bool,
            resumeDate: Date?,
            offerExpiryDate: Date?,
            offerRemainingCycle: Int,
            currency: String,
            lastPriceMillis: Int,
            regularPriceMillis: Int,
            renewPriceMillis: Int,
            platform: Platform,
            isManagedByThisStoreAccount: Bool,
            renewProduct: MobilyProduct?,
            renewProductOffer: MobilySubscriptionOffer?
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.autoRenewEnable = autoRenewEnable
            self.isInGracePeriod = isInGracePeriod
            self.isInBillingIssue = isInBillingIssue
            self.isExpiredOrRevoked = isExpiredOrRevoked
            self.isPaused = isPaused
            self.hasPauseScheduled = hasPauseScheduled
            self.resumeDate = resumeDate
            self.offerExpiryDate = offerExpiryDate
            self.offerRemainingCycle = offerRemainingCycle
            self.currency = currency
            self.lastPriceMillis = lastPriceMillis
            self.regularPriceMillis = regularPriceMillis
            self.renewPriceMillis = renewPriceMillis
            self.platform = platform
            self.isManagedByThisStoreAccount = isManagedByThisStoreAccount
            self.renewProduct = renewProduct
            self.renewProductOffer = renewProductOffer

            super.init()
        }
    }
}
