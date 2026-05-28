import Foundation

@objc public class MobilyAppleRefundRequestType: NSObject {
    @objc public static let REFUND = "REFUND"
    @objc public static let CANCEL = "CANCEL"

    @objc public static let values = [REFUND, CANCEL]

    override private init() {}

    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyAppleRefundRequestType: \(value)")
        return value
    }
}
