//
//  MobilyWebhookStatus.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

@objc public class MobilyWebhookStatus: NSObject {
    @objc public static let PENDING = "pending"
    @objc public static let ERROR = "error"
    @objc public static let SUCCESS = "success"

    override private init() {}
}
