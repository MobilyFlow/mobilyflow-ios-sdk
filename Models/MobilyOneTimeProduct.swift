//
//  MobilyOneTimeProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 05/11/2024.
//

import Foundation
import StoreKit

class MobilyOneTimeProduct {
    public let price: Decimal
    public let currencyCode: String
    public let priceFormatted: String
    public let isConsumable: Bool
    public let isNonRenewableSub: Bool
    public let isMultiQuantity: Bool
    public let status: ProductStatus

    init(price: Decimal, currencyCode: String, priceFormatted: String, isConsumable: Bool, isNonRenewableSub: Bool, isMultiQuantity: Bool, status: ProductStatus) {
        self.price = price
        self.currencyCode = currencyCode
        self.priceFormatted = priceFormatted
        self.isConsumable = isConsumable
        self.isNonRenewableSub = isNonRenewableSub
        self.isMultiQuantity = isMultiQuantity
        self.status = status
    }

    static func parse(jsonProduct: [String: Any]) -> MobilyOneTimeProduct {
        let price: Decimal
        let currencyCode: String
        let priceFormatted: String
        let status: ProductStatus

        let iosProduct = MobilyPurchaseRegistry.getIOSProduct(jsonProduct["ios_sku"]! as! String)

        if iosProduct == nil || iosProduct?.subscription != nil {
            status = iosProduct == nil ? .unavailable : .invalid
            price = Decimal(floatLiteral: coalesce(jsonProduct["defaultPrice"], 0.0) as! Double)
            currencyCode = coalesce(jsonProduct["defaultCurrencyCode"], "") as! String
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
