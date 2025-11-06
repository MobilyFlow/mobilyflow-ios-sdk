//
//  PeriodUnit.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 25/07/2024.
//

import Foundation
import StoreKit

@objc public class PeriodUnit: NSObject {
    @objc public static let WEEK = "week"
    @objc public static let MONTH = "month"
    @objc public static let YEAR = "year"

    override private init() {}

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
