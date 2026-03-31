//
//  MobilyPurchaseSDK.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import StoreKit

@objc public final class MobilyPurchaseSDK: NSObject {
    private static var instance: MobilyPurchaseSDKImpl?
    private static var _onTransactionFinishedListener: ((Transaction) -> Void)?

    /**
     Note: Calling init multiple times with different config will logout the current user.
     */
    @objc public static func initialize(
        appId: String,
        apiKey: String,
        environment: String,
        options: MobilyPurchaseSDKOptions? = nil
    ) {
        if let existingInstance = instance {
            // Close existing instance asynchronously
            Task(priority: .high) {
                await existingInstance.close()
            }
        }

        let impl = MobilyPurchaseSDKImpl(
            appId: appId,
            apiKey: apiKey,
            environment: environment,
            options: options
        )
        Monitoring.initialize(tag: "MobilyFlow", allowLogging: options?.debug ?? false) { logFile in
            try await impl.uploadMonitoring(logFile: logFile)
        }
        Task(priority: .high) {
            await impl.setOnTransactionFinishedListener(_onTransactionFinishedListener)
            await impl.initProcedure()
        }
        instance = impl
    }

    public static func setOnTransactionFinishedListener(_ callback: ((Transaction) -> Void)?) {
        _onTransactionFinishedListener = callback
        if let instance = self.instance {
            Task(priority: .high) {
                await instance.setOnTransactionFinishedListener(_onTransactionFinishedListener)
            }
        }
    }

    private static func ensureInit() throws -> MobilyPurchaseSDKImpl {
        guard let instance = instance else {
            throw MobilyError.sdk_not_initialized
        }
        return instance
    }

    @objc public static func close() {
        guard let instance = instance else {
            return
        }

        Task(priority: .high) {
            await instance.close()
        }
        self.instance = nil
    }

    @objc public static func login(externalRef: String) async throws -> MobilyCustomer {
        let instance = try ensureInit()
        return try await instance.login(externalRef: externalRef)
    }

    @objc public static func logout() async {
        guard let instance = instance else {
            return
        }
        await instance.logout()
    }

    @objc public static func getProducts(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilyProduct] {
        let instance = try ensureInit()
        return try await instance.getProducts(identifiers: identifiers, onlyAvailable: onlyAvailable)
    }

    @objc public static func getSubscriptionGroups(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilySubscriptionGroup] {
        let instance = try ensureInit()
        return try await instance.getSubscriptionGroups(identifiers: identifiers, onlyAvailable: onlyAvailable)
    }

    @objc public static func getSubscriptionGroupById(_ id: UUID) async throws -> MobilySubscriptionGroup {
        let instance = try ensureInit()
        return try await instance.getSubscriptionGroupById(id: id)
    }

    @objc public static func DANGEROUS_getProductFromCacheWithId(_ id: UUID) async -> MobilyProduct? {
        guard let instance = instance else {
            return nil
        }
        return await instance.getProductFromCacheWithId(id: id)
    }

    @objc public static func getEntitlementForSubscription(subscriptionGroupId: UUID) async throws -> MobilyCustomerEntitlement? {
        let instance = try ensureInit()
        return try await instance.getEntitlementForSubscription(subscriptionGroupId: subscriptionGroupId)
    }

    @objc public static func getEntitlement(productId: UUID) async throws -> MobilyCustomerEntitlement? {
        let instance = try ensureInit()
        return try await instance.getEntitlement(productId: productId)
    }

    @objc public static func getEntitlements(productIds: [UUID]?) async throws -> [MobilyCustomerEntitlement] {
        let instance = try ensureInit()
        return try await instance.getEntitlements(productIds: productIds)
    }

    @objc public static func getExternalEntitlements() async throws -> [MobilyCustomerEntitlement] {
        let instance = try ensureInit()
        return try await instance.getExternalEntitlements()
    }

    @objc public static func requestTransferOwnership() async throws -> String {
        let instance = try ensureInit()
        return try await instance.requestTransferOwnership()
    }

    @objc public static func openManageSubscription() async {
        try? await AppStore.showManageSubscriptions(in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
    }

    @objc public static func openRefundDialog(forProduct: MobilyProduct) async throws -> String {
        let instance = try ensureInit()
        return await instance.openRefundDialog(forProduct: forProduct)
    }

    @objc public static func openRefundDialog(forTransactionId: String) async throws -> String {
        let instance = try ensureInit()
        return await instance.openRefundDialog(forTransactionId: forTransactionId)
    }

    @objc public static func purchaseProduct(_ product: MobilyProduct, options: PurchaseOptions? = nil) async throws -> MobilyEvent {
        let instance = try ensureInit()
        return try await instance.purchaseProduct(product, options: options)
    }

    @objc public static func sendDiagnostic() async throws {
        let instance = try ensureInit()
        await instance.sendDiagnostic()
    }

    @objc public static func getStoreCountry() async throws -> String? {
        let instance = try ensureInit()
        return await instance.getStoreCountry()
    }

    @objc public static func isBillingAvailable() -> Bool {
        return AppStore.canMakePayments
    }

    @objc public static func isForwardingEnable(externalRef: String) async throws -> Bool {
        let instance = try ensureInit()
        return try await instance.isForwardingEnable(externalRef: externalRef)
    }

    @objc public static func getCustomer() async throws -> MobilyCustomer? {
        let instance = try ensureInit()
        return try await instance.getCustomer()
    }

    @objc public static func getSDKVersion() -> String {
        return MobilyFlowVersion.current
    }
}
