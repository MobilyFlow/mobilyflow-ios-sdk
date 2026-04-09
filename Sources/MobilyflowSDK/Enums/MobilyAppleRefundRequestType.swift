import Foundation

@objc public class MobilyAppleRefundRequestType: NSObject {
    @objc public static let REFUND = "REFUND"
    @objc public static let CANCEL = "CANCEL"

    @objc public static let values = [REFUND, CANCEL]

    // TODO: Retro-compatibility mapping
    private static let legacyMap: [String: String] = [
        "refund": REFUND,
        "cancel": CANCEL,
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
        precondition(values.contains(value), "Invalid MobilyAppleRefundRequestType: \(value)")
        return value
    }
}
