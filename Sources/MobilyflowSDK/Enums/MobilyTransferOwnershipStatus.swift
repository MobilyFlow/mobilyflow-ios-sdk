import Foundation

@objc public class MobilyTransferOwnershipStatus: NSObject {
	@objc public static let PENDING = "pending"
	@objc public static let DELAYED = "delayed"
	@objc public static let ACKNOWLEDGED = "acknowledged"
	@objc public static let REJECTED = "rejected"
	
	@objc public static let values = [PENDING,DELAYED,ACKNOWLEDGED,REJECTED]
	
	override private init() {}
	
	@objc public static func parse(_ value: String) -> String {
		precondition(values.contains(value), "Invalid MobilyTransferOwnershipStatus: \(value)")
		return value
	}
}
