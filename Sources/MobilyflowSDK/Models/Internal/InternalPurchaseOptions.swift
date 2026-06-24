//
//  InternalPurchaseOption.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 16/09/2025.
//

import StoreKit

class InternalPurchaseOptions {
    private let product: Product?
    private let options: Set<Product.PurchaseOption>?
    private let redeemUrl: URL?
    private let offerCode: String?
    let isDowngrade: Bool
    
    init(product: Product, isDowngrade: Bool, options: Set<Product.PurchaseOption>) {
        self.product = product
        self.isDowngrade = isDowngrade
        self.options = options
        self.offerCode = nil
        self.redeemUrl = nil
    }
    
    init(offerCode: String, redeemUrl: URL?, isDowngrade: Bool) {
        self.product = nil
        self.isDowngrade = isDowngrade
        self.options = nil
        self.offerCode = offerCode
        self.redeemUrl = redeemUrl
    }
    
    func isOfferCode() -> Bool {
        return self.offerCode != nil
    }
    
    func getRedeemUrl() -> URL? {
        return self.redeemUrl
    }
    
    func getOfferCode() -> String {
        return self.offerCode!
    }
    
    func getPurchaseOptions() -> (Product, Set<Product.PurchaseOption>) {
        return (self.product!, self.options!)
    }
}
