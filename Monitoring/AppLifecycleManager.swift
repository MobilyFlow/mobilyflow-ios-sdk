//
//  AppLifecycleManager.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 27/01/2025.
//

import Foundation
import UIKit

var previousExceptionHandler: (@convention(c) (NSException) -> Void)?
var allCrashObservers: [String: (NSException?, Int32?) -> Void]?

func exceptionHandler(_ exception: NSException) {
    if allCrashObservers != nil {
        for (_, observer) in allCrashObservers! {
            observer(exception, nil)
        }
    }
    if previousExceptionHandler != nil {
        previousExceptionHandler!(exception)
    }
}

func handleSignal(_ signal: Int32) {
    if allCrashObservers != nil {
        for (_, observer) in allCrashObservers! {
            observer(nil, signal)
        }
    }
}

func registerGlobalCrashHandler(_ id: String, _ handler: @escaping (NSException?, Int32?) -> Void) {
    if allCrashObservers == nil {
        allCrashObservers = [:]
        previousExceptionHandler = NSGetUncaughtExceptionHandler()

        NSSetUncaughtExceptionHandler(exceptionHandler)
        signal(SIGABRT, handleSignal)
        signal(SIGILL, handleSignal)
        signal(SIGSEGV, handleSignal)
        signal(SIGFPE, handleSignal)
        signal(SIGBUS, handleSignal)
        signal(SIGPIPE, handleSignal)
    }

    allCrashObservers![id] = handler
}

func unregisterGlobalCrashHandler(_ id: String) {
    if allCrashObservers != nil {
        allCrashObservers!.removeValue(forKey: id)
    }
}

class AppLifecycleManager {
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didEnterBackgroundObserver: NSObjectProtocol?
    private var willTerminateObserver: NSObjectProtocol?
    private var crashObserverId: String?

    deinit {
        self.unregisterAll()
    }

    func unregisterAll() {
        if crashObserverId != nil {
            unregisterGlobalCrashHandler(crashObserverId!)
        }
        if didBecomeActiveObserver != nil {
            NotificationCenter.default.removeObserver(self.didBecomeActiveObserver!)
        }
        if didEnterBackgroundObserver != nil {
            NotificationCenter.default.removeObserver(self.didEnterBackgroundObserver!)
        }
        if willTerminateObserver != nil {
            NotificationCenter.default.removeObserver(self.willTerminateObserver!)
        }
    }

    func registerDidBecomeActive(_ callback: @escaping () -> Void) {
        if self.didBecomeActiveObserver != nil {
            NotificationCenter.default.removeObserver(self.didBecomeActiveObserver!)
        }

        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            callback()
        }
    }

    func registerDidEnterBackground(_ callback: @escaping () -> Void) {
        if self.didEnterBackgroundObserver != nil {
            NotificationCenter.default.removeObserver(self.didEnterBackgroundObserver!)
        }

        self.didEnterBackgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            callback()
        }
    }

    func registerWillTerminate(_ callback: @escaping () -> Void) {
        if self.willTerminateObserver != nil {
            NotificationCenter.default.removeObserver(self.willTerminateObserver!)
        }

        self.willTerminateObserver = NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: nil) { _ in
            callback()
        }
    }

    func registerCrash(_ handler: @escaping (NSException?, Int32?) -> Void) {
        if crashObserverId != nil {
            unregisterGlobalCrashHandler(crashObserverId!)
        }
        crashObserverId = UUID().uuidString
        registerGlobalCrashHandler(crashObserverId!, handler)
    }
}
