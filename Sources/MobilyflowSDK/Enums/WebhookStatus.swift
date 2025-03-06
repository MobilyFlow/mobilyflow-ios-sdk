//
//  ProductStatus.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

@objc public enum WebhookStatus: Int {
    case pending = 0
    case error = 1
    case success = 2

    static func parse(_ rawValue: String) -> WebhookStatus? {
        switch rawValue.lowercased() {
        case "pending":
            return .pending
        case "success":
            return .success
        case "error":
            return .error
        default:
            return nil
        }
    }
}
