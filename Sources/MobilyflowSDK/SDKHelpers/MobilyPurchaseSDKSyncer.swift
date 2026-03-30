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

    init(API: MobilyPurchaseAPI) {
        self.API = API
    }

    func login(customer: MobilyCustomer?, jsonEntitlements: [[String: Any]]?) async throws {
        self.customer = customer
        self.entitlements = nil
        self.lastSyncTime = nil

        if self.customer != nil && jsonEntitlements != nil {
            Logger.d("Sync Entitlement with login data (\(jsonEntitlements?.count ?? -1))")
            try await self._syncEntitlements(jsonEntitlements: jsonEntitlements)
        }
        self.lastSyncTime = Date().timeIntervalSince1970
    }

    func close() {
        self.customer = nil
        self.entitlements = nil
        self.lastSyncTime = nil
    }

    func ensureSync(force: Bool = false) async throws {
        guard let customer = self.customer else {
            Logger.d("Sync skipped (no customer)")
            return
        }

        if customer.forwardNotificationEnable {
            // TODO: We check forwarding on externalRef while this field is optionnal, we should switch it to customerId
            // If a customer is flag as forwarded, we double check if it's still the case (so if we disable forwarding
            // on the backoffice, it's take effect instantly)
            if let isForwardingEnable = try? await self.API.isForwardingEnable(externalRef: customer.externalRef) {
                customer.forwardNotificationEnable = isForwardingEnable
            }
        }

        if
            force ||
            self.lastSyncTime == nil ||
            (self.lastSyncTime! + self.CACHE_DURATION_SEC) < Date().timeIntervalSince1970
        {
            Logger.d("Run Sync for customer \(customer.id) (externalRef: \(customer.externalRef))")

            try await self._syncEntitlements()
            self.lastSyncTime = Date().timeIntervalSince1970

            Logger.d("End Sync")
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

        guard let customer = self.customer else {
            // TODO: this is a hotfix, customer should not be nil at this time but some race condition (login while sync) make it to be nil
            Logger.e("_syncEntitlements with null customer")
            return
        }

        let jsonEntitlements = overrideJsonEntitlements != nil ? overrideJsonEntitlements! : try await self.API.getCustomerEntitlements(customerId: customer.id)
        var entitlements: [MobilyCustomerEntitlement] = []

        for jsonEntitlement in jsonEntitlements {
            entitlements.append(await MobilyCustomerEntitlement.parse(jsonEntitlement, storeAccountTransactions: self.storeAccountTransactions!))
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
