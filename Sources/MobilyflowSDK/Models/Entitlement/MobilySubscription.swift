//
//  MobilySubscription.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 06/11/2025.
//

import Foundation
import StoreKit

@objc public class MobilySubscription: Serializable {
    @objc public let id: UUID
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let productId: UUID
    @objc public let productOfferId: UUID?
    @objc public let startsAt: Date
    @objc public let endsAt: Date
    @objc public let platform: String
    @objc public let renewProductId: UUID?
    @objc public let renewProductOfferId: UUID?
    @objc public let lastPriceMillis: Int
    @objc public let regularPriceMillis: Int
    @objc public let renewPriceMillis: Int
    @objc public let currency: String
    @objc public let offerExpiresAt: Date?
    @objc public let offerRemainingCycle: Int
    @objc public let isAutoRenewing: Bool
    @objc public let isInGracePeriod: Bool
    @objc public let isInBillingIssue: Bool
    @objc public let hasPauseScheduled: Bool
    @objc public let isPaused: Bool
    @objc public let resumesAt: Date?
    @objc public let isExpiredOrRevoked: Bool
    @objc public let isManagedByThisStoreAccount: Bool
    @objc public let lastPlatformTxOriginalId: String?
    @objc public let Product: MobilyProduct?
    @objc public let ProductOffer: MobilySubscriptionOffer?
    @objc public let RenewProduct: MobilyProduct?
    @objc public let RenewProductOffer: MobilySubscriptionOffer?

    @objc init(id: UUID, createdAt: Date, updatedAt: Date, productId: UUID, productOfferId: UUID?, startsAt: Date, endsAt: Date, platform: String, renewProductId: UUID?, renewProductOfferId: UUID?, lastPriceMillis: Int, regularPriceMillis: Int, renewPriceMillis: Int, currency: String, offerExpiresAt: Date?, offerRemainingCycle: Int, isAutoRenewing: Bool, isInGracePeriod: Bool, isInBillingIssue: Bool, hasPauseScheduled: Bool, isPaused: Bool, resumesAt: Date?, isExpiredOrRevoked: Bool, isManagedByThisStoreAccount: Bool, lastPlatformTxOriginalId: String?, Product: MobilyProduct?, ProductOffer: MobilySubscriptionOffer?, RenewProduct: MobilyProduct?, RenewProductOffer: MobilySubscriptionOffer?) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productId = productId
        self.productOfferId = productOfferId
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.platform = MobilyPlatform.parse(platform)
        self.renewProductId = renewProductId
        self.renewProductOfferId = renewProductOfferId
        self.lastPriceMillis = lastPriceMillis
        self.regularPriceMillis = regularPriceMillis
        self.renewPriceMillis = renewPriceMillis
        self.currency = currency
        self.offerExpiresAt = offerExpiresAt
        self.offerRemainingCycle = offerRemainingCycle
        self.isAutoRenewing = isAutoRenewing
        self.isInGracePeriod = isInGracePeriod
        self.isInBillingIssue = isInBillingIssue
        self.hasPauseScheduled = hasPauseScheduled
        self.isPaused = isPaused
        self.resumesAt = resumesAt
        self.isExpiredOrRevoked = isExpiredOrRevoked
        self.isManagedByThisStoreAccount = isManagedByThisStoreAccount
        self.lastPlatformTxOriginalId = lastPlatformTxOriginalId
        self.Product = Product
        self.ProductOffer = ProductOffer
        self.RenewProduct = RenewProduct
        self.RenewProductOffer = RenewProductOffer
        super.init()
    }

    static func parse(_ jsonSubscription: [String: Any], storeAccountTransactions: [UInt64: Transaction]) async -> MobilySubscription {
        let platform = jsonSubscription["platform"] as! String
        var isAutoRenewing = jsonSubscription["isAutoRenewing"] as! Bool

        var lastPlatformTxOriginalId = jsonSubscription["lastPlatformTxOriginalId"] as? String
        var storeAccountTx: Transaction?

        if platform == MobilyPlatform.IOS && lastPlatformTxOriginalId != nil && !lastPlatformTxOriginalId!.isEmpty {
            storeAccountTx = storeAccountTransactions[UInt64(lastPlatformTxOriginalId!)!]

            if storeAccountTx != nil {
                isAutoRenewing = (await getRenewalInfo(tx: storeAccountTx!))?.willAutoRenew ?? isAutoRenewing
            }
        } else if platform == MobilyPlatform.ANDROID {
            lastPlatformTxOriginalId = nil
        }

        let jsonProduct = jsonSubscription["Product"] as? [String: Any]
        let product = jsonProduct != nil ? await MobilyProduct.parse(jsonProduct!) : nil

        let jsonProductOffer = jsonSubscription["ProductOffer"] as? [String: Any]
        let jsonRenewProduct = jsonSubscription["RenewProduct"] as? [String: Any]
        let jsonRenewProductOffer = jsonSubscription["RenewProductOffer"] as? [String: Any]

        var productOffer: MobilySubscriptionOffer? = nil
        var renewProduct: MobilyProduct? = nil
        var renewProductOffer: MobilySubscriptionOffer? = nil

        if product != nil && jsonProductOffer != nil {
            let iosProduct = MobilyPurchaseRegistry.getIOSProduct(product!.ios_sku)
            productOffer = await MobilySubscriptionOffer.parse(jsonProduct: jsonProduct!, jsonOffer: jsonProductOffer!, iosProduct: iosProduct)
        }

        if jsonRenewProduct != nil {
            renewProduct = await MobilyProduct.parse(jsonRenewProduct!)

            if jsonRenewProductOffer != nil {
                let iosProduct = MobilyPurchaseRegistry.getIOSProduct(renewProduct!.ios_sku)
                renewProductOffer = await MobilySubscriptionOffer.parse(jsonProduct: jsonRenewProduct!, jsonOffer: jsonRenewProductOffer!, iosProduct: iosProduct)
            }
        }

        return MobilySubscription(
            id: parseUUID(jsonSubscription["id"] as! String),
            createdAt: parseDate(jsonSubscription["createdAt"] as! String),
            updatedAt: parseDate(jsonSubscription["updatedAt"] as! String),
            productId: parseUUID(jsonSubscription["productId"] as! String),
            productOfferId: parseUUIDOpt(jsonSubscription["productOfferId"] as? String),
            startsAt: parseDate(jsonSubscription["startsAt"] as! String),
            endsAt: parseDate(jsonSubscription["endsAt"] as! String),
            platform: platform,
            renewProductId: parseUUIDOpt(jsonSubscription["renewProductId"] as? String),
            renewProductOfferId: parseUUIDOpt(jsonSubscription["renewProductOfferId"] as? String),
            lastPriceMillis: jsonSubscription["lastPriceMillis"] as! Int,
            regularPriceMillis: jsonSubscription["regularPriceMillis"] as! Int,
            renewPriceMillis: jsonSubscription["renewPriceMillis"] as! Int,
            currency: jsonSubscription["currency"] as! String,
            offerExpiresAt: parseDateOpt(jsonSubscription["offerExpiresAt"] as? String),
            offerRemainingCycle: jsonSubscription["offerRemainingCycle"] as! Int,
            isAutoRenewing: isAutoRenewing,
            isInGracePeriod: jsonSubscription["isInGracePeriod"] as! Bool,
            isInBillingIssue: jsonSubscription["isInBillingIssue"] as! Bool,
            hasPauseScheduled: jsonSubscription["hasPauseScheduled"] as! Bool,
            isPaused: jsonSubscription["isPaused"] as! Bool,
            resumesAt: parseDateOpt(jsonSubscription["resumesAt"] as? String),
            isExpiredOrRevoked: jsonSubscription["isExpiredOrRevoked"] as! Bool,
            isManagedByThisStoreAccount: storeAccountTx != nil,
            lastPlatformTxOriginalId: lastPlatformTxOriginalId,
            Product: product,
            ProductOffer: productOffer,
            RenewProduct: renewProduct,
            RenewProductOffer: renewProductOffer,
        )
    }
}
