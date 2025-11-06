//
//  StorePrice.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 04/09/2025.
//

import StoreKit

class StorePrice {
    let priceMillis: Int
    let currency: String
    let regionCode: String
    let platform: String

    init(priceMillis: Int, currency: String, regionCode: String, platform: String) {
        self.priceMillis = priceMillis
        self.currency = currency
        self.regionCode = regionCode
        self.platform = platform
    }

    static func parse(_ storePrice: [String: Any]) -> StorePrice {
        return StorePrice(
            priceMillis: storePrice["priceMillis"] as! Int,
            currency: storePrice["currency"] as! String,
            regionCode: storePrice["regionCode"] as! String,
            platform: storePrice["platform"] as! String
        )
    }

    static func getMostRelevantRegion() async -> String? {
        if let alpha3 = (await Storefront.current)?.countryCode {
            return CountryCodes.alpha3ToAlpha2(alpha3)
        }

        if #available(iOS 16.0, *) {
            return NSLocale.current.region?.identifier
        } else {
            return NSLocale.current.regionCode
        }

        return nil
    }
}
