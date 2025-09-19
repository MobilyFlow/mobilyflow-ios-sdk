//
//  MobilyPurchaseSDKDiagnostics.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 28/01/2025.
//

import Foundation
import StoreKit

class MobilyPurchaseSDKDiagnostics {
    var customerId: UUID?

    init(customerId: UUID?) {
        self.customerId = customerId
    }

    func sendDiagnostic() {
        Task(priority: .background) {
            // 1. Write maximum info we can get
            let bundleID = Bundle.main.bundleIdentifier
            let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let versionCode = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

            Logger.d("App \(bundleID ?? "nil") version \(versionName ?? "nil") (\(versionCode ?? "nil"))")

            if customerId == nil {
                Logger.d("Not logged to a customer...")
            } else {
                Logger.d("Logged with customer \(customerId!.uuidString.lowercased())")
            }

            for await signedTx in Transaction.currentEntitlements {
                if case .verified(let transaction) = signedTx {
                    Logger.d("Purchase \(transaction.productType.rawValue): productId: \(transaction.productID), transactionId \(transaction.id), originalId: \(transaction.originalID)")
                }
            }

            // 2. Send diagnostics
            try? Monitoring.exportDiagnostic(sinceDays: 1)
        }
    }
}
