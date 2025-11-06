//
//  ProductStatus.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

@objc public class TransferOwnershipStatus: NSObject {
    @objc public static let PENDING = "pending"
    @objc public static let DELAYED = "delayed"
    @objc public static let ACKNOWLEDGED = "acknowledged"
    @objc public static let REJECTED = "rejected"

    override private init() {}
}
