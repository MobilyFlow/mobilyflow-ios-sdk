import Foundation

@objc public class MobilyWebhookStatus: NSObject {
    @objc public static let PENDING = "PENDING"
    @objc public static let FAILED = "FAILED"
    @objc public static let IGNORED = "IGNORED"
    @objc public static let SUCCESS = "SUCCESS"

    @objc public static let values = [PENDING, FAILED, IGNORED, SUCCESS]

    // TODO: Retro-compatibility mapping
    private static let legacyMap: [String: String] = [
        "not-sent": PENDING,
        "pending": PENDING,
        "failed": FAILED,
        "error": FAILED,
        "ignored": IGNORED,
        "success": SUCCESS,
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
        precondition(values.contains(value), "Invalid MobilyWebhookStatus: \(value)")
        return value
    }
}
