//
//  MobilyPurchaseSDK.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

@objc public class MobilyPurchaseSDK: NSObject {
    let appId: String
    let API: MobilyPurchaseAPI

    let environment: MobilyEnvironment
    var customer: MobilyCustomer?

    var isStoreAvailable = true

    private var syncer: MobilyPurchaseSDKSyncer
    private let waiter: MobilyPurchaseSDKWaiter
    private let diagnostics: MobilyPurchaseSDKDiagnostics

    private var updateTxTask: Task<Void, Never>?
    private let purchaseExecutor = AsyncDispatchQueue(label: "mobilyflow-purchase")

    private let lifecycleManager = AppLifecycleManager()

    @objc public init(
        appId: String,
        apiKey: String,
        environment: MobilyEnvironment,
        options: MobilyPurchaseSDKOptions? = nil
    ) {
        self.appId = appId
        self.environment = environment
        self.API = MobilyPurchaseAPI(appId: appId, apiKey: apiKey, environment: environment, locales: getPreferredLocales(options?.locales), apiURL: options?.apiURL)
        self.diagnostics = MobilyPurchaseSDKDiagnostics(customerId: nil)
        self.waiter = MobilyPurchaseSDKWaiter(API: API, diagnostics: self.diagnostics)
        self.syncer = MobilyPurchaseSDKSyncer(API: self.API)

        super.init()

        Monitoring.initialize(tag: "MobilyFlow", allowLogging: options?.debug ?? false) { logFile in
            try await self.API.uploadMonitoring(customerId: self.customer?.id, file: logFile)
        }

        lifecycleManager.registerCrash { _, _ in
            Logger.fileHandle?.flush()
            self.sendDiagnotic()
        }
    }

    @objc public func close() {
        self.customer = nil
        diagnostics.customerId = nil
        self.updateTxTask?.cancel()
        self.syncer.close()
    }

    deinit {
        close()
    }

    /* ******************************************************************* */
    /* ****************************** LOGIN ****************************** */
    /* ******************************************************************* */

    @objc public func login(externalRef: String) async throws -> MobilyCustomer {
        // 1. Login
        let loginResponse = try await self.API.login(externalRef: externalRef)
        self.customer = MobilyCustomer.parse(jsonCustomer: loginResponse.customer, isForwardingEnable: loginResponse.isForwardingEnable)
        diagnostics.customerId = self.customer?.id
        try await self.syncer.login(customerId: customer?.id, jsonEntitlements: loginResponse.entitlements)

        // 2. Sync
        try await syncer.ensureSync()

        // 3. Manage out-of-app purchase
        startUpdateTransactionTask()

        // 4. Map transaction that are not known by the server
        let transactionToMap = await MobilyPurchaseSDKHelper.getTransactionToMap(loginResponse.platformOriginalTransactionIds)
        if !transactionToMap.isEmpty {
            do {
                try await self.API.mapTransactions(customerId: self.customer!.id, transactions: transactionToMap)
            } catch {
                Logger.e("Map transactions error", error: error)
            }
        }

        return self.customer!
    }

    /* ******************************************************************* */
    /* **************************** PRODUCTS ***************************** */
    /* ******************************************************************* */

    @objc public func getProducts(identifiers: [String]?, onlyAvailable: Bool) async throws -> [MobilyProduct] {
        try await syncer.ensureSync()

        // 1. Get product from Mobily API
        let jsonProducts = try await self.API.getProducts(identifiers: identifiers)

        // 2. Get product from App Store
        let iosIdentifiers = jsonProducts.map { p in p["ios_sku"]! } as! [String]
        await MobilyPurchaseRegistry.registerIOSProductSkus(iosIdentifiers)

        // 3. Parse to MobilyProduct
        var mobilyProducts: [MobilyProduct] = []

        for jsonProduct in jsonProducts {
            let mobilyProduct = await MobilyProduct.parse(jsonProduct: jsonProduct)
            if !onlyAvailable || mobilyProduct.status == .available {
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
            (group["Products"] as! [[String: Any]]).map { product in product["ios_sku"] as! String }
        }
        await MobilyPurchaseRegistry.registerIOSProductSkus(iosIdentifiers)

        // 3. Parse to MobilySubscriptionGroup
        var groups: [MobilySubscriptionGroup] = []

        for jsonGroup in jsonGroups {
            let mobilyGroup = await MobilySubscriptionGroup.parse(jsonGroup: jsonGroup, onlyAvailableProducts: onlyAvailable)

            if !onlyAvailable || mobilyGroup.products.count > 0 {
                groups.append(mobilyGroup)
            }
        }

        return groups
    }

    /* ******************************************************************* */
    /* ************************** ENTITLEMENTS *************************** */
    /* ******************************************************************* */

    @objc public func getEntitlementForSubscription(subscriptionGroupId: String) async throws -> MobilyCustomerEntitlement? {
        return try await syncer.getEntitlement(forSubscriptionGroup: subscriptionGroupId)
    }

    @objc public func getEntitlement(productId: String) async throws -> MobilyCustomerEntitlement? {
        return try await syncer.getEntitlement(forProductId: productId)
    }

    @objc public func getEntitlements(productIds: [String]) async throws -> [MobilyCustomerEntitlement] {
        return try syncer.getEntitlements(forProductIds: productIds)
    }

    /**
     Request transfer ownership of local device transactions.
     */
    @objc public func requestTransferOwnership() async throws -> TransferOwnershipStatus {
        if customer == nil {
            throw MobilyError.no_customer_logged
        }

        let transactionToClaim = await MobilyPurchaseSDKHelper.getAllTransactionSignatures()

        if !transactionToClaim.isEmpty {
            let requestId = try await self.API.transferOwnershipRequest(customerId: self.customer!.id, transactions: transactionToClaim)
            let status = try await self.waiter.waitTransferOwnershipRequest(requestId: requestId)
            Logger.d("Request ownership transfer complete with status \(status)")
            return status
        } else {
            return .acknowledged
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
    @objc public func openRefundDialog(product: MobilyProduct) async -> RefundDialogResult {
        for await signedTx in Transaction.currentEntitlements {
            if case .verified(let transaction) = signedTx {
                if transaction.productID == product.ios_sku {
                    let result = try? await Transaction.beginRefundRequest(for: transaction.id, in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
                    return (result ?? .userCancelled) == .success ? .success : .cancelled
                }
            }
        }
        return .transaction_not_found
    }

    /* ******************************************************************* */
    /* **************************** PURCHASE ***************************** */
    /* ******************************************************************* */

    @objc public func purchaseProduct(_ product: MobilyProduct, options: PurchaseOptions? = nil) async throws -> WebhookStatus {
        var resultStatus: WebhookStatus = .error

        try await purchaseExecutor.executeOrFallback({
            if self.customer == nil {
                throw MobilyError.no_customer_logged
            }

            let (iosProduct, purchaseOptions, upgradeOrDowngrade) = try await MobilyPurchaseSDKHelper.createPurchaseOptions(syncer: self.syncer, API: self.API, customerId: self.customer!.id, product: product, options: options)

            let purchaseResult: Product.PurchaseResult
            do {
                purchaseResult = try await iosProduct.purchase(options: purchaseOptions)
            } catch StoreKitError.userCancelled {
                throw MobilyPurchaseError.user_canceled
            } catch let error as Product.PurchaseError {
                Logger.e("[purchaseProduct] PurchaseError", error: error)
                self.sendDiagnotic()
                throw MobilyPurchaseError.product_unavailable
            } catch StoreKitError.notAvailableInStorefront {
                Logger.e("[purchaseProduct] Product notAvailableInStorefront")
                self.sendDiagnotic()
                throw MobilyPurchaseError.product_unavailable
            } catch StoreKitError.networkError(let url) {
                Logger.e("[purchaseProduct] Network error: \(url)")
                throw MobilyPurchaseError.network_unavailable
            } catch StoreKitError.systemError(let error) {
                Logger.e("[purchaseProduct] systemError", error: error)
                throw MobilyError.store_unavailable
            } /* catch StoreKitError.unknown {
                 /*
                   There is a tricky case:
                    - User buy the subscritpion
                    - He disable the auto-renew
                    - He re-open the app and try to re-purchase (his subscription is still active, but this should re-enable auto-renew)
                    - In that case the Product.purchase method throw StoreKitError.unknown but the subscription is well re-enable (at least in sandbox, maybe it work in production).

                  The error: Received error that does not have a corresponding StoreKit Error: Error Domain=ASDErrorDomain Code=825 "No transactions in response" UserInfo={NSDebugDescription=No transactions in response}

                   Check this post: https://developer.apple.com/forums/thread/770662

                  This case is not managed but is ready to be use by uncommenting things related to isSusbscriptionReEnable
                  */
                  if isSusbscriptionReEnable {
                      Logger.d("Subscription re-enable fix -> Ignore error")
                      return
                  } else {
                      Logger.d("Other error = unknown")
                      throw MobilyPurchaseError.failed
                  }
             } */
            catch {
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
                    await self.finishTransaction(signedTx: signedTx)
                    resultStatus = try await self.waiter.waitWebhook(transaction: transaction, product: product, upgradeOrDowngrade: upgradeOrDowngrade)
                    try await self.syncer.ensureSync(force: true)
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
        }, fallback: {
            throw MobilyPurchaseError.purchase_already_pending
        })

        return resultStatus
    }

    /* ******************************************************************* */
    /* ****************** UPDATE TRANSACTION LISTENER ****************** */
    /* ******************************************************************* */

    private func startUpdateTransactionTask() {
        self.updateTxTask?.cancel()
        self.updateTxTask = Task(priority: .background) {
            do {
                try await syncer.ensureSync()
            } catch {
                Logger.e("Error in sync, handleUpdate later...", error: error)
                return
            }

            // Note: `Transaction.updates` never returns and continuously send updates on transaction during the whole lifetime of the app
            for await signedTx in Transaction.updates {
                if case .verified(let tx) = signedTx {
                    if !(await MobilyPurchaseSDKHelper.isTransactionFinished(id: tx.id)) {
                        Logger.d("[startUpdateTransactionTask] finishTransaction")
                        await self.finishTransaction(signedTx: signedTx)
                    }
                }
            }
            Logger.d("End update task")
        }
    }

    private func finishTransaction(signedTx: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = signedTx {
            Logger.d("Finish transaction: \(transaction.id)")
            await transaction.finish()

            if let customerId = customer?.id {
                do {
                    try await API.mapTransactions(customerId: customerId, transactions: [signedTx.jwsRepresentation])
                } catch {
                    Logger.e("Map transaction error", error: error)
                }
            }
        }
    }

    /* *********************************************************** */
    /* *********************** DIAGNOSTICS *********************** */
    /* *********************************************************** */

    @objc public func sendDiagnotic() {
        diagnostics.sendDiagnostic()
    }

    /* ************************************************************** */
    /* *************************** OTHERS *************************** */
    /* ************************************************************** */

    // TODO: onStorefrontChange
    @objc public func getStoreCountry() async -> String? {
        return (await Storefront.current)?.countryCode
    }

    @objc public func isForwardingEnable(externalRef: String) async throws -> Bool {
        return try await API.isForwardingEnable(externalRef: externalRef)
    }
}
