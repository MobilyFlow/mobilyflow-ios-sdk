import Foundation

@objc public class MobilyProductOfferPricingMode: NSObject {
    @objc public static let FREE_TRIAL = "FREE_TRIAL"
    @objc public static let RECURRING = "RECURRING"
	
    @objc public static let values = [FREE_TRIAL, RECURRING]
	
    override private init() {}
	
    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyProductOfferType: \(value)")
        return value
    }
}
