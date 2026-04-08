import Foundation

@objc public class MobilyRefundDialogResult: NSObject {
    @objc public static let CANCELLED = "CANCELLED"
    @objc public static let SUCCESS = "SUCCESS"
    @objc public static let TRANSACTION_NOT_FOUND = "TRANSACTION_NOT_FOUND"
	
    @objc public static let values = [CANCELLED, SUCCESS, TRANSACTION_NOT_FOUND]
	
    override private init() {}
	
    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyRefundDialogResult: \(value)")
        return value
    }
}
