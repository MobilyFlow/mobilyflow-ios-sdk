//
//  MobilyPurchaseSDKImpl.swift
//  MobilyPurchaseSDKImpl
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

actor MobilyPurchaseSDKImpl {
    public var appId: String
    public var environment: String
    public var options: MobilyPurchaseSDKOptions?

    private let diagnostics: MobilyPurchaseSDKDiagnostics
    private var updateTxTask: Task<Void, Never>?
    private let lifecycleManager = AppLifecycleManager()

    private var customer: MobilyCustomer?

    private var API: MobilyPurchaseAPI
    private var syncer: MobilyPurchaseSDKSyncer
    private var waiter: MobilyPurchaseSDKWaiter
    private var refundRequestManager: MobilyPurchaseRefundRequestManager

    private var isPurchasing = false
    private var productsCaches: [UUID: MobilyProduct] = [:]

    private var finishTransactionTasks: [UInt64: Task<MobilyEvent?, any Error>] = [:]
    private var _onTransactionFinishedListener: ((Transaction) -> Void)?

    public init(
        appId: String,
        apiKey: String,
        environment: String,
        options: MobilyPurchaseSDKOptions? = nil
    ) {
        _ = MobilyEnvironment.parse(environment)

        self.appId = appId
        self.environment = environment
        self.options = options

        self.diagnostics = MobilyPurchaseSDKDiagnostics(customerId: nil)
        self.API = MobilyPurchaseAPI(appId: appId, apiKey: apiKey, environment: environment, locales: getPreferredLocales(options?.locales), apiURL: options?.apiURL)
        self.waiter = MobilyPurchaseSDKWaiter(API: API, diagnostics: self.diagnostics)
        self.syncer = MobilyPurchaseSDKSyncer(API: API)
        self.refundRequestManager = MobilyPurchaseRefundRequestManager(API: API)
    }

    func uploadMonitoring(logFile: URL) async throws {
        try await self.API.uploadMonitoring(customerId: self.customer?.id, file: logFile)
    }

    func initProcedure() {
        lifecycleManager.registerCrash { _, _ in
            // TODO: This sometime crash
            Logger.fileHandle?.flush()
            self.sendDiagnostic()
        }

        // Manage out-of-app purchase
        startUpdateTransactionTask()

        Task(priority: .high) {
            // Check app bundleId, platform config & force update
            if let appPlatform = try? await API.getAppPlatform() {
                if let mobilyBundleIdentifier = appPlatform["identifier"] as? String, let iosBundleIdentifier = Bundle.main.bundleIdentifier {
                    if mobilyBundleIdentifier != iosBundleIdentifier {
                        Logger.e("Bundle identifier is configured on MobilyFlow backoffice to  \"\(mobilyBundleIdentifier)\" (actual app have \"\(iosBundleIdentifier)\"), in-app purchase may be broken.")
                    }
                }

                if let forceUpdate = appPlatform["ForceUpdate"] as? [String: Any] {
                    var continueUpdate = true
                    var shouldSendDiagnostic = false
                    while continueUpdate {
                        await withCheckedContinuation { continuation in
                            DispatchQueue.main.async {
                                Logger.d("Force Update Required for version \(forceUpdate["minVersionName"]!) (\(forceUpdate["minVersionCode"]!))")
                                let alert = UIAlertController(title: nil, message: forceUpdate["message"] as? String, preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: forceUpdate["linkText"] as? String, style: .default, handler: { _ in
                                    UIApplication.shared.open(URL(string: forceUpdate["link"] as! String)!)
                                    continuation.resume()
                                }))

                                if let topViewController = getTopViewController() {
                                    topViewController.present(alert, animated: true, completion: nil)
                                } else {
                                    // TODO: This should not happen but we allow user to use the app if we cannot present the ViewController
                                    Logger.e("ForceUpdate doesn't find a viewController to present")
                                    shouldSendDiagnostic = true
                                    continueUpdate = false
                                    continuation.resume()
                                }
                            }
                        }
                    }

                    if shouldSendDiagnostic {
                        self.sendDiagnostic()
                    }
                }
            }
        }
    }

    func setOnTransactionFinishedListener(_ callback: ((Transaction) -> Void)?) {
        self._onTransactionFinishedListener = callback
    }

    public func close() {
        self.logout()
        self.syncer.close()
        self.lifecycleManager.unregisterAll()
        self.updateTxTask?.cancel()
    }

    /* ******************************************************************* */
    /* ****************************** LOGIN ****************************** */
    /* ******************************************************************* */

    public func login(externalRef: String) async throws -> MobilyCustomer {
        Logger.d("Login customer with externalRef \(externalRef)")

        // 1. Logout previous customer
        self.logout()

        // 2. Login
        let loginResponse = try await self.API.login(externalRef: externalRef)
        let customer = MobilyCustomer.parse(loginResponse.customer)
        self.customer = customer
        diagnostics.customerId = customer.id

        try await self.syncer.login(customer: customer, jsonEntitlements: loginResponse.entitlements)

        // 3. Map transaction that are not known by the server
        let transactionToMap = await MobilyPurchaseSDKHelper.getTransactionToMap(loginResponse.platformOriginalTransactionIds)
        if !transactionToMap.isEmpty {
            do {
                try await self.API.mapTransactions(customerId: customer.id, transactions: transactionToMap)
            } catch {
                Logger.e("Map transactions error", error: error)
            }
        }

        // 4. Send Refund Requests Notifications
        if let refundRequests = loginResponse.appleRefundRequests {
            Logger.d("Refund request detected (\(refundRequests.count))")
            if refundRequests.count > 0 {
                Task(priority: .background) {
                    // TODO: We may implement a system to show refund request when App foreground after 10s, not only when login
                    await self.refundRequestManager.manageRefundRequests(refundRequests)
                }
            }
            Logger.d("Refund request done")
        }

        // 5. Send monitoring if requested
        Logger.d("haveMonitoringRequests: \(loginResponse.haveMonitoringRequests)")
        if loginResponse.haveMonitoringRequests {
            Logger.d("Monitoring request detected")
            Task(priority: .background) {
                // When monitoring is requested, send 10 days
                self.diagnostics.sendDiagnostic(sinceDays: 10)
            }
        }

        Logger.d("Customer logged successfully")
        return customer
    }

    public func logout() {
        self.customer = nil
        diagnostics.customerId = nil
        productsCaches = [:]
        self.syncer.close()
    }

    /* ******************************************************************* */
    /* **************************** PRODUCTS ***************************** */
    /* ******************************************************************* */

    public func getProducts(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilyProduct] {
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

    public func getSubscriptionGroups(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilySubscriptionGroup] {
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

    public func getSubscriptionGroupById(id: UUID) async throws -> MobilySubscriptionGroup {
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

    public func getProductFromCacheWithId(id: UUID) -> MobilyProduct? {
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

    public func getEntitlementForSubscription(subscriptionGroupId: UUID) async throws -> MobilyCustomerEntitlement? {
        return try self._cacheEntitlement(await syncer.getEntitlement(forSubscriptionGroup: subscriptionGroupId))
    }

    public func getEntitlement(productId: UUID) async throws -> MobilyCustomerEntitlement? {
        return try self._cacheEntitlement(await syncer.getEntitlement(forProductId: productId))
    }

    public func getEntitlements(productIds: [UUID]?) async throws -> [MobilyCustomerEntitlement] {
        let result = try syncer.getEntitlements(forProductIds: productIds)
        result.forEach { _ = self._cacheEntitlement($0) }
        return result
    }

    public func getExternalEntitlements() async throws -> [MobilyCustomerEntitlement] {
        let (transactionToClaim, storeAccountTransactions) = await MobilyPurchaseSDKHelper.getAllTransactionSignatures()
        var entitlements: [MobilyCustomerEntitlement] = []

        if !transactionToClaim.isEmpty {
            let jsonEntitlements = try await self.API.getCustomerExternalEntitlements(transactions: transactionToClaim, customerId: customer?.id)

            for jsonEntitlement in jsonEntitlements {
                entitlements.append(await MobilyCustomerEntitlement.parse(jsonEntitlement, storeAccountTransactions: storeAccountTransactions))
            }
        }

        return entitlements
    }

    /**
     Request transfer ownership of local device transactions.
     */
    public func requestTransferOwnership() async throws -> String {
        guard let customer = self.customer else {
            throw MobilyError.no_customer_logged
        }

        let (transactionToClaim, _) = await MobilyPurchaseSDKHelper.getAllTransactionSignatures()

        if !transactionToClaim.isEmpty {
            let requestId = try await self.API.transferOwnershipRequest(customerId: customer.id, transactions: transactionToClaim)
            let status = try await self.waiter.waitTransferOwnershipRequest(requestId: requestId)
            try await self.syncer.ensureSync(force: true)
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
     * Open a refund dialog for the last transaction on the given product.
     *
     * Pro tips: to test declined refund in sandbox, once the dialog appear, select "other" and write "REJECT" in the text box.
     */
    public func openRefundDialog(forProduct: MobilyProduct) async -> String {
        if forProduct.oneTime?.isConsumable ?? false {
            do {
                if let customer = self.customer {
                    let lastTxId = try await API.getLastTxPlatformIdForProduct(customerId: customer.id, productId: forProduct.id)
                    let result = try? await Transaction.beginRefundRequest(for: UInt64(lastTxId)!, in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
                    return (result ?? .userCancelled) == .success ? MobilyRefundDialogResult.SUCCESS : MobilyRefundDialogResult.CANCELLED
                } else {
                    return MobilyRefundDialogResult.TRANSACTION_NOT_FOUND
                }
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
    public func openRefundDialog(forTransactionId: String) async -> String {
        let result = try? await Transaction.beginRefundRequest(for: UInt64(forTransactionId)!, in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
        return (result ?? .userCancelled) == .success ? MobilyRefundDialogResult.SUCCESS : MobilyRefundDialogResult.CANCELLED
    }

    /* ******************************************************************* */
    /* **************************** PURCHASE ***************************** */
    /* ******************************************************************* */

    public func purchaseProduct(_ product: MobilyProduct, options: PurchaseOptions? = nil) async throws -> MobilyEvent {
        if isPurchasing {
            throw MobilyPurchaseError.purchase_already_pending
        }
        isPurchasing = true
        defer { isPurchasing = false }

        guard let customer = self.customer else {
            throw MobilyError.no_customer_logged
        }
        if customer.forwardNotificationEnable {
            throw MobilyPurchaseError.customer_forwarded
        }

        var event: MobilyEvent? = nil
        try await self.syncer.ensureSync()

        let internalPurchaseOptions = try await MobilyPurchaseSDKHelper.createPurchaseOptions(syncer: syncer, API: API, customerId: customer.id, product: product, options: options)

        if internalPurchaseOptions.isRedeemURL() {
            var error: MobilyPurchaseError?
            let offerCodeLifecycleManager = AppLifecycleManager()
            let knownTransactionIdsForSku = await MobilyPurchaseSDKHelper.getKnownTransactionIdsForSku(product.ios_sku)
            let openTime = Date().timeIntervalSince1970
            let redeemURL = internalPurchaseOptions.getRedeemUrl()

            await withCheckedContinuation { continuation in
                offerCodeLifecycleManager.registerDidBecomeActive {
                    Logger.d("[purchaseProduct] didBecomeActive")
                    offerCodeLifecycleManager.unregisterAll()

                    Task(priority: .high) {
                        let startTime = Date().timeIntervalSince1970
                        if openTime + 8 > startTime {
                            // Less that 8s outside of the app, we consider the user doesn't buy the product as he will not have the time to execute the whole purchase flow
                            Logger.w("[purchaseProduct] Less than 8s outside of the app -> consider purchase canceled (\(startTime - openTime)s)")
                            error = MobilyPurchaseError.user_canceled
                            continuation.resume()
                            return
                        }

                        // Pull Transaction in a loop as it's faster than waiting Transaction.updates
                        while true {
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                            if startTime + 30 < Date().timeIntervalSince1970 {
                                Logger.e("[purchaseProduct] Can't see offer code transaction after 30s, consider purchase canceled")
                                error = MobilyPurchaseError.user_canceled
                                continuation.resume()
                                return
                            }

                            for await signedTx in Transaction.currentEntitlements {
                                if case .verified(let transaction) = signedTx {
                                    if transaction.productID == product.ios_sku && !knownTransactionIdsForSku.contains(transaction.id) {
                                        Logger.d("[purchaseProduct] Receive Offer Code Transaction: \(transaction.id)")
                                        event = try await self.finishTransaction(signedTx: signedTx, downgradeToProductId: nil)
                                        continuation.resume()
                                        return
                                    }
                                }
                            }
                        }
                    }
                }

                Task(priority: .high) { @MainActor in
                    await UIApplication.shared.open(redeemURL)
                }
            }

            if let error = error {
                throw error
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
                        try? await API.forceWebhook(transactionId: transaction.id, productId: product.id, isSandbox: isSandboxTransaction(transaction: transaction))
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
        if case .verified(let transaction) = signedTx {
            Logger.d("Finish transaction: \(transaction.id) (\(transaction.productID))")

            if let existingTask = self.finishTransactionTasks.removeValue(forKey: transaction.id) {
                // Avoid multiple parallel call to finishTransaction caused by the updateTxTask
                Logger.d("Finish transaction already pending wait for previous call")
                return try await existingTask.value
            } else {
                let newTask = Task(priority: .high) {
                    var event: MobilyEvent?

                    self._onTransactionFinishedListener?(transaction)
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
                        try await syncer.ensureSync(force: true)
                    }
                    return event
                }
                self.finishTransactionTasks[transaction.id] = newTask
                defer { self.finishTransactionTasks.removeValue(forKey: transaction.id) }
                return try await newTask.value
            }
        }
        return nil
    }

    /* *********************************************************** */
    /* *********************** DIAGNOSTICS *********************** */
    /* *********************************************************** */

    public func sendDiagnostic() {
        diagnostics.sendDiagnostic()
    }

    /* ************************************************************** */
    /* *************************** OTHERS *************************** */
    /* ************************************************************** */

    // TODO: onStorefrontChange
    public func getStoreCountry() async -> String? {
        if let alpha3 = (await Storefront.current)?.countryCode {
            return CountryCodes.alpha3ToAlpha2(alpha3)
        }
        return nil
    }

    public func isForwardingEnable(externalRef: String) async throws -> Bool {
        return try await API.isForwardingEnableByExternalRef(externalRef: externalRef)
    }

    public func getCustomer() async throws -> MobilyCustomer? {
        return self.customer
    }
}
