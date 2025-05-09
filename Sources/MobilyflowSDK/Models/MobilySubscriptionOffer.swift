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
    @objc public let name: String?
    @objc public let price: Decimal
    @objc public let currencyCode: String
    @objc public let priceFormatted: String
    @objc public let type: String?
    @objc public let periodCount: Int // For freeTrial only
    @objc public let periodUnit: PeriodUnit // For freeTrial only
    @objc public let countBillingCycle: Int // For recurring only
    @objc public let ios_offerId: String? // null for base offer
    @objc public let extras: [String: Any]?
    @objc public let status: ProductStatus

    @objc init(id: String?, identifier: String?, externalRef: String?, name: String?, price: Decimal, currencyCode: String, priceFormatted: String, type: String?, periodCount: Int, periodUnit: PeriodUnit, countBillingCycle: Int, ios_offerId: String?, extras: [String: Any]? = nil, status: ProductStatus) {
        self.id = id
        self.identifier = identifier
        self.externalRef = externalRef
        self.name = name
        self.price = price
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

    static func parse(jsonOffer: [String: Any], iosProduct: Product?, isBaseOffer: Bool) async -> MobilySubscriptionOffer {
        var id: String? = nil
        var identifier: String? = nil
        var externalRef: String? = nil
        var name: String? = nil
        let price: Decimal
        let currencyCode: String
        let priceFormatted: String
        var type = "recurring"
        let periodCount: Int
        let periodUnit: PeriodUnit
        let countBillingCycle: Int
        var ios_offerId: String? = nil
        var extras: [String: Any]? = nil
        var status: ProductStatus = .unavailable

        var iosOffer: Product.SubscriptionOffer?

        if !isBaseOffer {
            id = jsonOffer["id"] as? String
            identifier = jsonOffer["identifier"] as? String
            externalRef = jsonOffer["externalRef"] as? String
            name = jsonOffer["name"] as? String
            extras = jsonOffer["extras"] as? [String: Any]
            type = jsonOffer["type"] as! String
            ios_offerId = jsonOffer["ios_offerId"] as? String

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
                NSLog("Warning: Pay Up Front is not supported for subscription offers")
                status = .invalid
            }
        }

        // 2. Populate
        if (isBaseOffer && iosProduct == nil) || (!isBaseOffer && iosOffer == nil) || status == .invalid {
            price = Decimal(floatLiteral: coalesce(jsonOffer["defaultPrice"], 0.0) as! Double)
            currencyCode = coalesce(jsonOffer["defaultCurrencyCode"], "") as! String
            priceFormatted = formatPrice(price, currencyCode: currencyCode)

            // If isBaseOffer, jsonOffer is the jsonProduct
            if isBaseOffer {
                periodCount = jsonOffer["subscriptionPeriodCount"] as! Int
                periodUnit = PeriodUnit.parse(jsonOffer["subscriptionPeriodUnit"] as! String)!
                countBillingCycle = 0
            } else if type == "free_trial" {
                periodCount = jsonOffer["offerPeriodCount"] as! Int
                periodUnit = PeriodUnit.parse(jsonOffer["offerPeriodUnit"] as! String)!
                countBillingCycle = 0
            } else {
                // TODO: inherit from basePlan
                periodCount = 0
                periodUnit = PeriodUnit.week
                countBillingCycle = jsonOffer["offerCountBillingCycle"] as! Int
            }
        } else {
            status = .available
            currencyCode = iosProduct!.priceFormatStyle.currencyCode

            if iosOffer != nil {
                // Real offer
                if type == "free_trial" {
                    if !(await iosProduct!.subscription!.isEligibleForIntroOffer) {
                        status = .unavailable
                    }
                }

                price = iosOffer!.price
                priceFormatted = iosOffer!.displayPrice

                let parsedPeriod = try! PeriodUnit.parseSubscriptionPeriod(iosOffer!.period)
                periodCount = parsedPeriod.count
                periodUnit = parsedPeriod.unit
                countBillingCycle = iosOffer!.periodCount
            } else {
                // Base offer, use iosProduct
                price = iosProduct!.price
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
            name: name,
            price: price,
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
