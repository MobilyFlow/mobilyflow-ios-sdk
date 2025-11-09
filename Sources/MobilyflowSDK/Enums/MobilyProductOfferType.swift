import Foundation

@objc public class MobilyProductOfferType: NSObject {
	@objc public static let FREE_TRIAL = "free_trial"
	@objc public static let RECURRING = "recurring"
	
	@objc public static let values = [FREE_TRIAL,RECURRING]
	
	override private init() {}
	
	@objc public static func parse(_ value: String) -> String {
		precondition(values.contains(value), "Invalid MobilyProductOfferType: \(value)")
		return value
	}
}
