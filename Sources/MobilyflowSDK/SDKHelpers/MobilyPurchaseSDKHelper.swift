//
//  MobilyPurchaseSDKHelper.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import StoreKit

class MobilyPurchaseSDKHelper {
    static func getKnownTransactionIdsForSku(_ sku: String) async -> [UInt64] {
        var knownTxIds: [UInt64] = []

        for await signedTx in Transaction.currentEntitlements {
            if case .verified(let transaction) = signedTx {
                if transaction.productID == sku {
                    if !knownTxIds.contains(transaction.id) {
                        knownTxIds.append(transaction.id)
                    }
                }
            }
        }

        return knownTxIds
    }

    static func getTransactionToMap(_ knownOriginalTransactionIds: [String]) async -> [String] {
        var knownOriginalTxIds: [String] = knownOriginalTransactionIds
        var transactionToMap: [String] = []

        for await signedTx in Transaction.currentEntitlements {
            if case .verified(let transaction) = signedTx {
                let originalTxId = String(transaction.originalID)

                if !knownOriginalTxIds.contains(originalTxId) {
                    transactionToMap.append(signedTx.jwsRepresentation)

                    // Avoid sending duplicate originalTxId that can happen when subscription renew
                    knownOriginalTxIds.append(originalTxId)
                }
            }
        }

        return transactionToMap
    }

    static func getAllTransactionSignatures() async -> ([String], [UInt64: Transaction]) {
        var storeAccountTransactions: [UInt64: Transaction] = [:]

        var knownOriginalTxIds: [String] = []
        var transactionSignatures: [String] = []

        for await signedTx in Transaction.currentEntitlements {
            if case .verified(let transaction) = signedTx {
                storeAccountTransactions[transaction.originalID] = transaction

                let originalTxId = String(transaction.originalID)

                // Avoid sending duplicate originalTxId that can happen when subscription renew
                if !knownOriginalTxIds.contains(originalTxId) {
                    transactionSignatures.append(signedTx.jwsRepresentation)
                    knownOriginalTxIds.append(originalTxId)
                }
            }
        }

        return (transactionSignatures, storeAccountTransactions)
    }

    static func isEligibleForPromotionnalOffer() async -> Bool {
        // TODO: We should find a way to force it to false in production for testing purpose
        if #available(iOS 17.4, *) {
            for await signedTx in Transaction.all {
                switch signedTx {
                case .verified(let transaction):
                    if transaction.productType == .autoRenewable {
                        return true
                    }
                case .unverified:
                    break
                }
            }
        }
        return false
    }

    /**
     Create the set of PurchaseOption to start the billing flow.
     It return an InternalPurchaseOptions that cas be either product with options or redeemURL
     */
    static func createPurchaseOptions(
        syncer: MobilyPurchaseSDKSyncer, API: MobilyPurchaseAPI,
        customerId: UUID, product: MobilyProduct, options: PurchaseOptions?
    ) async throws -> InternalPurchaseOptions {
        guard let iosProduct = MobilyPurchaseRegistry.getIOSProduct(product.ios_sku) else {
            // Probably store_unavavaible but no way to check...
            throw MobilyPurchaseError.product_unavailable
        }

        var isDowngrade = false
        var redeemUrl: URL?
        var iosOffer: Product.SubscriptionOffer?

        if product.type == ProductType.SUBSCRIPTION && options?.offer != nil {
            if options!.offer!.type == MobilyProductOfferType.FREE_TRIAL {
                iosOffer = iosProduct.subscription!.introductoryOffer
            } else if options!.offer!.ios_offerId != nil {
                if await isEligibleForPromotionnalOffer() {
                    iosOffer = MobilyPurchaseRegistry.getIOSOffer(product.ios_sku, offerId: options!.offer!.ios_offerId!)

                    if iosOffer == nil {
                        throw MobilyPurchaseError.product_unavailable
                    }
                } else {
                    // Promotional Offer not available, use offerCode instead
                    do {
                        let offerCode = try await API.appleOfferCode(customerId: customerId, offerId: options!.offer!.id)
                        redeemUrl = URL(string: offerCode["redeemUrl"] as! String)!
                    } catch {
                        Logger.e("Can't get appleOfferCode", error: error)
                    }
                }
            }
        }

        // Manage already purchased
        if product.type == ProductType.ONE_TIME {
            if !product.oneTime!.isConsumable {
                let entitlement = try! await syncer.getEntitlement(forProductId: product.id)
                if entitlement != nil {
                    throw MobilyPurchaseError.already_purchased
                } else {
                    let storeAccountTransaction = syncer.getStoreAccountTransaction(forIosSku: product.ios_sku)

                    if storeAccountTransaction != nil {
                        // Another customer is already entitled to this product on the same store account
                        throw MobilyPurchaseError.store_account_already_have_purchase
                    }
                }
            }
        } else {
            let entitlement = try! await syncer.getEntitlement(forSubscriptionGroup: product.subscription!.groupId)
            let storeAccountTransaction = syncer.getStoreAccountTransaction(forIosSubscriptionGroup: product.subscription!.ios_groupId)

            Logger.d("[createPurchaseOptions] entitlement = \(entitlement?.Product.identifier ?? "null")")

            if entitlement != nil {
                if !entitlement!.Subscription!.isManagedByThisStoreAccount {
                    // Customer subscribe under another store account
                    throw MobilyPurchaseError.not_managed_by_this_store_account
                }

                // If auto-renew is disabled, allow re-purchase in app
                if entitlement!.Subscription!.autoRenewEnable {
                    let currentRenewProduct = entitlement!.Subscription!.RenewProduct ?? entitlement!.Product
                    let currentRenewSku = currentRenewProduct.ios_sku

                    if currentRenewSku == product.ios_sku {
                        if entitlement!.Product.ios_sku == product.ios_sku {
                            throw MobilyPurchaseError.already_purchased
                        } else {
                            throw MobilyPurchaseError.renew_already_on_this_plan
                        }
                    }
                }

                if product.subscription!.groupLevel >= entitlement!.Product.subscription!.groupLevel {
                    isDowngrade = true
                }
            } else {
                if storeAccountTransaction != nil {
                    // Another customer is already entitled to this product on the same store account
                    if storeAccountTransaction!.expirationDate == nil || storeAccountTransaction!.expirationDate!.timeIntervalSinceNow > 0 {
                        throw MobilyPurchaseError.store_account_already_have_purchase
                    }
                }
            }
        }

        if redeemUrl != nil {
            return InternalPurchaseOptions(redeemUrl: redeemUrl!, isDowngrade: isDowngrade)
        }

        var iosOptions = Set<Product.PurchaseOption>()
        iosOptions.insert(Product.PurchaseOption.appAccountToken(customerId))

        iosOptions.insert(Product.PurchaseOption.onStorefrontChange(shouldContinuePurchase: { _ in
            // TODO: In case storefront change, notify developer to refetch product
            true
        }))

        if #available(iOS 17.4, *) {
            if options?.offer?.ios_offerId != nil && iosOffer != nil {
                let signature = try await API.signOffer(customerId: customerId, offerId: options!.offer!.id.uuidString)
                iosOptions.insert(Product.PurchaseOption.promotionalOffer(offerID: options!.offer!.ios_offerId!, signature: signature))
            }
        }

        if options?.quantity != nil {
            iosOptions.insert(Product.PurchaseOption.quantity(options!.quantity!))
        }

        return InternalPurchaseOptions(product: iosProduct, isDowngrade: isDowngrade, options: iosOptions)
    }

    static func isTransactionFinished(id: UInt64) async -> Bool {
        for await verificationResult in Transaction.unfinished {
            if case .verified(let tx) = verificationResult {
                if tx.id == id {
                    return false
                }
            }
        }
        return true
    }
}
