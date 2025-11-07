//
//  MobilyEventType.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 07/11/2025.
//

import Foundation

@objc public class MobilyEventType: NSObject {
    @objc public static let TEST = "test"
    @objc public static let PURCHASE = "purchase"
    @objc public static let CONSUMED = "consumed"
    @objc public static let RENEW = "renew"
    @objc public static let EXPIRED = "expired"
    @objc public static let REVOKED = "revoked"
    @objc public static let REFUNDED = "refunded"
    @objc public static let SUBSCRIPTION_CHANGE_RENEW_PRODUCT = "subscription-change-renew-product"
    @objc public static let SUBSCRIPTION_UPGRADE = "subscription-upgrade"
    @objc public static let SUBSCRIPTION_EXTENDED = "subscription-extended"
    @objc public static let CHANGE_AUTO_RENEW = "change-auto-renew"
    @objc public static let CHANGE_PAUSE_STATUS = "change-pause-status"
    @objc public static let GRACE_PERIOD_RESOLVED = "grace-period-resolved"
    @objc public static let TRANSFER_OWNERSHIP_REQUEST = "transfer-ownership-request"
    @objc public static let TRANSFER_OWNERSHIP_ACKNOWLEDGED = "transfer-ownership-acknowledged"

    override private init() {}
}
