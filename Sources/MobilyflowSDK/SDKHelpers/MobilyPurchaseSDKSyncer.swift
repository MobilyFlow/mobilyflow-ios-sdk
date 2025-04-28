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

    private var entitlements: [MobilyCustomerEntitlement]?
    private var storeAccountTransactions: [UInt64: Transaction]? // originalTxId -> Transaction

    private var lastSyncTime: Double?
    private let syncExecutor = AsyncDispatchQueue(label: "mobilyflow-sync")

    init(API: MobilyPurchaseAPI) {
        self.API = API
    }

    func login(customerId: UUID?, jsonEntitlements: [[String: Any]]?) async throws {
        syncExecutor.sync {
            self.customerId = customerId
            self.entitlements = nil
        }
        if self.customerId != nil && jsonEntitlements != nil {
            try await syncExecutor.execute {
                try await self._syncEntitlements(jsonEntitlements: jsonEntitlements)
                self.lastSyncTime = Date().timeIntervalSince1970
            }
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
                self.lastSyncTime == nil ||
                (self.lastSyncTime! + self.CACHE_DURATION_SEC) < Date().timeIntervalSince1970
            {
                Logger.d("Run Sync")
                try await self._syncEntitlements()
                self.lastSyncTime = Date().timeIntervalSince1970
                Logger.d("End Sync")
            }
        }
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

    private func _syncEntitlements(jsonEntitlements overrideJsonEntitlements: [[String: Any]]? = nil) async throws {
        if customerId == nil {
            return
        }

        try await _syncStoreAccountTransactions()

        let jsonEntitlements = overrideJsonEntitlements != nil ? overrideJsonEntitlements! : try await self.API.getCustomerEntitlements(customerId: customerId!)
        var entitlements: [MobilyCustomerEntitlement] = []

        for jsonEntitlement in jsonEntitlements {
            entitlements.append(await MobilyCustomerEntitlement.parse(jsonEntitlement: jsonEntitlement, storeAccountTransactions: self.storeAccountTransactions!))
        }

        self.entitlements = entitlements
    }

    func getEntitlement(forSubscriptionGroup subscriptionGroupId: String) async throws -> MobilyCustomerEntitlement? {
        if customerId == nil {
            throw MobilyError.no_customer_logged
        }

        try await ensureSync()

        return entitlements?.first { entitlement in
            entitlement.type == .subscription && entitlement.product.subscriptionProduct?.subscriptionGroupId == subscriptionGroupId
        }
    }

    func getEntitlement(forProductId productId: String) async throws -> MobilyCustomerEntitlement? {
        if customerId == nil {
            throw MobilyError.no_customer_logged
        }

        try await ensureSync()

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

    /**
     Return the Storekit Transaction related to the MobilyProduct
     */
    func getStoreAccountTransaction(forIosSku iosSku: String) -> Transaction? {
        return self.storeAccountTransactions?.first { entitlement in
            entitlement.value.productID == iosSku
        }?.value
    }

    /**
     Return the Storekit Transaction related to a product from a subscription group
     */
    func getStoreAccountTransaction(forIosSubscriptionGroup subscriptionGroupId: String) -> Transaction? {
        return self.storeAccountTransactions?.first { entitlement in
            if entitlement.value.subscriptionGroupID == subscriptionGroupId {
                return true
            }
            return false
        }?.value
    }
}
