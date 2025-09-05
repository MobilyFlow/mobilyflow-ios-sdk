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

    init(priceMillis: Int, currency: String, regionCode: String) {
        self.priceMillis = priceMillis
        self.currency = currency
        self.regionCode = regionCode
    }

    static func parse(_ storePrice: [String: Any]) -> StorePrice {
        return StorePrice(
            priceMillis: storePrice["priceMillis"] as! Int,
            currency: storePrice["currency"] as! String,
            regionCode: storePrice["regionCode"] as! String
        )
    }

    static func getDefaultPrice(_ storePrices: [[String: Any]], currentRegion: String?) -> StorePrice? {
        let currentRegionPrice = storePrices.first { $0["regionCode"] as? String == currentRegion }
        if currentRegionPrice != nil {
            return StorePrice.parse(currentRegionPrice!)
        }

        let defaultStorePrice = storePrices.first {
            ($0["isDefault"] as? Bool ?? false) && ($0["platform"] as? String == nil || $0["platform"] as? String == "ios")
        }

        if defaultStorePrice != nil {
            return StorePrice.parse(defaultStorePrice!)
        }

        let firstStorePrice = storePrices.first
        if firstStorePrice != nil {
            return StorePrice.parse(firstStorePrice!)
        }

        return nil
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
