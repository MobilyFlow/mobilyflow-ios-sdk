import Foundation
import StoreKit

@objc public class PeriodUnit: NSObject {
    @objc public static let WEEK = "week"
    @objc public static let MONTH = "month"
    @objc public static let YEAR = "year"
	
    @objc public static let values = [WEEK, MONTH, YEAR]
	
    override private init() {}
	
    @objc public static func parse(_ value: String) -> String {
        precondition(values.contains(value), "Invalid PeriodUnit: \(value)")
        return value
    }
    
    static func parseSubscriptionPeriod(_ period: Product.SubscriptionPeriod) throws -> (count: Int, unit: String) {
        if period.unit == .day && period.value == 7 {
            return (1, PeriodUnit.WEEK)
        }

        switch period.unit {
        case .week: return (period.value, PeriodUnit.WEEK)
        case .month: return (period.value, PeriodUnit.MONTH)
        case .year: return (period.value, PeriodUnit.YEAR)
        default: fatalError("fromSubscriptionPeriodUnit -> Bad unit \(period.value) \(period.unit)")
        }
    }
}
