//
//  MobilyOneTimeProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 05/11/2024.
//

import Foundation
import StoreKit

@objc public class MobilyOneTimeProduct: Serializable {
    @objc public let priceMillis: Int
    @objc public let currencyCode: String
    @objc public let priceFormatted: String
    @objc public let isConsumable: Bool
    @objc public let isNonRenewableSub: Bool
    @objc public let isMultiQuantity: Bool
    @objc public let status: String

    @objc init(priceMillis: Int, currencyCode: String, priceFormatted: String, isConsumable: Bool, isNonRenewableSub: Bool, isMultiQuantity: Bool, status: String) {
        self.priceMillis = priceMillis
        self.currencyCode = currencyCode
        self.priceFormatted = priceFormatted
        self.isConsumable = isConsumable
        self.isNonRenewableSub = isNonRenewableSub
        self.isMultiQuantity = isMultiQuantity
        self.status = status

        super.init()
    }

    static func parse(jsonProduct: [String: Any]) -> MobilyOneTimeProduct {
        let priceMillis: Int
        let currencyCode: String
        let priceFormatted: String
        let status: String

        let iosProduct = MobilyPurchaseRegistry.getIOSProduct(jsonProduct["ios_sku"]! as! String)

        if iosProduct == nil || iosProduct?.subscription != nil {
            status = iosProduct == nil ? ProductStatus.UNAVAILABLE : ProductStatus.INVALID

            let jsonStorePrice = jsonProduct["StorePrices"] as? [[String: Any]]
            let storePrice = (jsonStorePrice?.count ?? 0) > 0 ? StorePrice.parse(jsonStorePrice![0]) : nil

            priceMillis = storePrice?.priceMillis ?? 0
            currencyCode = storePrice?.currency ?? ""

            priceFormatted = formatPrice(priceMillis, currencyCode: currencyCode)
        } else {
            status = ProductStatus.AVAILABLE
            priceMillis = NSDecimalNumber(decimal: iosProduct!.price * 1000.0).intValue
            currencyCode = iosProduct!.priceFormatStyle.currencyCode
            priceFormatted = iosProduct!.displayPrice
        }

        return MobilyOneTimeProduct(
            priceMillis: priceMillis,
            currencyCode: currencyCode,
            priceFormatted: priceFormatted,
            isConsumable: jsonProduct["isConsumable"]! as! Bool,
            isNonRenewableSub: jsonProduct["ios_isNonRenewableSub"]! as! Bool,
            isMultiQuantity: jsonProduct["isMultiQuantity"]! as! Bool,
            status: status
        )
    }
}
