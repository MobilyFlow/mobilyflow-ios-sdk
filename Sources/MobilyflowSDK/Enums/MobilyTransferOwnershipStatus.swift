import Foundation

@objc public class MobilyTransferOwnershipStatus: NSObject {
    @objc public static let PENDING = "PENDING"
    @objc public static let DELAYED = "DELAYED"
    @objc public static let ACKNOWLEDGED = "ACKNOWLEDGED"
    @objc public static let REJECTED = "REJECTED"
    @objc public static let ERROR = "ERROR"

    @objc public static let values = [PENDING, DELAYED, ACKNOWLEDGED, REJECTED, ERROR]

    override private init() {}

    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyTransferOwnershipStatus: \(value)")
        return value
    }
}
