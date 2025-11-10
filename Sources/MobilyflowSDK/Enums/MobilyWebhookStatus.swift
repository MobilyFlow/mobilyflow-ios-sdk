import Foundation

@objc public class MobilyWebhookStatus: NSObject {
	@objc public static let PENDING = "pending"
	@objc public static let ERROR = "error"
	@objc public static let SUCCESS = "success"
	
	@objc public static let values = [PENDING,ERROR,SUCCESS]
	
	override private init() {}
	
	@objc public static func parse(_ value: String) -> String {
		precondition(values.contains(value), "Invalid MobilyWebhookStatus: \(value)")
		return value
	}
}
