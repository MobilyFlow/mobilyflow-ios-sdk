import Foundation

@objc public class MobilyProductOfferType: NSObject {
    @objc public static let INTRODUCTORY = "INTRODUCTORY"
    @objc public static let DEVELOPER_DETERMINED = "DEVELOPER_DETERMINED"
	
    @objc public static let values = [INTRODUCTORY, DEVELOPER_DETERMINED]
	
    override private init() {}
	
    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid MobilyProductOfferType: \(value)")
        return value
    }
}
