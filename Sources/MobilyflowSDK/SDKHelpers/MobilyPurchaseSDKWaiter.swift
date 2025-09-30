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
    func waitWebhook(transaction: Transaction, downgradeToProductId: String? = nil) async throws -> WebhookStatus {
        let isSandbox = isSandboxTransaction(transaction: transaction)

        Logger.d("Wait webhook for \(transaction.id) (original: \(transaction.originalID))")

        var result = WebhookStatus.pending
        let startTime = Date().timeIntervalSince1970
        var retry = 0

        while result == .pending {
            result = try await self.API.getWebhookStatus(
                transactionOriginalId: transaction.originalID,
                transactionId: transaction.id,
                isSandbox: isSandbox,
                // Remove 5s to the signed date for safety
                downgradeToProductId: downgradeToProductId,
                downgradeAfterDate: downgradeToProductId == nil ? nil : transaction.signedDate.addingTimeInterval(-5.0)
            )

            if result == .pending {
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

        Logger.d("Webhook wait completed (\(result))")

        if result == .error {
            throw MobilyPurchaseError.webhook_failed
        }

        return result
    }

    /**
     * Wait the transfer-request to be processed.
     */
    func waitTransferOwnershipRequest(requestId: String) async throws -> TransferOwnershipStatus {
        var result = TransferOwnershipStatus.pending
        let startTime = Date().timeIntervalSince1970
        var retry = 0

        while result == .pending {
            result = try await self.API.getTransferRequestStatus(requestId: requestId)

            if result == .pending {
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
