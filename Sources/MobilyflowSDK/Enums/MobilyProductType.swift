import Foundation

@objc public class MobilyProductType: NSObject {
    @objc public static let ONE_TIME = "ONE_TIME"
    @objc public static let SUBSCRIPTION = "SUBSCRIPTION"

    @objc public static let values = [ONE_TIME, SUBSCRIPTION]

    // TODO: Retro-compatibility mapping
    private static let legacyMap: [String: String] = [
        "one_time": ONE_TIME,
        "subscription": SUBSCRIPTION,
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
        precondition(values.contains(value), "Invalid MobilyProductType: \(value)")
        return value
    }
}
