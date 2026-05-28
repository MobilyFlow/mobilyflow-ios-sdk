import Foundation

@objc public class MobilyProductType: NSObject {
    @objc public static let ONE_TIME = "ONE_TIME"
    @objc public static let SUBSCRIPTION = "SUBSCRIPTION"

    @objc public static let values = [ONE_TIME, SUBSCRIPTION]

    override private init() {}

    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyProductType: \(value)")
        return value
    }
}
