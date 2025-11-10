import Foundation

@objc public class MobilyPlatform: NSObject {
	@objc public static let IOS = "ios"
	@objc public static let ANDROID = "android"
	
	@objc public static let values = [IOS,ANDROID]
	
	override private init() {}
	
	@objc public static func parse(_ value: String) -> String {
		precondition(values.contains(value), "Invalid MobilyPlatform: \(value)")
		return value
	}
}
