//
//  MobilyPurchaseSDKSyncer.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import Foundation
import StoreKit

class MobilyPurchaseSDKSyncer {
    private let API: MobilyPurchaseAPI
    private var customerId: UUID?

    private let CACHE_DURATION_SEC = 3600.0

    private var products: [MobilyProduct]?
    private var subscriptionGroups: [MobilySubscriptionGroup]?
    private var entitlements: [MobilyCustomerEntitlement]?
    private var storeAccountTransactions: [UInt64: Transaction]? // originalTxId -> Transaction

    private var lastProductFetchTime: Double?
    private let syncExecutor = AsyncDispatchQueue(label: "mobilyflow-sync")

    init(API: MobilyPurchaseAPI) {
        self.API = API
    }

    func login(customerId: UUID?) {
        syncExecutor.sync {
            self.customerId = customerId
            self.entitlements = nil
            self.lastProductFetchTime = nil
        }
    }

    func close() {
        syncExecutor.sync {
            self.customerId = nil
            self.entitlements = nil
        }
        syncExecutor.cancel()
    }

    func ensureSync(force: Bool = false) async throws {
        try await syncExecutor.execute {
            if
                force ||
                self.lastProductFetchTime == nil ||
                (self.lastProductFetchTime! + self.CACHE_DURATION_SEC) < Date().timeIntervalSince1970
            {
                self.lastProductFetchTime = Date().timeIntervalSince1970
                Logger.d("Run Sync")
                try await self._syncProduct()
                try await self._syncEntitlements()
            }
        }
    }

    private func _syncProduct() async throws {
        // 1. Get product from Mobily API
        let jsonProducts = try await self.API.getProducts(identifiers: nil)

        // 2. Get product from App Store
        let iosIdentifiers = jsonProducts.map { p in p["ios_sku"]! } as! [String]
        guard let storeProducts = try? await Product.products(for: iosIdentifiers) else {
            throw MobilyError.store_unavailable
        }
        MobilyPurchaseRegistry.registerIOSProducts(storeProducts)

        // 3. Parse to MobilyProduct
        var mobilyProducts: [MobilyProduct] = []
        var subscriptionGroupMap: [String: MobilySubscriptionGroup] = [:]

        for jsonProduct in jsonProducts {
            let mobilyProduct = await MobilyProduct.parse(jsonProduct: jsonProduct)
            mobilyProducts.append(mobilyProduct)

            if mobilyProduct.subscriptionProduct?.subscriptionGroup != nil {
                subscriptionGroupMap[mobilyProduct.subscriptionProduct!.subscriptionGroupId!] = mobilyProduct.subscriptionProduct!.subscriptionGroup!
            }
        }

        products = mobilyProducts
        subscriptionGroups = Array(subscriptionGroupMap.values)
    }

    private func _syncStoreAccountTransactions() async throws {
        var storeAccountTransactions: [UInt64: Transaction] = [:]

        for await signedTx in Transaction.currentEntitlements {
            switch signedTx {
            case .verified(let transaction):
                storeAccountTransactions[transaction.originalID] = transaction
            case .unverified:
                break
            }
        }

        self.storeAccountTransactions = storeAccountTransactions
    }

    private func _syncEntitlements() async throws {
        if customerId == nil {
            return
        }

        try await _syncStoreAccountTransactions()

        let entitlementsJson = try await self.API.getCustomerEntitlements(customerId: customerId!)
        var entitlements: [MobilyCustomerEntitlement] = []

        for jsonEntitlement in entitlementsJson {
            entitlements.append(await MobilyCustomerEntitlement.parse(jsonEntitlement: jsonEntitlement, storeAccountTransactions: self.storeAccountTransactions!))
        }

        self.entitlements = entitlements
    }

    func syncProduct() async throws {
        try await syncExecutor.execute {
            try await self.syncProduct()
        }
    }

    func syncEntitlements() async throws {
        try await syncExecutor.execute {
            try await self._syncEntitlements()
        }
    }

    func getProducts(identifiers: [String]?) async throws -> [MobilyProduct] {
        try await ensureSync()

        var result: [MobilyProduct] = []

        for p in products! {
            if identifiers == nil || identifiers!.contains(p.identifier) {
                result.append(p)
            }
        }

        return result
    }

    func getSubscriptionGroups(identifiers: [String]?) async throws -> [MobilySubscriptionGroup] {
        try await ensureSync()

        var result: [MobilySubscriptionGroup] = []

        for g in subscriptionGroups! {
            if identifiers == nil || identifiers!.contains(g.identifier) {
                result.append(g)
            }
        }

        return result
    }

    func getEntitlement(forSubscriptionGroup subscriptionGroupId: String) throws -> MobilyCustomerEntitlement? {
        if customerId == nil {
            throw MobilyError.no_customer_logged
        }

        return entitlements?.first { entitlement in
            entitlement.type == .subscription && entitlement.product.subscriptionProduct?.subscriptionGroupId == subscriptionGroupId
        }
    }

    func getEntitlement(forProductId productId: String) throws -> MobilyCustomerEntitlement? {
        if customerId == nil {
            throw MobilyError.no_customer_logged
        }

        return entitlements?.first { entitlement in
            entitlement.product.id == productId
        }
    }

    func getEntitlements(forProductIds productIds: [String]) throws -> [MobilyCustomerEntitlement] {
        if customerId == nil {
            throw MobilyError.no_customer_logged
        }

        return entitlements?.filter { entitlement in
            productIds.contains(entitlement.product.id)
        } ?? []
    }

    func getStoreAccountTransaction(forProduct product: MobilyProduct) -> Transaction? {
        return self.storeAccountTransactions?.first { entitlement in
            entitlement.value.productID == product.ios_sku
        }?.value
    }

    func getStoreAccountTransaction(forSubscriptionGroup subscriptionGroupId: String) -> Transaction? {
        let productsInGroup = products?.filter { p in
            p.subscriptionProduct?.subscriptionGroupId == subscriptionGroupId
        }
        if productsInGroup == nil || productsInGroup!.isEmpty {
            return nil
        }

        return self.storeAccountTransactions?.first { entitlement in
            for product in productsInGroup! {
                if entitlement.value.productID == product.ios_sku {
                    return true
                }
            }
            return false
        }?.value
    }
}
