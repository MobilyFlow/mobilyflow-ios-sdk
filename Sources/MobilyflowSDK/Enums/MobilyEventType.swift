import Foundation

@objc public class MobilyEventType: NSObject {
    @objc public static let TEST = "TEST"
    @objc public static let PURCHASED = "PURCHASED"
    @objc public static let CONSUMED = "CONSUMED"
    @objc public static let RENEWED = "RENEWED"
    @objc public static let EXPIRED = "EXPIRED"
    @objc public static let REVOKED = "REVOKED"
    @objc public static let REFUNDED = "REFUNDED"
    @objc public static let RENEW_PRODUCT_CHANGED = "RENEW_PRODUCT_CHANGED"
    @objc public static let UPGRADED = "UPGRADED"
    @objc public static let EXTENDED = "EXTENDED"
    @objc public static let AUTO_RENEW_CHANGED = "AUTO_RENEW_CHANGED"
    @objc public static let PAUSE_STATUS_CHANGED = "PAUSE_STATUS_CHANGED"
    @objc public static let GRACE_PERIOD_RESOLVED = "GRACE_PERIOD_RESOLVED"
    @objc public static let TRANSFER_OWNERSHIP_REQUESTED = "TRANSFER_OWNERSHIP_REQUESTED"
    @objc public static let TRANSFER_OWNERSHIP_ACKNOWLEDGED = "TRANSFER_OWNERSHIP_ACKNOWLEDGED"

    @objc public static let values = [TEST, PURCHASED, CONSUMED, RENEWED, EXPIRED, REVOKED, REFUNDED, RENEW_PRODUCT_CHANGED, UPGRADED, EXTENDED, AUTO_RENEW_CHANGED, PAUSE_STATUS_CHANGED, GRACE_PERIOD_RESOLVED, TRANSFER_OWNERSHIP_REQUESTED, TRANSFER_OWNERSHIP_ACKNOWLEDGED]

    override private init() {}

    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyEventType: \(value)")
        return value
    }
}
