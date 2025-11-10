import Foundation

@objc public class MobilyRefundDialogResult: NSObject {
	@objc public static let CANCELLED = "cancelled"
	@objc public static let SUCCESS = "success"
	@objc public static let TRANSACTION_NOT_FOUND = "transaction_not_found"
	
	@objc public static let values = [CANCELLED,SUCCESS,TRANSACTION_NOT_FOUND]
	
	override private init() {}
	
	@objc public static func parse(_ value: String) -> String {
		precondition(values.contains(value), "Invalid MobilyRefundDialogResult: \(value)")
		return value
	}
}
