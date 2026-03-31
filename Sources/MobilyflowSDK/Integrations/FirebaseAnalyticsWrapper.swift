//
//  FirebaseAnalyticsWrapper.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 30/03/2026.
//

import Foundation
import StoreKit

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Utility class to log transactions to Firebase Analytics if available in the host app.
class FirebaseAnalyticsWrapper {
    private static var isInitialized = false
    private static var isAvailable = false

    /// Initialize and cache the Analytics class if available
    private static func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        #if canImport(FirebaseAnalytics)
        isAvailable = true
        #endif

        if isAvailable {
            print("[MobilyFlow] Firebase Analytics detected")
        }
    }

    /// Check if Firebase Analytics is available in the host app
    static func isAnalyticsAvailable() -> Bool {
        initialize()
        return isAvailable
    }

    /// Log a StoreKit transaction to Firebase Analytics.
    /// No-op if Firebase Analytics is not available.
    /// - Parameter transaction: The StoreKit transaction to log
    static func logTransaction(_ transaction: Transaction) {
        initialize()

        if isAvailable {
            #if canImport(FirebaseAnalytics)
            Logger.d("Log iOS transaction to Firebase Analytics")
            Analytics.logTransaction(transaction)
            Logger.d("Transaction logged to Firebase Analytics")
            #endif
        }
    }
}
