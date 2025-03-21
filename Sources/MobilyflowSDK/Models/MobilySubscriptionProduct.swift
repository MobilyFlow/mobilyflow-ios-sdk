//
//  MobilySubscriptionProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 05/11/2024.
//

import Foundation
import StoreKit

@objc public class MobilySubscriptionProduct: Serializable {
    @objc public let baseOffer: MobilySubscriptionOffer
    @objc public let freeTrial: MobilySubscriptionOffer?
    @objc public let promotionalOffers: [MobilySubscriptionOffer]
    @objc public let status: ProductStatus
    @objc public let groupLevel: Int
    @objc public let subscriptionGroupId: String?
    @objc public let subscriptionGroup: MobilySubscriptionGroup?

    @objc init(baseOffer: MobilySubscriptionOffer, freeTrial: MobilySubscriptionOffer? = nil, promotionalOffers: [MobilySubscriptionOffer], status: ProductStatus, groupLevel: Int, subscriptionGroupId: String?, subscriptionGroup: MobilySubscriptionGroup?) {
        self.baseOffer = baseOffer
        self.freeTrial = freeTrial
        self.promotionalOffers = promotionalOffers
        self.status = status
        self.groupLevel = groupLevel
        self.subscriptionGroupId = subscriptionGroupId
        self.subscriptionGroup = subscriptionGroup

        super.init()
    }

    static func parse(jsonProduct: [String: Any]) async -> MobilySubscriptionProduct {
        var freeTrial: MobilySubscriptionOffer? = nil
        var promotionalOffers: [MobilySubscriptionOffer] = []
        var subscriptionGroup: MobilySubscriptionGroup? = nil

        let iosProduct = MobilyPurchaseRegistry.getIOSProduct(jsonProduct["ios_sku"]! as! String)
        let baseOffer = await MobilySubscriptionOffer.parse(jsonOffer: jsonProduct, iosProduct: iosProduct, isBaseOffer: true)

        // TODO: This means no offer are returned at all if the ios product is not available
        if iosProduct?.subscription != nil {
            let jsonOffers = jsonProduct["Offers"] as? [[String: Any]] ?? []

            for jsonOffer in jsonOffers {
                let offer = await MobilySubscriptionOffer.parse(jsonOffer: jsonOffer, iosProduct: iosProduct, isBaseOffer: false)

                if offer.isFreeTrial {
                    if freeTrial != nil {
                        Logger.w("Offer \(iosProduct!.id)/\(offer.ios_offerId ?? "nil") is incompatible with MobilyFlow (too many free trials)")
                        continue
                    }
                    freeTrial = offer
                } else {
                    promotionalOffers.append(offer)
                }
            }
        }

        let subscriptionGroupJson = jsonProduct["SubscriptionGroup"] as? [String: Any]
        if subscriptionGroupJson != nil {
            subscriptionGroup = MobilySubscriptionGroup.parse(jsonGroup: subscriptionGroupJson!)
        }

        let subscriptionGroupLevel: Int
        if #available(iOS 16.4, *), iosProduct != nil {
            subscriptionGroupLevel = iosProduct!.subscription!.groupLevel
        } else {
            subscriptionGroupLevel = jsonProduct["subscriptionGroupLevel"]! as! Int
        }

        let subscription = MobilySubscriptionProduct(
            baseOffer: baseOffer,
            freeTrial: freeTrial,
            promotionalOffers: promotionalOffers,
            status: baseOffer.status,
            groupLevel: subscriptionGroupLevel,
            subscriptionGroupId: jsonProduct["subscriptionGroupId"]! as? String,
            subscriptionGroup: subscriptionGroup
        )

        return subscription
    }
}
