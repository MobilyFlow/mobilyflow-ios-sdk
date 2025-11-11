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

    func sendDiagnostic(sinceDays: Int = 1) {
        Task(priority: .background) {
            // 1. Write maximum info we can get
            Logger.d("[Device Info] OS = \(DeviceInfo.getOSName()) \(DeviceInfo.getOSVersion())")
            Logger.d("[Device Info] deviceModel = \(DeviceInfo.getDeviceModelName())")
            Logger.d("[Device Info] appBundleIdentifier = \(DeviceInfo.getAppBundleIdentifier())")
            Logger.d("[Device Info] appVersion = \(DeviceInfo.getAppVersionName()) (\(DeviceInfo.getAppBuildNumber()))")

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
            try? Monitoring.exportDiagnostic(sinceDays: sinceDays)
        }
    }
}
