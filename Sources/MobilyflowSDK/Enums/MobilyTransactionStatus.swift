import Foundation

@objc public class MobilyTransactionStatus: NSObject {
    @objc public static let SUCCESS = "SUCCESS"
    @objc public static let BILLING_ERROR = "BILLING_ERROR"
    @objc public static let REFUNDED = "REFUNDED"

    @objc public static let values = [SUCCESS, BILLING_ERROR, REFUNDED]

    override private init() {}

    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyTransactionStatus: \(value)")
        return value
    }
}
