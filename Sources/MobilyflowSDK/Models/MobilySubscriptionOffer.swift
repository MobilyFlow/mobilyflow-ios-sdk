//
//  MobilySubscriptionOffer.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 05/11/2024.
//

import Foundation
import StoreKit

@objc public class MobilySubscriptionOffer: Serializable {
    @objc public let id: String? // null for base offer
    @objc public let identifier: String? // null for base offer
    @objc public let externalRef: String? // null for base offer
    @objc public let referenceName: String?
    @objc public let name: String?
    @objc public let priceMillis: Int
    @objc public let currencyCode: String
    @objc public let priceFormatted: String
    @objc public let type: String?
    @objc public let periodCount: Int
    @objc public let periodUnit: String
    @objc public let countBillingCycle: Int
    @objc public let ios_offerId: String? // null for base offer
    @objc public let extras: [String: Any]?
    @objc public let status: String

    @objc init(id: String?, identifier: String?, externalRef: String?, referenceName: String?, name: String?, priceMillis: Int, currencyCode: String, priceFormatted: String, type: String?, periodCount: Int, periodUnit: String, countBillingCycle: Int, ios_offerId: String?, extras: [String: Any]? = nil, status: String) {
        self.id = id
        self.identifier = identifier
        self.externalRef = externalRef
        self.referenceName = referenceName
        self.name = name
        self.priceMillis = priceMillis
        self.currencyCode = currencyCode
        self.priceFormatted = priceFormatted
        self.type = type
        self.periodCount = periodCount
        self.periodUnit = periodUnit
        self.countBillingCycle = countBillingCycle
        self.ios_offerId = ios_offerId
        self.extras = extras
        self.status = status

        super.init()
    }

    static func parse(jsonBase: [String: Any], jsonOffer: [String: Any]?, iosProduct: Product?) async -> MobilySubscriptionOffer {
        var id: String? = nil
        var identifier: String? = nil
        var externalRef: String? = nil
        var referenceName: String? = nil
        var name: String? = nil
        let priceMillis: Int
        let currencyCode: String
        let priceFormatted: String
        var type = "recurring" // TODO: Use Enum
        let periodCount: Int
        let periodUnit: String
        let countBillingCycle: Int
        var ios_offerId: String? = nil
        var extras: [String: Any]? = nil
        var status = ProductStatus.UNAVAILABLE

        var iosOffer: Product.SubscriptionOffer?

        if jsonOffer != nil {
            id = jsonOffer!["id"] as? String
            identifier = jsonOffer!["identifier"] as? String
            externalRef = jsonOffer!["externalRef"] as? String
            referenceName = jsonOffer!["referenceName"] as? String
            name = getTranslationValue(jsonOffer!["_translations"] as! [[String: Any]], field: "name")
            extras = jsonOffer!["extras"] as? [String: Any]
            type = jsonOffer!["type"] as! String
            ios_offerId = jsonOffer!["ios_offerId"] as? String

            if iosProduct != nil {
                if ios_offerId != nil {
                    iosOffer = MobilyPurchaseRegistry.getIOSOffer(iosProduct!.id, offerId: ios_offerId!)
                } else if type == "free_trial" {
                    iosOffer = iosProduct!.subscription!.introductoryOffer
                }
            }
        }

        // 1. Validate offer
        if iosOffer != nil {
            if iosOffer?.paymentMode == .payUpFront {
                Logger.w("Pay Up Front is not supported for subscription offers (ios offer \(iosOffer?.id))")
                status = ProductStatus.INVALID
            }
        }

        // 2. Populate
        if jsonOffer == nil && iosProduct == nil {
            // Base offer but unavailable
            let jsonStorePrice = jsonBase["StorePrices"] as? [[String: Any]]
            let storePrice = (jsonStorePrice?.count ?? 0) > 0 ? StorePrice.parse(jsonStorePrice![0]) : nil

            priceMillis = storePrice?.priceMillis ?? 0
            currencyCode = storePrice?.currency ?? ""

            priceFormatted = formatPrice(priceMillis, currencyCode: currencyCode)

            periodCount = jsonBase["subscriptionPeriodCount"] as! Int
            periodUnit = jsonBase["subscriptionPeriodUnit"] as! String
            countBillingCycle = 0
        } else if (jsonOffer != nil && iosOffer == nil) || status == ProductStatus.INVALID {
            // Promotionnal offer but unavailable
            let jsonStorePrice = jsonOffer!["StorePrices"] as? [[String: Any]]
            let storePrice = (jsonStorePrice?.count ?? 0) > 0 ? StorePrice.parse(jsonStorePrice![0]) : nil

            priceMillis = storePrice?.priceMillis ?? 0
            currencyCode = storePrice?.currency ?? ""

            priceFormatted = formatPrice(priceMillis, currencyCode: currencyCode)

            if type == "free_trial" {
                periodCount = jsonOffer!["offerPeriodCount"] as! Int
                periodUnit = jsonOffer!["offerPeriodUnit"] as! String
                countBillingCycle = 1
            } else {
                countBillingCycle = jsonOffer!["offerCountBillingCycle"] as! Int

                // Inherit from baseOffer
                periodCount = jsonBase["subscriptionPeriodCount"] as! Int
                periodUnit = jsonBase["subscriptionPeriodUnit"] as! String
            }
        } else {
            status = ProductStatus.AVAILABLE
            currencyCode = iosProduct!.priceFormatStyle.currencyCode

            if iosOffer != nil {
                // Real offer
                if type == "free_trial" {
                    if !(await iosProduct!.subscription!.isEligibleForIntroOffer) {
                        status = ProductStatus.UNAVAILABLE
                    }
                }

                priceMillis = NSDecimalNumber(decimal: iosOffer!.price * 1000.0).intValue
                priceFormatted = iosOffer!.displayPrice

                let parsedPeriod = try! PeriodUnit.parseSubscriptionPeriod(iosOffer!.period)
                periodCount = parsedPeriod.count
                periodUnit = parsedPeriod.unit
                countBillingCycle = iosOffer!.periodCount
            } else {
                // Base offer, use iosProduct
                priceMillis = NSDecimalNumber(decimal: iosProduct!.price * 1000.0).intValue
                priceFormatted = iosProduct!.displayPrice

                let parsedPeriod = try! PeriodUnit.parseSubscriptionPeriod(iosProduct!.subscription!.subscriptionPeriod)
                periodCount = parsedPeriod.count
                periodUnit = parsedPeriod.unit
                countBillingCycle = 0
            }
        }

        return MobilySubscriptionOffer(
            id: id,
            identifier: identifier,
            externalRef: externalRef,
            referenceName: referenceName,
            name: name,
            priceMillis: priceMillis,
            currencyCode: currencyCode,
            priceFormatted: priceFormatted,
            type: type,
            periodCount: periodCount,
            periodUnit: periodUnit,
            countBillingCycle: countBillingCycle,
            ios_offerId: ios_offerId,
            extras: extras,
            status: status
        )
    }
}
