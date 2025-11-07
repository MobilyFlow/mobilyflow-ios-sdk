//
//  MobilyTransactionStatus.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 07/11/2025.
//

import Foundation

@objc public class MobilyTransactionStatus: NSObject {
    @objc public static let SUCCESS = "success"
    @objc public static let BILLING_ERROR = "billing-error"
    @objc public static let REFUNDED = "refunded"

    override private init() {}
}
