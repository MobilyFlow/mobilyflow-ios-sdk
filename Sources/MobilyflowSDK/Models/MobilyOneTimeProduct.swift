//
//  MobilyOneTimeProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 05/11/2024.
//

import Foundation
import StoreKit

@objc public class MobilyOneTimeProduct: Serializable {
    @objc public let price: Decimal
    @objc public let currencyCode: String
    @objc public let priceFormatted: String
    @objc public let isConsumable: Bool
    @objc public let isNonRenewableSub: Bool
    @objc public let isMultiQuantity: Bool
    @objc public let status: ProductStatus

    @objc init(price: Decimal, currencyCode: String, priceFormatted: String, isConsumable: Bool, isNonRenewableSub: Bool, isMultiQuantity: Bool, status: ProductStatus) {
        self.price = price
        self.currencyCode = currencyCode
        self.priceFormatted = priceFormatted
        self.isConsumable = isConsumable
        self.isNonRenewableSub = isNonRenewableSub
        self.isMultiQuantity = isMultiQuantity
        self.status = status

        super.init()
    }

    static func parse(jsonProduct: [String: Any], currentRegion: String?) -> MobilyOneTimeProduct {
        let price: Decimal
        let currencyCode: String
        let priceFormatted: String
        let status: ProductStatus

        let iosProduct = MobilyPurchaseRegistry.getIOSProduct(jsonProduct["ios_sku"]! as! String)

        if iosProduct == nil || iosProduct?.subscription != nil {
            status = iosProduct == nil ? .unavailable : .invalid

            let storePrice = StorePrice.getDefaultPrice(jsonProduct["StorePrices"] as! [[String: Any]], currentRegion: currentRegion)
            if storePrice == nil {
                price = Decimal(floatLiteral: 0.0)
                currencyCode = ""
            } else {
                price = Decimal(floatLiteral: Double(storePrice!.priceMillis) / 1000.0)
                currencyCode = storePrice!.currency
            }

            priceFormatted = formatPrice(price, currencyCode: currencyCode)
        } else {
            status = .available
            price = iosProduct!.price
            currencyCode = iosProduct!.priceFormatStyle.currencyCode
            priceFormatted = iosProduct!.displayPrice
        }

        return MobilyOneTimeProduct(
            price: price,
            currencyCode: currencyCode,
            priceFormatted: priceFormatted,
            isConsumable: jsonProduct["isConsumable"]! as! Bool,
            isNonRenewableSub: jsonProduct["ios_isNonRenewableSub"]! as! Bool,
            isMultiQuantity: jsonProduct["isMultiQuantity"]! as! Bool,
            status: status
        )
    }
}
