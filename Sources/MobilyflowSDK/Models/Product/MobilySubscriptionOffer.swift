//
//  MobilySubscriptionOffer.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 05/11/2024.
//

import Foundation
import StoreKit

@objc public class MobilySubscriptionOffer: Serializable {
    @objc public let id: UUID
    @objc public let identifier: String
    @objc public let externalRef: String?
    @objc public let referenceName: String
    @objc public let priceMillis: Int
    @objc public let currencyCode: String
    @objc public let priceFormatted: String
    @objc public let type: String
    @objc public let periodCount: Int
    @objc public let periodUnit: String
    @objc public let countBillingCycle: Int
    @objc public let android_offerId: String?
    @objc public let ios_offerId: String?
    @objc public let extras: [String: Any]?
    @objc public let status: String
    @objc public let name: String?

    @objc init(id: UUID, identifier: String, externalRef: String?, referenceName: String, priceMillis: Int, currencyCode: String, priceFormatted: String, type: String, periodCount: Int, periodUnit: String, countBillingCycle: Int, android_offerId: String?, ios_offerId: String?, extras: [String: Any]? = nil, status: String, name: String) {
        self.id = id
        self.identifier = identifier
        self.externalRef = externalRef
        self.referenceName = referenceName
        self.priceMillis = priceMillis
        self.currencyCode = currencyCode
        self.priceFormatted = priceFormatted
        self.type = MobilyProductOfferType.parse(type)
        self.periodCount = periodCount
        self.periodUnit = PeriodUnit.parse(periodUnit)
        self.countBillingCycle = countBillingCycle
        self.android_offerId = android_offerId
        self.ios_offerId = ios_offerId
        self.extras = extras
        self.status = status
        self.name = name
        super.init()
    }

    static func parse(jsonProduct: [String: Any], jsonOffer: [String: Any], iosProduct: Product?) async -> MobilySubscriptionOffer {
        let priceMillis: Int
        let currencyCode: String
        let priceFormatted: String
        let periodCount: Int
        let periodUnit: String
        let countBillingCycle: Int
        var status = MobilyProductStatus.UNAVAILABLE

        var iosOffer: Product.SubscriptionOffer?

        let id = parseUUID(jsonOffer["id"] as! String)!
        let identifier = jsonOffer["identifier"] as! String
        let externalRef = jsonOffer["externalRef"] as? String
        let referenceName = jsonOffer["referenceName"] as! String
        let extras = jsonOffer["extras"] as? [String: Any]
        let type = jsonOffer["type"] as! String
        let ios_offerId = jsonOffer["ios_offerId"] as? String
        let name = getTranslationValue(jsonOffer["_translations"] as? [[String: Any]], field: "name") ?? ""

        if iosProduct != nil {
            if type == MobilyProductOfferType.FREE_TRIAL {
                iosOffer = iosProduct!.subscription!.introductoryOffer
            } else if ios_offerId != nil {
                iosOffer = MobilyPurchaseRegistry.getIOSOffer(iosProduct!.id, offerId: ios_offerId!)
            }
        }

        // 1. Validate offer
        if iosOffer != nil {
            if iosOffer?.paymentMode == .payUpFront {
                Logger.w("Pay Up Front is not supported for subscription offers (ios offer \(iosOffer?.id ?? "nil"))")
                status = MobilyProductStatus.INVALID
            }
        }

        // 2. Populate
        if iosOffer == nil || status == MobilyProductStatus.INVALID {
            // Promotionnal offer but unavailable
            let jsonStorePrice = jsonOffer["StorePrices"] as? [[String: Any]]
            let storePrice = (jsonStorePrice?.count ?? 0) > 0 ? StorePrice.parse(jsonStorePrice![0]) : nil

            priceMillis = storePrice?.priceMillis ?? 0
            currencyCode = storePrice?.currency ?? ""

            priceFormatted = formatPrice(priceMillis, currencyCode: currencyCode)

            if type == MobilyProductOfferType.FREE_TRIAL {
                periodCount = jsonOffer["offerPeriodCount"] as! Int
                periodUnit = jsonOffer["offerPeriodUnit"] as! String
                countBillingCycle = 1
            } else {
                countBillingCycle = jsonOffer["offerCountBillingCycle"] as! Int

                // Inherit from product
                periodCount = jsonProduct["subscriptionPeriodCount"] as! Int
                periodUnit = jsonProduct["subscriptionPeriodUnit"] as! String
            }
        } else {
            status = MobilyProductStatus.AVAILABLE
            currencyCode = iosProduct!.priceFormatStyle.currencyCode

            if type == MobilyProductOfferType.FREE_TRIAL {
                if !(await iosProduct!.subscription!.isEligibleForIntroOffer) {
                    status = MobilyProductStatus.UNAVAILABLE
                }
            }

            priceMillis = NSDecimalNumber(decimal: iosOffer!.price * 1000.0).intValue
            priceFormatted = iosOffer!.displayPrice

            let parsedPeriod = try! PeriodUnit.parseSubscriptionPeriod(iosOffer!.period)
            periodCount = parsedPeriod.count
            periodUnit = parsedPeriod.unit
            countBillingCycle = iosOffer!.periodCount
        }

        return MobilySubscriptionOffer(
            id: id,
            identifier: identifier,
            externalRef: externalRef,
            referenceName: referenceName,
            priceMillis: priceMillis,
            currencyCode: currencyCode,
            priceFormatted: priceFormatted,
            type: type,
            periodCount: periodCount,
            periodUnit: periodUnit,
            countBillingCycle: countBillingCycle,
            android_offerId: jsonOffer["android_offerId"] as? String,
            ios_offerId: ios_offerId,
            extras: extras,
            status: status,
            name: name
        )
    }
}
