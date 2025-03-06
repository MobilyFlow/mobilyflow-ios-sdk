//
//  ProductStatus.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

@objc public enum TransferOwnershipStatus: Int {
    case pending
    case delayed
    case acknowledged
    case rejected
    case error

    static func parse(_ rawValue: String) -> TransferOwnershipStatus? {
        switch rawValue.lowercased() {
        case "pending":
            return .pending
        case "delayed":
            return .delayed
        case "acknowledged":
            return .acknowledged
        case "rejected":
            return .rejected
        case "error":
            return .error
        default:
            return nil
        }
    }
}
