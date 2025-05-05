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
     * upgradeOrDowngrade is 0 for purchase, -1 for downgrade, 1 for upgrade (subscription only).
     */
    func waitWebhook(transaction: Transaction, product: MobilyProduct, upgradeOrDowngrade: Int) async throws -> WebhookStatus {
        let isSandbox: Bool

        if #available(iOS 16.0, *) {
            isSandbox = transaction.environment != .production
        } else {
            // This is not 100% reliable: it can produce false negative, but the worst behavior in that case is
            // error during waiting but in Sandbox only
            isSandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        }

        Logger.d("Wait webhook for \(transaction.id) (upgradeOrDowngrade: \(upgradeOrDowngrade))")

        if upgradeOrDowngrade >= 0 {
            try? await API.forceWebhook(transactionId: transaction.id, type: upgradeOrDowngrade > 0 ? "upgrade" : "purchase", isSandbox: isSandbox)
        }

        var result = WebhookStatus.pending
        let startTime = Date().timeIntervalSince1970
        var retry = 0

        while result == .pending {
            result = try await self.API.getWebhookStatus(transactionId: upgradeOrDowngrade < 0 ? transaction.originalID : transaction.id, isSandbox: isSandbox, isDowngrade: upgradeOrDowngrade < 0)

            if result == .pending {
                // Exit the wait function after 1 minute
                if startTime + 60 < Date().timeIntervalSince1970 {
                    Logger.e("Webhook still pending after 1 minutes (The user has probably paid without being credited)")
                    diagnostics.sendDiagnostic()
                    throw MobilyPurchaseError.webhook_not_processed
                }

                usleep(calcWaitWebhookTime(retry)) // 2 seconds
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

        if result == .error {
            throw MobilyTransferOwnershipError.webhook_failed
        }

        return result
    }
}
