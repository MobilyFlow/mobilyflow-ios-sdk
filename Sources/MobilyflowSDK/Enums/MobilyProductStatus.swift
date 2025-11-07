//
//  MobilyProductStatus.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

@objc public class MobilyProductStatus: NSObject {
    @objc public static let INVALID = "invalid"
    @objc public static let UNAVAILABLE = "unavailable"
    @objc public static let AVAILABLE = "available"

    override private init() {}
}
