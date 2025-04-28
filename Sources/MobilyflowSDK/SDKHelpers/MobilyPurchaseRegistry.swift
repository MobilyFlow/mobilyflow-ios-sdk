//
//  MobilyPurchaseRegistry.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import StoreKit

class MobilyPurchaseRegistry {
    private static var skuToProduct: [String: ProductRegistryItem] = [:]

    private init() {}

    private struct ProductRegistryItem {
        let product: Product
        let offers: [String: Product.SubscriptionOffer]?
    }

    static func registerIOSProductSkus(_ skus: [String]) async {
        let unknownSkus: [String] = skus.filter { skuToProduct[$0] == nil }

        if !unknownSkus.isEmpty {
            guard let storeProducts = try? await Product.products(for: unknownSkus) else {
                return
            }
            registerIOSProducts(storeProducts)
        }
    }

    static func registerIOSProducts(_ products: [Product]) {
        for product in products {
            registerIOSProduct(product)
        }
    }

    static func registerIOSProduct(_ product: Product) {
        var offers: [String: Product.SubscriptionOffer]?

        if product.type == .autoRenewable {
            offers = [:]
            for offer in product.subscription!.promotionalOffers {
                offers![offer.id!] = offer
            }
        }

        skuToProduct[product.id] = ProductRegistryItem(product: product, offers: offers)
    }

    static func getIOSProduct(_ sku: String) -> Product? {
        return skuToProduct[sku]?.product
    }

    static func getIOSOffer(_ sku: String, offerId: String) -> Product.SubscriptionOffer? {
        return skuToProduct[sku]?.offers?[offerId]
    }
}
