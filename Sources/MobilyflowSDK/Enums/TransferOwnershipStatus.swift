//
//  ProductStatus.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

@objc public enum TransferOwnershipStatus: Int {
    case pending = 0
    case delayed = 1
    case acknowledged = 2
    case rejected = 3

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
        default:
            return nil
        }
    }
}
