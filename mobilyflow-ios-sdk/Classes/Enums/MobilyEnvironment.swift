//
//  MobilyEnvironment.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 25/07/2024.
//

import Foundation

@objc public enum MobilyEnvironment: Int {
    case development
    case staging
    case production

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
