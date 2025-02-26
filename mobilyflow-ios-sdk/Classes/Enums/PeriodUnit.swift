//
//  PeriodUnit.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 25/07/2024.
//

import Foundation
import StoreKit

public enum PeriodUnit: String {
    case week
    case month
    case year

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
}
