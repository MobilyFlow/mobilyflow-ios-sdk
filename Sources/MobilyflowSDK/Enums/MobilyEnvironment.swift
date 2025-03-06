//
//  MobilyEnvironment.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 25/07/2024.
//

import Foundation

@objc public enum MobilyEnvironment: Int {
    case development = 0
    case staging = 1
    case production = 2

    public func toString() -> String {
        switch self {
        case .development:
            return "development"
        case .staging:
            return "staging"
        case .production:
            return "production"
        }
    }
}
