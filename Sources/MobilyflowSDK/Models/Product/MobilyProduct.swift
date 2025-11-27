//
//  MobilyProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

@objc public class MobilyProduct: Serializable {
    @objc public let id: UUID
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let identifier: String
    @objc public let referenceName: String
    @objc public let externalRef: String?

    @objc public let android_sku: String?
    @objc public let android_basePlanId: String?
    @objc public let ios_sku: String

    @objc public let type: String
    @objc public let extras: [String: Any]?

    @objc public let priceMillis: Int
    @objc public let currencyCode: String
    @objc public let priceFormatted: String
    @objc public let status: String

    @objc public let name: String
    @objc public let details: String

    @objc public let oneTime: MobilyOneTimeProduct?
    @objc public let subscription: MobilySubscriptionProduct?

    @objc public class MobilyOneTimeProduct: Serializable {
        @objc public let isConsumable: Bool
        @objc public let isMultiQuantity: Bool
        @objc public let ios_isNonRenewableSub: Bool

        @objc init(isConsumable: Bool, isMultiQuantity: Bool, ios_isNonRenewableSub: Bool) {
            self.isConsumable = isConsumable
            self.isMultiQuantity = isMultiQuantity
            self.ios_isNonRenewableSub = ios_isNonRenewableSub
            super.init()
        }
    }

    @objc public class MobilySubscriptionProduct: Serializable {
        @objc public let periodCount: Int
        @objc public let periodUnit: String
        @objc public let groupLevel: Int
        @objc public let groupId: String
        @objc public let ios_groupId: String?

        @objc public let introductoryOffer: MobilySubscriptionOffer?
        @objc public let promotionalOffers: [MobilySubscriptionOffer]

        @objc init(periodCount: Int, periodUnit: String, groupLevel: Int, groupId: String, ios_groupId: String?, introductoryOffer: MobilySubscriptionOffer?, promotionalOffers: [MobilySubscriptionOffer]) {
            self.periodCount = periodCount
            self.periodUnit = PeriodUnit.parse(periodUnit)
            self.groupLevel = groupLevel
            self.groupId = groupId
            self.ios_groupId = ios_groupId
            self.introductoryOffer = introductoryOffer
            self.promotionalOffers = promotionalOffers
            super.init()
        }
    }

    @objc init(
        id: UUID, createdAt: Date, updatedAt: Date, identifier: String, referenceName: String, externalRef: String?, android_sku: String?, android_basePlanId: String?, ios_sku: String, type: String, extras: [String: Any]?, priceMillis: Int, currencyCode: String, priceFormatted: String, status: String, name: String, details: String, oneTime: MobilyOneTimeProduct?, subscription: MobilySubscriptionProduct?,
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.identifier = identifier
        self.referenceName = referenceName
        self.externalRef = externalRef
        self.android_sku = android_sku
        self.android_basePlanId = android_basePlanId
        self.ios_sku = ios_sku
        self.type = MobilyProductType.parse(type)
        self.extras = extras
        self.priceMillis = priceMillis
        self.currencyCode = currencyCode
        self.priceFormatted = priceFormatted
        self.status = MobilyProductStatus.parse(status)
        self.name = name
        self.details = details
        self.oneTime = oneTime
        self.subscription = subscription
        super.init()
    }

    static func parse(_ jsonProduct: [String: Any]) async -> MobilyProduct {
        let ios_sku = jsonProduct["ios_sku"] as! String
        let type = jsonProduct["type"] as! String

        var status: String
        var priceMillis = 0
        var currencyCode = ""
        var priceFormatted = ""

        var oneTime: MobilyOneTimeProduct? = nil
        var subscription: MobilySubscriptionProduct? = nil

        let iosProduct = MobilyPurchaseRegistry.getIOSProduct(ios_sku)

        if type == MobilyProductType.ONE_TIME {
            if iosProduct == nil || iosProduct?.subscription != nil {
                status = iosProduct == nil ? MobilyProductStatus.UNAVAILABLE : MobilyProductStatus.INVALID
            } else {
                status = MobilyProductStatus.AVAILABLE
                priceMillis = NSDecimalNumber(decimal: iosProduct!.price * 1000.0).intValue
                currencyCode = iosProduct!.priceFormatStyle.currencyCode
                priceFormatted = iosProduct!.displayPrice
            }

            oneTime = MobilyOneTimeProduct(
                isConsumable: jsonProduct["isConsumable"] as! Bool,
                isMultiQuantity: jsonProduct["isMultiQuantity"] as! Bool,
                ios_isNonRenewableSub: jsonProduct["ios_isNonRenewableSub"] as! Bool,
            )
        } else {
            var periodCount: Int
            var periodUnit: String
            var introductoryOffer: MobilySubscriptionOffer? = nil
            var promotionalOffers: [MobilySubscriptionOffer] = []

            if iosProduct != nil {
                status = MobilyProductStatus.AVAILABLE

                // Base offer, use iosProduct
                priceMillis = NSDecimalNumber(decimal: iosProduct!.price * 1000.0).intValue
                currencyCode = iosProduct!.priceFormatStyle.currencyCode
                priceFormatted = iosProduct!.displayPrice

                let parsedPeriod = try! PeriodUnit.parseSubscriptionPeriod(iosProduct!.subscription!.subscriptionPeriod)
                periodCount = parsedPeriod.count
                periodUnit = parsedPeriod.unit
            } else {
                status = MobilyProductStatus.UNAVAILABLE
                periodUnit = jsonProduct["subscriptionPeriodUnit"] as! String
                periodCount = jsonProduct["subscriptionPeriodCount"] as! Int
            }

            let jsonOffers = jsonProduct["Offers"] as? [[String: Any]] ?? []

            for jsonOffer in jsonOffers {
                let offer = await MobilySubscriptionOffer.parse(jsonProduct: jsonProduct, jsonOffer: jsonOffer, iosProduct: iosProduct)

                if offer.type == MobilyProductOfferType.INTRODUCTORY {
                    if introductoryOffer != nil {
                        Logger.w("Offer \(iosProduct!.id)/\(offer.ios_offerId ?? "nil") is incompatible with MobilyFlow (too many INTRODUCTORY offers)")
                        continue
                    }
                    introductoryOffer = offer
                } else {
                    promotionalOffers.append(offer)
                }
            }

            if introductoryOffer != nil && introductoryOffer?.status != MobilyProductStatus.AVAILABLE {
                // Remove UNAVAILABLE introductoryOffer
                introductoryOffer = nil
            }

            subscription = MobilySubscriptionProduct(
                periodCount: periodCount,
                periodUnit: periodUnit,
                groupLevel: jsonProduct["subscriptionGroupLevel"] as! Int,
                groupId: jsonProduct["subscriptionGroupId"] as! String,
                ios_groupId: iosProduct?.subscription?.subscriptionGroupID,
                introductoryOffer: introductoryOffer,
                promotionalOffers: promotionalOffers,
            )
        }

        if status != MobilyProductStatus.AVAILABLE {
            let jsonStorePrice = jsonProduct["StorePrices"] as? [[String: Any]]
            let storePrice = (jsonStorePrice?.count ?? 0) > 0 ? StorePrice.parse(jsonStorePrice![0]) : nil

            priceMillis = storePrice?.priceMillis ?? 0
            currencyCode = storePrice?.currency ?? ""
            priceFormatted = formatPrice(priceMillis, currencyCode: currencyCode)
        }

        let product = MobilyProduct(
            id: parseUUID(jsonProduct["id"] as? String)!,
            createdAt: parseDate(jsonProduct["createdAt"] as! String),
            updatedAt: parseDate(jsonProduct["updatedAt"] as! String),
            identifier: jsonProduct["identifier"] as! String,
            referenceName: jsonProduct["referenceName"] as! String,
            externalRef: jsonProduct["externalRef"] as? String,
            android_sku: jsonProduct["android_sku"] as? String,
            android_basePlanId: jsonProduct["android_basePlanId"] as? String,
            ios_sku: ios_sku,
            type: type,
            extras: jsonProduct["extras"] as! [String: Any]?,
            priceMillis: priceMillis,
            currencyCode: currencyCode,
            priceFormatted: priceFormatted,
            status: status,
            name: getTranslationValue(jsonProduct["_translations"] as? [[String: Any]], field: "name") ?? "",
            details: getTranslationValue(jsonProduct["_translations"] as? [[String: Any]], field: "description") ?? "",
            oneTime: oneTime,
            subscription: subscription,
        )

        return product
    }
}
