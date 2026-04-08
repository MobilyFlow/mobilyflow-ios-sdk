import Foundation

@objc public class MobilyTransactionStatus: NSObject {
    @objc public static let SUCCESS = "SUCCESS"
    @objc public static let BILLING_ERROR = "BILLING_ERROR"
    @objc public static let REFUNDED = "REFUNDED"

    @objc public static let values = [SUCCESS, BILLING_ERROR, REFUNDED]

    // TODO: Retro-compatibility mapping
    private static let legacyMap: [String: String] = [
        "success": SUCCESS,
        "billing-error": BILLING_ERROR,
        "refunded": REFUNDED,
    ]

    override private init() {}

    @objc public static func parse(_ value: String) -> String {
        // TODO: Retro-compatibility mapping
        if values.contains(value) {
            return value
        }
        if let legacy = legacyMap[value] {
            return legacy
        }
        // ---------------------------------
        precondition(values.contains(value), "Invalid MobilyTransactionStatus: \(value)")
        return value
    }
}
