import Foundation

@objc public class MobilyWebhookStatus: NSObject {
    @objc public static let PENDING = "PENDING"
    @objc public static let FAILED = "FAILED"
    @objc public static let IGNORED = "IGNORED"
    @objc public static let SUCCESS = "SUCCESS"

    @objc public static let values = [PENDING, FAILED, IGNORED, SUCCESS]

    override private init() {}

    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyWebhookStatus: \(value)")
        return value
    }
}
