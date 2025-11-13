//
//  MobilyPurchaseSDK.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

@objc public class MobilyPurchaseSDK: NSObject {
    public let appId: String
    public let environment: String
    private var customer: MobilyCustomer?

    private let API: MobilyPurchaseAPI
    private var syncer: MobilyPurchaseSDKSyncer
    private let waiter: MobilyPurchaseSDKWaiter
    private let diagnostics: MobilyPurchaseSDKDiagnostics
    private let refundRequestManager: MobilyPurchaseRefundRequestManager

    private var updateTxTask: Task<Void, Never>?
    private let purchaseExecutor = AsyncDispatchQueue(label: "mobilyflow-purchase")

    private let lifecycleManager = AppLifecycleManager()

    private var productsCaches: [UUID: MobilyProduct] = [:]

    @objc public init(
        appId: String,
        apiKey: String,
        environment: String,
        options: MobilyPurchaseSDKOptions? = nil
    ) {
        MobilyEnvironment.parse(environment)

        self.appId = appId
        self.environment = environment
        self.API = MobilyPurchaseAPI(appId: appId, apiKey: apiKey, environment: environment, locales: getPreferredLocales(options?.locales), apiURL: options?.apiURL)
        self.diagnostics = MobilyPurchaseSDKDiagnostics(customerId: nil)
        self.waiter = MobilyPurchaseSDKWaiter(API: API, diagnostics: self.diagnostics)
        self.syncer = MobilyPurchaseSDKSyncer(API: self.API)
        self.refundRequestManager = MobilyPurchaseRefundRequestManager(API: self.API)

        super.init()

        Monitoring.initialize(tag: "MobilyFlow", allowLogging: options?.debug ?? false) { logFile in
            try await self.API.uploadMonitoring(customerId: self.customer?.id, file: logFile)
        }

        lifecycleManager.registerCrash { _, _ in
            // TODO: This sometime crash
            Logger.fileHandle?.flush()
            self.sendDiagnostic()
        }

        // Manage out-of-app purchase
        startUpdateTransactionTask()
    }

    @objc public func close() {
        self.logout()
        self.syncer.close()
        self.lifecycleManager.unregisterAll()
        self.updateTxTask?.cancel()
    }

    deinit {
        close()
    }

    /* ******************************************************************* */
    /* ****************************** LOGIN ****************************** */
    /* ******************************************************************* */

    @objc public func login(externalRef: String) async throws -> MobilyCustomer {
        // 1. Logout previous customer
        self.logout()

        // 2. Login
        let loginResponse = try await self.API.login(externalRef: externalRef)
        self.customer = MobilyCustomer.parse(loginResponse.customer)
        diagnostics.customerId = self.customer?.id
        try await self.syncer.login(customer: customer, jsonEntitlements: loginResponse.entitlements)

        // 3. Map transaction that are not known by the server
        let transactionToMap = await MobilyPurchaseSDKHelper.getTransactionToMap(loginResponse.platformOriginalTransactionIds)
        if !transactionToMap.isEmpty {
            do {
                try await self.API.mapTransactions(customerId: self.customer!.id, transactions: transactionToMap)
            } catch {
                Logger.e("Map transactions error", error: error)
            }
        }

        // 4. Send Refund Requests Notifications
        if let refundRequests = loginResponse.appleRefundRequests {
            Task(priority: .background) {
                // TODO: We may implement a system to show refund request when App foreground after 10s, not only when login
                await self.refundRequestManager.manageRefundRequests(refundRequests)
            }
        }

        // 5. Send monitoring if requested
        if loginResponse.haveMonitoringRequests {
            Task(priority: .background) {
                // When monitoring is requested, send 10 days
                Logger.d("Send monitoring as requested by the server")
                self.diagnostics.sendDiagnostic(sinceDays: 10)
            }
        }

        return self.customer!
    }

    @objc public func logout() {
        self.customer = nil
        diagnostics.customerId = nil
        self.syncer.logout()
    }

    /* ******************************************************************* */
    /* **************************** PRODUCTS ***************************** */
    /* ******************************************************************* */

    @objc public func getProducts(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilyProduct] {
        try await syncer.ensureSync()

        // 1. Get product from Mobily API
        let jsonProducts = try await self.API.getProducts(identifiers: identifiers)

        // 2. Get product from App Store
        let iosIdentifiers = getAllIosSkuForJsonProducts(jsonProducts: jsonProducts)
        await MobilyPurchaseRegistry.registerIOSProductSkus(iosIdentifiers)

        // 3. Parse to MobilyProduct
        var mobilyProducts: [MobilyProduct] = []

        for jsonProduct in jsonProducts {
            let mobilyProduct = await MobilyProduct.parse(jsonProduct)
            productsCaches[mobilyProduct.id] = mobilyProduct

            if !onlyAvailable || mobilyProduct.status == MobilyProductStatus.AVAILABLE {
                mobilyProducts.append(mobilyProduct)
            }
        }

        return mobilyProducts
    }

    @objc public func getSubscriptionGroups(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilySubscriptionGroup] {
        try await syncer.ensureSync()

        // 1. Get groups from Mobily API
        let jsonGroups = try await self.API.getSubscriptionGroups(identifiers: identifiers)

        // 2. Get product from App Store
        let iosIdentifiers = jsonGroups.flatMap { group in
            getAllIosSkuForJsonProducts(jsonProducts: group["Products"] as! [[String: Any]])
        }
        await MobilyPurchaseRegistry.registerIOSProductSkus(iosIdentifiers)

        // 3. Parse to MobilySubscriptionGroup
        var groups: [MobilySubscriptionGroup] = []

        for jsonGroup in jsonGroups {
            let mobilyGroup = await MobilySubscriptionGroup.parse(jsonGroup, onlyAvailableProducts: onlyAvailable)

            for product in mobilyGroup.Products {
                productsCaches[product.id] = product
            }

            if !onlyAvailable || mobilyGroup.Products.count > 0 {
                groups.append(mobilyGroup)
            }
        }

        return groups
    }

    @objc public func getSubscriptionGroupById(id: String) async throws -> MobilySubscriptionGroup {
        try await syncer.ensureSync()

        // 1. Get groups from Mobily API
        let jsonGroup = try await self.API.getSubscriptionGroupById(id: id)

        // 2. Get product from App Store
        let iosIdentifiers = getAllIosSkuForJsonProducts(jsonProducts: jsonGroup["Products"] as! [[String: Any]])
        await MobilyPurchaseRegistry.registerIOSProductSkus(iosIdentifiers)

        // 3. Parse to MobilySubscriptionGroup
        let mobilyGroup = await MobilySubscriptionGroup.parse(jsonGroup, onlyAvailableProducts: false)

        for product in mobilyGroup.Products {
            productsCaches[product.id] = product
        }

        return mobilyGroup
    }

    @objc public func getProductFromCacheWithId(id: UUID) -> MobilyProduct? {
        return productsCaches[id]
    }

    /* ******************************************************************* */
    /* ************************** ENTITLEMENTS *************************** */
    /* ******************************************************************* */

    private func _cacheEntitlement(_ entitlement: MobilyCustomerEntitlement?) -> MobilyCustomerEntitlement? {
        if let entitlement = entitlement {
            productsCaches[entitlement.Product.id] = entitlement.Product

            if entitlement.Subscription?.RenewProduct != nil {
                productsCaches[entitlement.Subscription!.RenewProduct!.id] = entitlement.Subscription!.RenewProduct
            }
        }
        return entitlement
    }

    @objc public func getEntitlementForSubscription(subscriptionGroupId: String) async throws -> MobilyCustomerEntitlement? {
        return try self._cacheEntitlement(await syncer.getEntitlement(forSubscriptionGroup: subscriptionGroupId))
    }

    @objc public func getEntitlement(productId: UUID) async throws -> MobilyCustomerEntitlement? {
        return try self._cacheEntitlement(await syncer.getEntitlement(forProductId: productId))
    }

    @objc public func getEntitlements(productIds: [UUID]?) async throws -> [MobilyCustomerEntitlement] {
        let result = try syncer.getEntitlements(forProductIds: productIds)
        result.forEach { _ = self._cacheEntitlement($0) }
        return result
    }

    @objc public func getExternalEntitlements() async throws -> [MobilyCustomerEntitlement] {
        if customer == nil {
            throw MobilyError.no_customer_logged
        }

        let (transactionToClaim, storeAccountTransactions) = await MobilyPurchaseSDKHelper.getAllTransactionSignatures()
        var entitlements: [MobilyCustomerEntitlement] = []

        if !transactionToClaim.isEmpty {
            let jsonEntitlements = try await self.API.getCustomerExternalEntitlements(customerId: customer!.id, transactions: transactionToClaim)

            for jsonEntitlement in jsonEntitlements {
                entitlements.append(await MobilyCustomerEntitlement.parse(jsonEntitlement, storeAccountTransactions: storeAccountTransactions))
            }
        }

        return entitlements
    }

    /**
     Request transfer ownership of local device transactions.
     */
    @objc public func requestTransferOwnership() async throws -> String {
        if customer == nil {
            throw MobilyError.no_customer_logged
        }

        let (transactionToClaim, _) = await MobilyPurchaseSDKHelper.getAllTransactionSignatures()

        if !transactionToClaim.isEmpty {
            let requestId = try await self.API.transferOwnershipRequest(customerId: self.customer!.id, transactions: transactionToClaim)
            let status = try await self.waiter.waitTransferOwnershipRequest(requestId: requestId)
            Logger.d("Request ownership transfer complete with status \(status)")
            return status
        } else {
            throw MobilyTransferOwnershipError.nothing_to_transfer
        }
    }

    /* ******************************************************************* */
    /* ************************ INTERFACE HELPERS ************************ */
    /* ******************************************************************* */

    /**
     * Open the manage subscription dialog
     */
    @objc public func openManageSubscription() async {
        try? await AppStore.showManageSubscriptions(in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
    }

    /**
     * Open a refund dialog for the last transaction on the given product.
     *
     * Pro tips: to test declined refund in sandbox, once the dialog appear, select "other" and write "REJECT" in the text box.
     */
    @objc public func openRefundDialog(forProduct: MobilyProduct) async -> String {
        if forProduct.oneTime?.isConsumable ?? false {
            do {
                let lastTxId = try await self.API.getLastTxPlatformIdForProduct(customerId: self.customer!.id, productId: forProduct.id)
                let result = try? await Transaction.beginRefundRequest(for: UInt64(lastTxId)!, in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
                return (result ?? .userCancelled) == .success ? MobilyRefundDialogResult.SUCCESS : MobilyRefundDialogResult.CANCELLED
            } catch {
                return MobilyRefundDialogResult.TRANSACTION_NOT_FOUND
            }
        } else {
            if #available(iOS 18.4, *) {
                for await signedTx in Transaction.currentEntitlements(for: forProduct.ios_sku) {
                    if case .verified(let transaction) = signedTx {
                        let result = try? await Transaction.beginRefundRequest(for: transaction.id, in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
                        return (result ?? .userCancelled) == .success ? MobilyRefundDialogResult.SUCCESS : MobilyRefundDialogResult.CANCELLED
                    }
                }
            } else {
                for await signedTx in Transaction.currentEntitlements {
                    if case .verified(let transaction) = signedTx {
                        if transaction.productID == forProduct.ios_sku {
                            let result = try? await Transaction.beginRefundRequest(for: transaction.id, in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
                            return (result ?? .userCancelled) == .success ? MobilyRefundDialogResult.SUCCESS : MobilyRefundDialogResult.CANCELLED
                        }
                    }
                }
            }
        }
        return MobilyRefundDialogResult.TRANSACTION_NOT_FOUND
    }

    /**
     * Open a refund dialog for the given transactionId.
     * Warning: this is iOS transactionId, not MobilyFlow transactionId
     *
     * Pro tips: to test declined refund in sandbox, once the dialog appear, select "other" and write "REJECT" in the text box.
     */
    @objc public func openRefundDialog(forTransactionId: String) async -> String {
        let result = try? await Transaction.beginRefundRequest(for: UInt64(forTransactionId)!, in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
        return (result ?? .userCancelled) == .success ? MobilyRefundDialogResult.SUCCESS : MobilyRefundDialogResult.CANCELLED
    }

    /* ******************************************************************* */
    /* **************************** PURCHASE ***************************** */
    /* ******************************************************************* */

    @objc public func purchaseProduct(_ product: MobilyProduct, options: PurchaseOptions? = nil) async throws -> MobilyEvent {
        var event: MobilyEvent? = nil

        if self.customer == nil {
            throw MobilyError.no_customer_logged
        }

        try await purchaseExecutor.executeOrFallback({
            try await self.syncer.ensureSync()

            if self.customer!.forwardNotificationEnable {
                throw MobilyPurchaseError.customer_forwarded
            }

            let internalPurchaseOptions = try await MobilyPurchaseSDKHelper.createPurchaseOptions(syncer: self.syncer, API: self.API, customerId: self.customer!.id, product: product, options: options)

            if internalPurchaseOptions.isRedeemURL() {
                let semaphore = DispatchSemaphore(value: 0)
                var error: MobilyPurchaseError?
                let offerCodeLifecycleManager = AppLifecycleManager()
                let knownTransactionIdsForSku = await MobilyPurchaseSDKHelper.getKnownTransactionIdsForSku(product.ios_sku)
                let openTime = Date().timeIntervalSince1970

                offerCodeLifecycleManager.registerDidBecomeActive {
                    Logger.d("[purchaseProduct] didBecomeActive")
                    offerCodeLifecycleManager.unregisterAll()

                    Task(priority: .high) {
                        let startTime = Date().timeIntervalSince1970
                        if openTime + 8 > startTime {
                            // Less that 8s outside of the app, we consider the user doesn't buy the product as he will not have the time to execute the whole purchase flow
                            Logger.w("[purchaseProduct] Less than 8s outside of the app -> consider purchase canceled (\(startTime - openTime)s)")
                            error = MobilyPurchaseError.user_canceled
                            semaphore.signal()
                            return
                        }

                        // Pull Transaction in a loop as it's faster than waiting Transaction.updates
                        while true {
                            sleep(2)

                            if startTime + 30 < Date().timeIntervalSince1970 {
                                Logger.e("[purchaseProduct] Can't see offer code transaction after 30s, consider purchase canceled")
                                error = MobilyPurchaseError.user_canceled
                                semaphore.signal()
                                return
                            }

                            for await signedTx in Transaction.currentEntitlements {
                                if case .verified(let transaction) = signedTx {
                                    if transaction.productID == product.ios_sku && !knownTransactionIdsForSku.contains(transaction.id) {
                                        Logger.d("[purchaseProduct] Receive Offer Code Transaction: \(transaction.id)")
                                        let isFinished = await MobilyPurchaseSDKHelper.isTransactionFinished(id: transaction.id)
                                        event = try await self.finishTransaction(signedTx: signedTx, downgradeToProductId: nil)
                                        semaphore.signal()
                                        return
                                    }
                                }
                            }
                        }
                    }
                }

                DispatchQueue.main.sync {
                    Task(priority: .high) {
                        await UIApplication.shared.open(internalPurchaseOptions.getReeemUrl())
                    }
                }

                semaphore.wait()
                if error != nil {
                    throw error!
                }
            } else {
                let (iosProduct, purchaseOptions) = internalPurchaseOptions.getPurchaseOptions()

                let purchaseResult: Product.PurchaseResult
                do {
                    purchaseResult = try await iosProduct.purchase(options: purchaseOptions)
                } catch StoreKitError.userCancelled {
                    throw MobilyPurchaseError.user_canceled
                } catch let error as Product.PurchaseError {
                    Logger.e("[purchaseProduct] PurchaseError", error: error)
                    Logger.d("[purchaseProduct] error.localizedDescription \(error.localizedDescription)")
                    if #available(iOS 15.4, *) {
                        Logger.d("[purchaseProduct] error.errorDescription \(error.errorDescription ?? "nil")")
                        Logger.d("[purchaseProduct] error.failureReason \(error.failureReason ?? "nil")")
                        Logger.d("[purchaseProduct] error.recoverySuggestion \(error.recoverySuggestion ?? "nil")")
                        Logger.d("[purchaseProduct] error.helpAnchor \(error.helpAnchor ?? "nil")")
                    }
                    self.sendDiagnostic()
                    throw MobilyPurchaseError.product_unavailable
                } catch StoreKitError.notAvailableInStorefront {
                    Logger.e("[purchaseProduct] Product notAvailableInStorefront")
                    self.sendDiagnostic()
                    throw MobilyPurchaseError.product_unavailable
                } catch StoreKitError.networkError(let url) {
                    Logger.e("[purchaseProduct] Network error: \(url)")
                    throw MobilyPurchaseError.network_unavailable
                } catch StoreKitError.systemError(let error) {
                    Logger.e("[purchaseProduct] systemError", error: error)
                    throw MobilyError.store_unavailable
                } catch {
                    Logger.e("[purchaseProduct] Other error", error: error)
                    throw MobilyPurchaseError.failed
                }

                switch purchaseResult {
                case .pending:
                    // Probably waiting parental control approve (know as ask-to-buy scenario)
                    Logger.w("purchaseProduct pending")
                    throw MobilyPurchaseError.pending

                case .success(let signedTx):
                    switch signedTx {
                    case .verified(let transaction):
                        if internalPurchaseOptions.isDowngrade {
                            event = try await self.finishTransaction(signedTx: signedTx, downgradeToProductId: product.id)
                        } else {
                            Logger.d("Force webhook for \(transaction.id) (original: \(transaction.originalID))")
                            try? await self.API.forceWebhook(transactionId: transaction.id, productId: product.id, isSandbox: isSandboxTransaction(transaction: transaction))
                            event = try await self.finishTransaction(signedTx: signedTx)
                        }
                    case .unverified:
                        Logger.e("purchaseProduct unverified")
                        try? Monitoring.exportDiagnostic(sinceDays: 1)
                        throw MobilyPurchaseError.failed
                    }

                case .userCancelled:
                    throw MobilyPurchaseError.user_canceled

                @unknown default:
                    assertionFailure("Unexpected result")
                    throw MobilyPurchaseError.failed
                }
            }
        }, fallback: {
            throw MobilyPurchaseError.purchase_already_pending
        })

        if event == nil {
            throw MobilyError.unknown_error
        }

        return event!
    }

    /* ******************************************************************* */
    /* ****************** UPDATE TRANSACTION LISTENER ****************** */
    /* ******************************************************************* */

    private func startUpdateTransactionTask() {
        self.updateTxTask?.cancel()
        self.updateTxTask = Task(priority: .background) {
            // Note: `Transaction.updates` never returns and continuously send updates on transaction during the whole lifetime of the app
            for await signedTx in Transaction.updates {
                if case .verified(let tx) = signedTx {
                    if !(await MobilyPurchaseSDKHelper.isTransactionFinished(id: tx.id)) {
                        Logger.d("[startUpdateTransactionTask] finishTransaction \(tx.id)")
                        _ = try? await self.finishTransaction(signedTx: signedTx)
                    }
                }
            }
            Logger.d("End update task")
        }
    }

    private func finishTransaction(signedTx: VerificationResult<Transaction>, downgradeToProductId: UUID? = nil) async throws -> MobilyEvent? {
        var event: MobilyEvent? = nil

        if case .verified(let transaction) = signedTx {
            Logger.d("Finish transaction: \(transaction.id) (\(transaction.productID))")
            await transaction.finish()

            if let customer = self.customer {
                do {
                    try await API.mapTransactions(customerId: customer.id, transactions: [signedTx.jwsRepresentation])
                } catch {
                    Logger.e("Map transaction error", error: error)
                }
                if !customer.forwardNotificationEnable {
                    let result = try await self.waiter.waitPurchaseWebhook(signedTx: signedTx, downgradeToProductId: downgradeToProductId)
                    if result.event != nil {
                        let (_, storeAccountTransactions) = await MobilyPurchaseSDKHelper.getAllTransactionSignatures()
                        event = await MobilyEvent.parse(result.event!, storeAccountTransactions: storeAccountTransactions)
                    }
                }
                try? await syncer.ensureSync(force: true)
            }
        }
        return event
    }

    /* *********************************************************** */
    /* *********************** DIAGNOSTICS *********************** */
    /* *********************************************************** */

    @objc public func sendDiagnostic() {
        diagnostics.sendDiagnostic()
    }

    /* ************************************************************** */
    /* *************************** OTHERS *************************** */
    /* ************************************************************** */

    @objc public func isBillingAvailable() -> Bool {
        return AppStore.canMakePayments
    }

    // TODO: onStorefrontChange
    @objc public func getStoreCountry() async -> String? {
        if let alpha3 = (await Storefront.current)?.countryCode {
            return CountryCodes.alpha3ToAlpha2(alpha3)
        }
        return nil
    }

    @objc public func isForwardingEnable(externalRef: String) async throws -> Bool {
        return try await API.isForwardingEnable(externalRef: externalRef)
    }

    @objc public func getCustomer() async throws -> MobilyCustomer? {
        return self.customer
    }

    @objc public func getSDKVersion() -> String {
        return MobilyFlowVersion.current
    }
}
