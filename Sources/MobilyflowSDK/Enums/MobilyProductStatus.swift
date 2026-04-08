import Foundation

@objc public class MobilyProductStatus: NSObject {
    @objc public static let INVALID = "INVALID"
    @objc public static let UNAVAILABLE = "UNAVAILABLE"
    @objc public static let AVAILABLE = "AVAILABLE"

    @objc public static let values = [INVALID, UNAVAILABLE, AVAILABLE]

    override private init() {}

    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyProductStatus: \(value)")
        return value
    }
}
