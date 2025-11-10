import Foundation

@objc public class MobilyTransactionStatus: NSObject {
	@objc public static let SUCCESS = "success"
	@objc public static let BILLING_ERROR = "billing-error"
	@objc public static let REFUNDED = "refunded"
	
	@objc public static let values = [SUCCESS,BILLING_ERROR,REFUNDED]
	
	override private init() {}
	
	@objc public static func parse(_ value: String) -> String {
		precondition(values.contains(value), "Invalid MobilyTransactionStatus: \(value)")
		return value
	}
}
