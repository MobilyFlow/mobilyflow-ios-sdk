import Foundation

@objc public class MobilyTransferOwnershipStatus: NSObject {
    @objc public static let PENDING = "PENDING"
    @objc public static let DELAYED = "DELAYED"
    @objc public static let ACKNOWLEDGED = "ACKNOWLEDGED"
    @objc public static let REJECTED = "REJECTED"
    @objc public static let ERROR = "ERROR"

    @objc public static let values = [PENDING, DELAYED, ACKNOWLEDGED, REJECTED, ERROR]

    // TODO: Retro-compatibility mapping
    private static let legacyMap: [String: String] = [
        "pending": PENDING,
        "delayed": DELAYED,
        "acknowledged": ACKNOWLEDGED,
        "rejected": REJECTED,
        "error": ERROR,
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
        precondition(values.contains(value), "Invalid MobilyTransferOwnershipStatus: \(value)")
        return value
    }
}
