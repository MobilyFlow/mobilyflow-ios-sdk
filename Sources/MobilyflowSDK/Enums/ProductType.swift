//
//  ProductType.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 25/07/2024.
//

import Foundation

@objc public class ProductType: NSObject {
    // Abstract
    @available(*, unavailable, message: "This class is abstract and cannot be instantiated.")
    override init() {
        fatalError("This class is abstract and cannot be instantiated.")
    }

    @objc public static let one_time = "one_time"
    @objc public static let subscription = "subscription"
}
