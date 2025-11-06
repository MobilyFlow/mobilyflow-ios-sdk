//
//  MobilyEnvironment.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 25/07/2024.
//

import Foundation

@objc public class MobilyEnvironment: NSObject {
    @objc public static let DEVELOPMENT = "development"
    @objc public static let STAGING = "staging"
    @objc public static let PRODUCTION = "production"

    override private init() {}
}
