//
//  LogLevel.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 24/01/2025.
//

public enum LogLevel {
    case debug
    case warn
    case error

    static func getIcon(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "📘"
        case .warn: return "⚠️"
        case .error: return "⛔️"
        }
    }

    static func getLabel(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .warn: return "WARN"
        case .error: return "ERROR"
        }
    }
}
