//
//  MobilyPurchaseSDKHelper.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import StoreKit

class MobilyPurchaseSDKHelper {
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

    static func getAllTransactionSignatures() async -> [String] {
        var knownOriginalTxIds: [String] = []
        var transactionSignatures: [String] = []

        for await signedTx in Transaction.currentEntitlements {
            if case .verified(let transaction) = signedTx {
                let originalTxId = String(transaction.originalID)

                // Avoid sending duplicate originalTxId that can happen when subscription renew
                if !knownOriginalTxIds.contains(originalTxId) {
                    transactionSignatures.append(signedTx.jwsRepresentation)
                    knownOriginalTxIds.append(originalTxId)
                }
            }
        }

        return transactionSignatures
    }

    /**
     Create the set of PurchaseOption to start the billing flow.
     It return a tuple (iosProduct, Set<Product.PurchaseOption>, upgradeOrDowngrade)
     */
    static func createPurchaseOptions(
        syncer: MobilyPurchaseSDKSyncer, API: MobilyPurchaseAPI,
        customerId: UUID, product: MobilyProduct, options: PurchaseOptions?
    ) async throws -> (Product, Set<Product.PurchaseOption>, Int) {
        let iosProduct = MobilyPurchaseRegistry.getIOSProduct(product.ios_sku)
        if iosProduct == nil {
            throw MobilyPurchaseError.product_unavailable
        }

        var iosOffer: Product.SubscriptionOffer?
        if product.type == .subscription && options?.offer != nil {
            if options!.offer!.isFreeTrial {
                iosOffer = iosProduct!.subscription!.introductoryOffer
            } else if options!.offer!.ios_offerId != nil {
                iosOffer = MobilyPurchaseRegistry.getIOSOffer(product.ios_sku, offerId: options!.offer!.ios_offerId!)

                if iosOffer == nil {
                    throw MobilyPurchaseError.product_unavailable
                }
            }
        }

        // Manage already purchased
        var upgradeOrDowngrade = 0
        if product.type == .one_time {
            if !product.oneTimeProduct!.isConsumable {
                let entitlement = try! syncer.getEntitlement(forProductId: product.id)
                if entitlement != nil {
                    throw MobilyPurchaseError.already_purchased
                } else {
                    let storeAccountTransaction = syncer.getStoreAccountTransaction(forProduct: product)

                    if storeAccountTransaction != nil {
                        // Another customer is already entitled to this product on the same store account
                        throw MobilyPurchaseError.store_account_already_have_purchase
                    }
                }
            }
        } else {
            let entitlement = product.subscriptionProduct!.subscriptionGroupId != nil ?
                try! syncer.getEntitlement(forSubscriptionGroup: product.subscriptionProduct!.subscriptionGroupId!) :
                try! syncer.getEntitlement(forProductId: product.id)

            let storeAccountTransaction = product.subscriptionProduct!.subscriptionGroupId != nil ?
                syncer.getStoreAccountTransaction(forSubscriptionGroup: product.subscriptionProduct!.subscriptionGroupId!) :
                syncer.getStoreAccountTransaction(forProduct: product)

            if entitlement != nil {
                if !entitlement!.subscription!.isManagedByThisStoreAccount {
                    // Customer subscribe under another store account
                    throw MobilyPurchaseError.not_managed_by_this_store_account
                }

                let renewalInfo = await getRenewalInfo(tx: storeAccountTransaction)
                if renewalInfo != nil {
                    let renewalIosSku = renewalInfo!.autoRenewPreference

                    if renewalIosSku == product.ios_sku {
                        if entitlement?.product.ios_sku == product.ios_sku {
                            throw MobilyPurchaseError.already_purchased
                        } else {
                            throw MobilyPurchaseError.renew_already_on_this_plan
                        }
                    } else {
                        upgradeOrDowngrade = product.subscriptionProduct!.groupLevel < entitlement!.product.subscriptionProduct!.groupLevel ? 1 : -1
                    }
                }
            } else {
                if storeAccountTransaction != nil {
                    // Another customer is already entitled to this product on the same store account
                    throw MobilyPurchaseError.store_account_already_have_purchase
                }
            }

            // TODO: If subscription is owned but autoRenew disable, allow to re-enable autoRenew
            /* let entitlement = syncer!.getEntitlement(productId: product.id)
             if entitlement != nil {
                 let currentTx = await syncer!.getTransactionForOriginalTxId(originalTxId: UInt64(entitlement!.platformOriginalTransactionId!)!)
                  if currentTx != nil {
                      let subStatus = await currentTx!.subscriptionStatus
                      if subStatus != nil, case .verified(let verifiedSub) = subStatus!.renewalInfo {
                          if verifiedSub.willAutoRenew {
                              throw MobilyPurchaseError.already_purchased
                          } else {
                              isSusbscriptionReEnable = true
                          }
                      }
                  }
             } */
        }

        var iosOptions = Set<Product.PurchaseOption>()
        iosOptions.insert(Product.PurchaseOption.appAccountToken(customerId))

        iosOptions.insert(Product.PurchaseOption.onStorefrontChange(shouldContinuePurchase: { _ in
            // In case storefront change, fetch product again
            Task(priority: .high) { [weak syncer] in
                try! await syncer?.syncProduct()
                // TODO: Add event to notify developer to refetch product
            }
            return true
        }))

        if #available(iOS 17.4, *) {
            if options?.offer?.ios_offerId != nil {
                let signature = try await API.signOffer(customerId: customerId, offerId: options!.offer!.id!)
                iosOptions.insert(Product.PurchaseOption.promotionalOffer(offerID: options!.offer!.ios_offerId!, signature: signature))
            }
        }

        if options?.quantity != nil {
            iosOptions.insert(Product.PurchaseOption.quantity(options!.quantity!))
        }

        return (iosProduct!, iosOptions, upgradeOrDowngrade)
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
