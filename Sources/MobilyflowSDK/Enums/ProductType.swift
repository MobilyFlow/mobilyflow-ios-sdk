//
//  ProductType.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 25/07/2024.
//

import Foundation

@objc public enum ProductType: Int {
    case one_time
    case subscription

    static func parse(_ rawValue: String) -> ProductType? {
        switch rawValue.lowercased() {
        case "one_time":
            return .one_time
        case "subscription":
            return .subscription
        default:
            return nil
        }
    }
}
