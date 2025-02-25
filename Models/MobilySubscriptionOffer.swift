//
//  MobilySubscriptionOffer.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 05/11/2024.
//

import Foundation
import StoreKit

public class MobilySubscriptionOffer {
    public let id: String?
    public let name: String?
    public let price: Decimal
    public let currencyCode: String
    public let priceFormatted: String
    public let isFreeTrial: Bool
    public let periodCount: Int
    public let periodUnit: PeriodUnit
    public let ios_offerId: String?
    public let extras: [String: Any]?
    public let status: ProductStatus

    init(id: String?, name: String?, price: Decimal, currencyCode: String, priceFormatted: String, isFreeTrial: Bool, periodCount: Int, periodUnit: PeriodUnit, ios_offerId: String?, extras: [String: Any]? = nil, status: ProductStatus) {
        self.id = id
        self.name = name
        self.price = price
        self.currencyCode = currencyCode
        self.priceFormatted = priceFormatted
        self.isFreeTrial = isFreeTrial
        self.periodCount = periodCount
        self.periodUnit = periodUnit
        self.ios_offerId = ios_offerId
        self.extras = extras
        self.status = status
    }

    static func parse(jsonOffer: [String: Any], iosProduct: Product?, isBaseOffer: Bool) async -> MobilySubscriptionOffer {
        var id: String? = nil
        var name: String? = nil
        let price: Decimal
        let currencyCode: String
        let priceFormatted: String
        var isFreeTrial = false
        let periodCount: Int
        let periodUnit: PeriodUnit
        var ios_offerId: String? = nil
        var extras: [String: Any]? = nil
        var status: ProductStatus = .unavailable

        var iosOffer: Product.SubscriptionOffer?

        if !isBaseOffer {
            id = jsonOffer["id"] as? String
            name = jsonOffer["name"] as? String
            extras = jsonOffer["extras"] as? [String: Any]
            isFreeTrial = jsonOffer["isFreeTrial"] as? Bool ?? false
            ios_offerId = jsonOffer["ios_offerId"] as? String

            if iosProduct != nil {
                if ios_offerId != nil {
                    iosOffer = MobilyPurchaseRegistry.getIOSOffer(iosProduct!.id, offerId: ios_offerId!)
                } else if isFreeTrial {
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
            price = jsonOffer["defaultPrice"] as! Decimal
            currencyCode = coalesce(jsonOffer["defaultCurrencyCode"], "") as! String
            priceFormatted = formatPrice(price, currencyCode: currencyCode)

            // If isBaseOffer, jsonOffer is the jsonProduct
            let periodPrefix = isBaseOffer ? "subscription" : "offer"
            periodCount = jsonOffer["\(periodPrefix)PeriodCount"] as! Int
            periodUnit = PeriodUnit(rawValue: jsonOffer["\(periodPrefix)PeriodUnit"] as! String)!
        } else {
            status = .available
            currencyCode = iosProduct!.priceFormatStyle.currencyCode

            if iosOffer != nil {
                // Real offer
                if isFreeTrial {
                    if !(await iosProduct!.subscription!.isEligibleForIntroOffer) {
                        status = .unavailable
                    }
                }

                price = iosOffer!.price
                priceFormatted = iosOffer!.displayPrice

                let parsedPeriod = try! PeriodUnit.parseSubscriptionPeriod(iosOffer!.period)
                periodCount = parsedPeriod.count
                periodUnit = parsedPeriod.unit
            } else {
                // Base offer, use iosProduct
                price = iosProduct!.price
                priceFormatted = iosProduct!.displayPrice

                let parsedPeriod = try! PeriodUnit.parseSubscriptionPeriod(iosProduct!.subscription!.subscriptionPeriod)
                periodCount = parsedPeriod.count
                periodUnit = parsedPeriod.unit
            }
        }

        return MobilySubscriptionOffer(
            id: id,
            name: name,
            price: price,
            currencyCode: currencyCode,
            priceFormatted: priceFormatted,
            isFreeTrial: isFreeTrial,
            periodCount: periodCount,
            periodUnit: periodUnit,
            ios_offerId: ios_offerId,
            extras: extras,
            status: status
        )
    }
}
