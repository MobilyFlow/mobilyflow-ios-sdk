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
    private var customer: MobilyCustomer?

    private let CACHE_DURATION_SEC = 3600.0

    private var entitlements: [MobilyCustomerEntitlement]?
    private var storeAccountTransactions: [UInt64: Transaction]? // originalTxId -> Transaction

    private var lastSyncTime: Double?
    private let syncExecutor = AsyncDispatchQueue(label: "mobilyflow-sync")

    init(API: MobilyPurchaseAPI) {
        self.API = API
    }

    func login(customer: MobilyCustomer?, jsonEntitlements: [[String: Any]]?) async throws {
        syncExecutor.sync {
            self.customer = customer
            self.entitlements = nil
            self.lastSyncTime = nil
        }
        if self.customer != nil && jsonEntitlements != nil {
            try await syncExecutor.execute {
                Logger.d("Sync Entitlement with login data")
                CrashlyticsLogger.log("Sync Entitlement with login data (\(jsonEntitlements?.count ?? -1))")
                try await self._syncEntitlements(jsonEntitlements: jsonEntitlements)
            }
        }
        self.lastSyncTime = Date().timeIntervalSince1970
    }

    func logout() {
        syncExecutor.sync {
            self.customer = nil
            self.entitlements = nil
            self.lastSyncTime = nil
        }
    }

    func close() {
        syncExecutor.sync {
            self.customer = nil
            self.entitlements = nil
        }
        syncExecutor.cancel()
    }

    func ensureSync(force: Bool = false) async throws {
        try await syncExecutor.execute {
            if self.customer != nil && self.customer!.forwardNotificationEnable {
                // If a customer is flag as forwarded, we double check if it's still the case (so if we disable forwarding
                // on the backoffice, it's take effect instantly)
                if let isForwardingEnable = try? await self.API.isForwardingEnable(externalRef: self.customer!.externalRef) {
                    self.customer!.forwardNotificationEnable = isForwardingEnable
                }
            }

            if
                force ||
                self.lastSyncTime == nil ||
                (self.lastSyncTime! + self.CACHE_DURATION_SEC) < Date().timeIntervalSince1970
            {
                Logger.d("Run Sync expected...")
                if self.customer != nil {
                    Logger.d("Run Sync for customer \(self.customer!.id) (externalRef: \(self.customer!.externalRef ?? "null"))")

                    try await self._syncEntitlements()
                    self.lastSyncTime = Date().timeIntervalSince1970
                } else {
                    Logger.d(" -> Sync skipped (no customer)")
                }
                Logger.d("End Sync")
            }
        }
    }

    private func _syncStoreAccountTransactions() async throws {
        var storeAccountTransactions: [UInt64: Transaction] = [:]

        for await signedTx in Transaction.currentEntitlements {
            if case .verified(let transaction) = signedTx {
                storeAccountTransactions[transaction.originalID] = transaction
            }
        }

        self.storeAccountTransactions = storeAccountTransactions
    }

    private func _syncEntitlements(jsonEntitlements overrideJsonEntitlements: [[String: Any]]? = nil) async throws {
        try await _syncStoreAccountTransactions()

        let jsonEntitlements = overrideJsonEntitlements != nil ? overrideJsonEntitlements! : try await self.API.getCustomerEntitlements(customerId: customer!.id)
        var entitlements: [MobilyCustomerEntitlement] = []

        for jsonEntitlement in jsonEntitlements {
            CrashlyticsLogger.log("Parse Entitlement in sync (\(jsonEntitlement))")
            entitlements.append(await MobilyCustomerEntitlement.parse(jsonEntitlement, storeAccountTransactions: self.storeAccountTransactions!))
            CrashlyticsLogger.log("Parse Entitlement done")
        }

        self.entitlements = entitlements
    }

    func getEntitlement(forSubscriptionGroup subscriptionGroupId: UUID) async throws -> MobilyCustomerEntitlement? {
        if customer == nil {
            throw MobilyError.no_customer_logged
        }

        try await ensureSync()

        return entitlements?.first { entitlement in
            entitlement.type == MobilyProductType.SUBSCRIPTION && entitlement.Product.subscription?.groupId == subscriptionGroupId
        }
    }

    func getEntitlement(forProductId productId: UUID) async throws -> MobilyCustomerEntitlement? {
        if customer == nil {
            throw MobilyError.no_customer_logged
        }

        try await ensureSync()

        return entitlements?.first { entitlement in
            entitlement.Product.id == productId
        }
    }

    func getEntitlements(forProductIds productIds: [UUID]?) throws -> [MobilyCustomerEntitlement] {
        if customer == nil {
            throw MobilyError.no_customer_logged
        }

        if productIds == nil {
            return entitlements ?? []
        }

        return entitlements?.filter { entitlement in
            productIds!.contains(entitlement.Product.id)
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
    func getStoreAccountTransaction(forIosSubscriptionGroup subscriptionGroupId: String?) -> Transaction? {
        if subscriptionGroupId == nil || subscriptionGroupId!.isEmpty {
            return nil
        }

        return self.storeAccountTransactions?.first { entitlement in
            if entitlement.value.subscriptionGroupID == subscriptionGroupId {
                return true
            }
            return false
        }?.value
    }
}
