//
//  MobilyItem.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 06/11/2025.
//

import Foundation
import StoreKit

@objc public class MobilySubscription: Serializable {
    @objc public let id: String
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let productId: String
    @objc public let productOfferId: String
    @objc public let startDate: Date
    @objc public let endDate: Date
    @objc public let platform: String
    @objc public let renewProductId: String
    @objc public let renewProductOfferId: String
    @objc public let lastPriceMillis: Int
    @objc public let regularPriceMillis: Int
    @objc public let renewPriceMillis: Int
    @objc public let currency: String
    @objc public let offerExpiryDate: Date?
    @objc public let offerRemainingCycle: Int
    @objc public let autoRenewEnable: Bool
    @objc public let isInGracePeriod: Bool
    @objc public let isInBillingIssue: Bool
    @objc public let hasPauseScheduled: Bool
    @objc public let isPaused: Bool
    @objc public let resumeDate: Date?
    @objc public let isExpiredOrRevoked: Bool
    @objc public let isManagedByThisStoreAccount: Bool
    @objc public let lastPlatformTxOriginalId: String?
    @objc public let Product: MobilyProduct
    @objc public let ProductOffer: MobilySubscriptionOffer?
    @objc public let RenewProduct: MobilyProduct?
    @objc public let RenewProductOffer: MobilySubscriptionOffer?

    @objc init(id: String, createdAt: Date, updatedAt: Date, productId: String, productOfferId: String, startDate: Date, endDate: Date, platform: String, renewProductId: String, renewProductOfferId: String, lastPriceMillis: Int, regularPriceMillis: Int, renewPriceMillis: Int, currency: String, offerExpiryDate: Date?, offerRemainingCycle: Int, autoRenewEnable: Bool, isInGracePeriod: Bool, isInBillingIssue: Bool, hasPauseScheduled: Bool, isPaused: Bool, resumeDate: Date?, isExpiredOrRevoked: Bool, isManagedByThisStoreAccount: Bool, lastPlatformTxOriginalId: String?, Product: MobilyProduct, ProductOffer: MobilySubscriptionOffer?, RenewProduct: MobilyProduct?, RenewProductOffer: MobilySubscriptionOffer?) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productId = productId
        self.productOfferId = productOfferId
        self.startDate = startDate
        self.endDate = endDate
        self.platform = platform
        self.renewProductId = renewProductId
        self.renewProductOfferId = renewProductOfferId
        self.lastPriceMillis = lastPriceMillis
        self.regularPriceMillis = regularPriceMillis
        self.renewPriceMillis = renewPriceMillis
        self.currency = currency
        self.offerExpiryDate = offerExpiryDate
        self.offerRemainingCycle = offerRemainingCycle
        self.autoRenewEnable = autoRenewEnable
        self.isInGracePeriod = isInGracePeriod
        self.isInBillingIssue = isInBillingIssue
        self.hasPauseScheduled = hasPauseScheduled
        self.isPaused = isPaused
        self.resumeDate = resumeDate
        self.isExpiredOrRevoked = isExpiredOrRevoked
        self.isManagedByThisStoreAccount = isManagedByThisStoreAccount
        self.lastPlatformTxOriginalId = lastPlatformTxOriginalId
        self.Product = Product
        self.ProductOffer = ProductOffer
        self.RenewProduct = RenewProduct
        self.RenewProductOffer = RenewProductOffer
        super.init()
    }

    static func parse(jsonSubscription: [String: Any], storeAccountTransactions: [UInt64: Transaction]) async -> MobilySubscription {
        let platform = jsonSubscription["platform"] as! String
        var autoRenewEnable = jsonSubscription["autoRenewEnable"] as! Bool

        var lastPlatformTxOriginalId = jsonSubscription["lastPlatformTxOriginalId"] as? String
        var storeAccountTx: Transaction?

        if platform == Platform.IOS && lastPlatformTxOriginalId != nil && !lastPlatformTxOriginalId!.isEmpty {
            storeAccountTx = storeAccountTransactions[UInt64(lastPlatformTxOriginalId!)!]

            if storeAccountTx != nil {
                autoRenewEnable = (await getRenewalInfo(tx: storeAccountTx!))?.willAutoRenew ?? autoRenewEnable
            }
        } else if platform == Platform.ANDROID {
            lastPlatformTxOriginalId = nil
        }

        let jsonProduct = jsonSubscription["Product"] as! [String: Any]
        var product = await MobilyProduct.parse(jsonProduct: jsonProduct)

        let jsonProductOffer = jsonSubscription["ProductOffer"] as? [String: Any]
        let jsonRenewProduct = jsonSubscription["RenewProduct"] as? [String: Any]
        let jsonRenewProductOffer = jsonSubscription["RenewProductOffer"] as? [String: Any]

        var productOffer: MobilySubscriptionOffer? = nil
        var renewProduct: MobilyProduct? = nil
        var renewProductOffer: MobilySubscriptionOffer? = nil

        if jsonProductOffer != nil {
            let iosProduct = MobilyPurchaseRegistry.getIOSProduct(product.ios_sku)
            productOffer = await MobilySubscriptionOffer.parse(jsonProduct: jsonProduct, jsonOffer: jsonProductOffer!, iosProduct: iosProduct)
        }

        if jsonRenewProduct != nil {
            renewProduct = await MobilyProduct.parse(jsonProduct: jsonRenewProduct!)

            // TODO: What if jsonRenewProduct is NULL but renewOffer is defined (change renew to same product but with an offer)
            if jsonRenewProductOffer != nil {
                let iosProduct = MobilyPurchaseRegistry.getIOSProduct(renewProduct!.ios_sku)
                renewProductOffer = await MobilySubscriptionOffer.parse(jsonProduct: jsonRenewProduct!, jsonOffer: jsonRenewProductOffer!, iosProduct: iosProduct)
            }
        }

        return MobilySubscription(
            id: jsonSubscription["id"] as! String,
            createdAt: parseDate(jsonSubscription["createdAt"]! as! String),
            updatedAt: parseDate(jsonSubscription["updatedAt"]! as! String),
            productId: jsonSubscription["productId"] as! String,
            productOfferId: jsonSubscription["productOfferId"] as! String,
            startDate: parseDate(jsonSubscription["startDate"] as! String),
            endDate: parseDate(jsonSubscription["endDate"] as! String),
            platform: platform,
            renewProductId: jsonSubscription["renewProductId"] as! String,
            renewProductOfferId: jsonSubscription["renewProductOfferId"] as! String,
            lastPriceMillis: jsonSubscription["lastPriceMillis"] as! Int,
            regularPriceMillis: jsonSubscription["regularPriceMillis"] as! Int,
            renewPriceMillis: jsonSubscription["renewPriceMillis"] as! Int,
            currency: jsonSubscription["currency"] as! String,
            offerExpiryDate: parseDateOpt(jsonSubscription["offerExpiryDate"] as? String),
            offerRemainingCycle: jsonSubscription["offerRemainingCycle"] as! Int,
            autoRenewEnable: autoRenewEnable,
            isInGracePeriod: jsonSubscription["isInGracePeriod"] as! Bool,
            isInBillingIssue: jsonSubscription["isInBillingIssue"] as! Bool,
            hasPauseScheduled: jsonSubscription["hasPauseScheduled"] as! Bool,
            isPaused: jsonSubscription["isPaused"] as! Bool,
            resumeDate: parseDateOpt(jsonSubscription["resumeDate"] as? String),
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
