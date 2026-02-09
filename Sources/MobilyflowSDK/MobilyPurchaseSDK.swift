//
//  MobilyPurchaseSDK.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import StoreKit

@objc public final class MobilyPurchaseSDK: NSObject {
    private static var instance: MobilyPurchaseSDKImpl?

    /**
     Note: Calling init multiple times with different config will logout the current user.
     */
    @objc public static func initialize(
        appId: String,
        apiKey: String,
        environment: String,
        options: MobilyPurchaseSDKOptions? = nil
    ) {
        if let impl = instance {
            impl.reinit(appId: appId, apiKey: apiKey, environment: environment, options: options)
        } else {
            instance = MobilyPurchaseSDKImpl(
                appId: appId,
                apiKey: apiKey,
                environment: environment,
                options: options
            )
        }
    }

    private static func ensureInit(checkOnly: Bool = false) throws -> Bool {
        if checkOnly {
            return instance != nil
        }
        guard instance != nil else {
            throw MobilyError.sdk_not_initialized
        }
        return true
    }

    @objc public static func close() {
        if try! ensureInit(checkOnly: true) {
            instance?.close()
        }
        instance = nil
    }

    @objc public static func login(externalRef: String) async throws -> MobilyCustomer {
        _ = try ensureInit()
        return try await instance!.login(externalRef: externalRef)
    }

    @objc public static func logout() {
        if try! ensureInit(checkOnly: true) {
            instance!.logout()
        }
    }

    @objc public static func getProducts(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilyProduct] {
        _ = try ensureInit()
        return try await instance!.getProducts(identifiers: identifiers, onlyAvailable: onlyAvailable)
    }

    @objc public static func getSubscriptionGroups(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilySubscriptionGroup] {
        _ = try ensureInit()
        return try await instance!.getSubscriptionGroups(identifiers: identifiers, onlyAvailable: onlyAvailable)
    }

    @objc public static func getSubscriptionGroupById(_ id: UUID) async throws -> MobilySubscriptionGroup {
        _ = try ensureInit()
        return try await instance!.getSubscriptionGroupById(id: id)
    }

    @objc public static func DANGEROUS_getProductFromCacheWithId(_ id: UUID) -> MobilyProduct? {
        if try! ensureInit(checkOnly: true) {
            return instance!.getProductFromCacheWithId(id: id)
        }
        return nil
    }

    @objc public static func getEntitlementForSubscription(subscriptionGroupId: UUID) async throws -> MobilyCustomerEntitlement? {
        _ = try ensureInit()
        return try await instance!.getEntitlementForSubscription(subscriptionGroupId: subscriptionGroupId)
    }

    @objc public static func getEntitlement(productId: UUID) async throws -> MobilyCustomerEntitlement? {
        _ = try ensureInit()
        return try await instance!.getEntitlement(productId: productId)
    }

    @objc public static func getEntitlements(productIds: [UUID]?) async throws -> [MobilyCustomerEntitlement] {
        _ = try ensureInit()
        return try await instance!.getEntitlements(productIds: productIds)
    }

    @objc public static func getExternalEntitlements() async throws -> [MobilyCustomerEntitlement] {
        _ = try ensureInit()
        return try await instance!.getExternalEntitlements()
    }

    @objc public static func requestTransferOwnership() async throws -> String {
        _ = try ensureInit()
        return try await instance!.requestTransferOwnership()
    }

    @objc public static func openManageSubscription() async {
        try? await AppStore.showManageSubscriptions(in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
    }

    @objc public static func openRefundDialog(forProduct: MobilyProduct) async throws -> String {
        _ = try ensureInit()
        return await instance!.openRefundDialog(forProduct: forProduct)
    }

    @objc public static func openRefundDialog(forTransactionId: String) async throws -> String {
        _ = try ensureInit()
        return await instance!.openRefundDialog(forTransactionId: forTransactionId)
    }

    @objc public static func purchaseProduct(_ product: MobilyProduct, options: PurchaseOptions? = nil) async throws -> MobilyEvent {
        _ = try ensureInit()
        return try await instance!.purchaseProduct(product, options: options)
    }

    @objc public static func sendDiagnostic() throws {
        _ = try ensureInit()
        instance!.sendDiagnostic()
    }

    @objc public static func getStoreCountry() async throws -> String? {
        _ = try ensureInit()
        return await instance!.getStoreCountry()
    }

    @objc public static func isBillingAvailable() -> Bool {
        return AppStore.canMakePayments
    }

    @objc public static func isForwardingEnable(externalRef: String) async throws -> Bool {
        _ = try ensureInit()
        return try await instance!.isForwardingEnable(externalRef: externalRef)
    }

    @objc public static func getCustomer() async throws -> MobilyCustomer? {
        _ = try ensureInit()
        return try await instance!.getCustomer()
    }

    @objc public static func getSDKVersion() -> String {
        return MobilyFlowVersion.current
    }
}
