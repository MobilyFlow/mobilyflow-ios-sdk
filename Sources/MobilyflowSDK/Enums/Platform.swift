//
//  Platform.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

@objc public enum Platform: Int {
    case ios = 0
    case android = 1

    static func parse(_ rawValue: String) -> Platform? {
        switch rawValue.lowercased() {
        case "ios":
            return .ios
        case "android":
            return .android
        default:
            return nil
        }
    }
}
