import Foundation

@objc public class MobilyEnvironment: NSObject {
	@objc public static let DEVELOPMENT = "development"
	@objc public static let STAGING = "staging"
	@objc public static let PRODUCTION = "production"
	
	@objc public static let values = [DEVELOPMENT,STAGING,PRODUCTION]
	
	override private init() {}
	
	@objc public static func parse(_ value: String) -> String {
		precondition(values.contains(value), "Invalid MobilyEnvironment: \(value)")
		return value
	}
}
