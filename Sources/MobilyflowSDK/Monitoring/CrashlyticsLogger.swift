//
//  CrashlyticsLogger.swift
//  MobilyflowSDK
//

import Foundation

/// Utility class to log messages to Firebase Crashlytics if available in the host app.
/// This uses Objective-C runtime to dynamically call Crashlytics methods without
/// requiring Firebase as a dependency.
///
/// Reference: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/WeakLinking.html
class CrashlyticsLogger {
    private static var crashlyticsInstance: NSObject?
    private static var isInitialized = false
    private static var isAvailable = false

    /// Initialize and cache the Crashlytics instance if available
    private static func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        // Try to get the FIRCrashlytics class dynamically
        guard let crashlyticsClass = NSClassFromString("FIRCrashlytics") as? NSObject.Type else {
            isAvailable = false
            return
        }

        // Get the shared instance via "crashlytics" class method
        let crashlyticsSelector = NSSelectorFromString("crashlytics")
        guard crashlyticsClass.responds(to: crashlyticsSelector) else {
            isAvailable = false
            return
        }

        crashlyticsInstance = crashlyticsClass.perform(crashlyticsSelector)?.takeUnretainedValue() as? NSObject
        isAvailable = crashlyticsInstance != nil

        if isAvailable {
            print("[MobilyFlow] Firebase Crashlytics detected")
        }
    }

    /// Check if Firebase Crashlytics is available in the host app
    static func isCrashlyticsAvailable() -> Bool {
        initialize()
        return isAvailable
    }

    private static let dateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]
        return formatter
    }()

    /// Log a message to Firebase Crashlytics.
    /// Messages will appear in the "Logs" tab of a crash report.
    /// - Parameter message: The message to log
    static func log(_ message: String) {
        initialize()
        guard let instance = crashlyticsInstance else { return }

        let logSelector = NSSelectorFromString("log:")
        guard instance.responds(to: logSelector) else { return }

        instance.perform(logSelector, with: message)
    }
}
