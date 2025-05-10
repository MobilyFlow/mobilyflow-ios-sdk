//
//  PeriodUnit.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 25/07/2024.
//

import Foundation
import StoreKit

@objc public enum PeriodUnit: Int {
    case week = 0
    case month = 1
    case year = 2

    static func parseSubscriptionPeriod(_ period: Product.SubscriptionPeriod) throws -> (count: Int, unit: PeriodUnit) {
        if period.unit == .day && period.value == 7 {
            return (1, .week)
        }

        switch period.unit {
        case .week: return (period.value, .week)
        case .month: return (period.value, .month)
        case .year: return (period.value, .month)
        default: fatalError("fromSubscriptionPeriodUnit -> Bad unit \(period.value) \(period.unit)")
        }
    }

    public static func parse(_ str: String) -> PeriodUnit? {
        switch str.lowercased() {
        case "week":
            return .week
        case "month":
            return .month
        case "year":
            return .year
        default:
            return nil
        }
    }

    public static func toString(_ value: PeriodUnit) -> String {
        switch value {
        case .week:
            return "week"
        case .month:
            return "month"
        case .year:
            return "year"
        }
    }
}
