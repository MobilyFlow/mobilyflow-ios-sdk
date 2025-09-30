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
    public let isDowngrade: Bool
    
    init(product: Product, isDowngrade: Bool, options: Set<Product.PurchaseOption>) {
        self.product = product
        self.isDowngrade = isDowngrade
        self.options = options
        self.redeemUrl = nil
    }
    
    init(redeemUrl: URL, isDowngrade: Bool) {
        self.product = nil
        self.isDowngrade = isDowngrade
        self.options = nil
        self.redeemUrl = redeemUrl
    }
    
    func isRedeemURL() -> Bool {
        return self.redeemUrl != nil
    }
    
    func getReeemUrl() -> URL {
        return self.redeemUrl!
    }
    
    func getPurchaseOptions() -> (Product, Set<Product.PurchaseOption>) {
        return (self.product!, self.options!)
    }
}
