//
//  FirebaseAnalyticsWrapper.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 30/03/2026.
//

import Foundation
import StoreKit

/// Utility class to log transactions to Firebase Analytics if available in the host app.
/// This uses Objective-C runtime to dynamically call Analytics methods without
/// requiring Firebase as a dependency.
class FirebaseAnalyticsWrapper {
    private static var analyticsClass: NSObject.Type?
    private static var isInitialized = false
    private static var isAvailable = false

    /// Initialize and cache the Analytics class if available
    private static func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        // Try to get the FIRAnalytics class dynamically
        guard let firAnalyticsClass = NSClassFromString("FIRAnalytics") as? NSObject.Type else {
            isAvailable = false
            return
        }

        // Verify the class responds to logTransaction:
        let logTransactionSelector = NSSelectorFromString("logTransaction:")
        guard firAnalyticsClass.responds(to: logTransactionSelector) else {
            isAvailable = false
            return
        }

        analyticsClass = firAnalyticsClass
        isAvailable = true

        print("[MobilyFlow] Firebase Analytics detected")
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
        guard let analyticsClass = analyticsClass else { return }

        let logTransactionSelector = NSSelectorFromString("logTransaction:")
        guard analyticsClass.responds(to: logTransactionSelector) else { return }

        Logger.d("Log iOS transaction to Firebase Analytics")
        analyticsClass.perform(logTransactionSelector, with: transaction)
        Logger.d("Transaction logged to Firebase Analytics")
    }
}
