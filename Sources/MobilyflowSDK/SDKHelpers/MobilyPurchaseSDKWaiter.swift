//
//  MobilyPurchaseSDKWaiter.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 24/01/2025.
//

import Foundation
import StoreKit

class MobilyPurchaseSDKWaiter {
    private var API: MobilyPurchaseAPI
    private var diagnostics: MobilyPurchaseSDKDiagnostics

    init(API: MobilyPurchaseAPI, diagnostics: MobilyPurchaseSDKDiagnostics) {
        self.API = API
        self.diagnostics = diagnostics
    }

    /**
     * Wait the webhook to be processed.
     *
     *  - transaction: the transaction that refer to the webhook
     *  - downgradeToProductId: in case of a downgrade, this is the MobilyFlow productId of the renew product
     */
    func waitPurchaseWebhook(signedTx: VerificationResult<Transaction>, downgradeToProductId: UUID? = nil) async throws -> MobilyWebhookResult {
        guard case .verified(let transaction) = signedTx else {
            throw MobilyError.unknown_error
        }

        if transaction.purchaseDate > Date().addingTimeInterval(60.0) {
            /*
             In case of a RENEW, it can happen that the purchaseDate is in the future.
             We notice Transaction.updates can sometime return a RENEW 3 days before it was effective,
             this mean the backend won't receive RENEW info until 3 days.
             In that case waiting for webhook will always result in "Webhook still pending after 1 minutes"
             */
            Logger.w("finishTransaction with future purchaseDate -> skip waitWebhook")
            return MobilyWebhookResult(status: MobilyWebhookStatus.SUCCESS, event: nil)
        } else if transaction.purchaseDate < Date().addingTimeInterval(-7.0 * 24.0 * 3600.0) {
            // In case of a PURCHASE older than 1 week, assume the webhook is already done.
            Logger.w("finishTransaction with old purchaseDate -> skip waitWebhook")
            return MobilyWebhookResult(status: MobilyWebhookStatus.SUCCESS, event: nil)
        }

        let isSandbox = isSandboxTransaction(transaction: transaction)

        Logger.d("Wait webhook for \(transaction.id) (original: \(transaction.originalID))")

        let startTime = Date().timeIntervalSince1970
        var retry = 0
        var result = MobilyWebhookResult(status: MobilyWebhookStatus.PENDING, event: nil)

        while result.status == MobilyWebhookStatus.PENDING {
            result = try await self.API.getWebhookResult(
                signedTransaction: signedTx.jwsRepresentation,
                transactionId: transaction.id,
                isSandbox: isSandbox,
                // Remove 5s to the signed date for safety
                downgradeToProductId: downgradeToProductId,
                downgradeAfterDate: downgradeToProductId == nil ? nil : transaction.signedDate.addingTimeInterval(-5.0)
            )

            if result.status == MobilyWebhookStatus.PENDING {
                // Exit the wait function after 1 minute
                if startTime + 60 < Date().timeIntervalSince1970 {
                    Logger.e("Webhook still pending after 1 minutes (The user has probably paid without being credited)")
                    diagnostics.sendDiagnostic()
                    throw MobilyPurchaseError.webhook_not_processed
                }

                usleep(calcWaitWebhookTime(retry))
                retry += 1
            }
        }

        Logger.d("Webhook wait completed (\(result.status))")

        if result.status == MobilyWebhookStatus.ERROR {
            throw MobilyPurchaseError.webhook_failed
        }

        return result
    }

    /**
     * Wait the transfer-request to be processed.
     */
    func waitTransferOwnershipRequest(requestId: String) async throws -> String {
        var result = MobilyTransferOwnershipStatus.PENDING
        let startTime = Date().timeIntervalSince1970
        var retry = 0

        while result == MobilyTransferOwnershipStatus.PENDING {
            result = try await self.API.getTransferRequestStatus(requestId: requestId)

            if result == MobilyTransferOwnershipStatus.PENDING {
                // Exit the wait function after 1 minute
                if startTime + 60 < Date().timeIntervalSince1970 {
                    throw MobilyTransferOwnershipError.webhook_not_processed
                }

                usleep(calcWaitWebhookTime(retry)) // 2 seconds
                retry += 1
            }
        }
        Logger.d("Transfer Ownership wait completed (\(result))")

        return result
    }
}
