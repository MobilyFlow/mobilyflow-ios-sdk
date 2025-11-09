import Foundation

@objc public class MobilyProductStatus: NSObject {
	@objc public static let INVALID = "invalid"
	@objc public static let UNAVAILABLE = "unavailable"
	@objc public static let AVAILABLE = "available"
	
	@objc public static let values = [INVALID,UNAVAILABLE,AVAILABLE]
	
	override private init() {}
	
	@objc public static func parse(_ value: String) -> String {
		precondition(values.contains(value), "Invalid MobilyProductStatus: \(value)")
		return value
	}
}
