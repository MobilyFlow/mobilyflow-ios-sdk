//
//  MobilyRefundDialogResult.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 10/05/2025.
//

import Foundation

@objc public class MobilyRefundDialogResult: NSObject {
    @objc public static let CANCELLED = "cancelled"
    @objc public static let SUCCESS = "success"
    @objc public static let TRANSACTION_NOT_FOUND = "transaction_not_found"

    override private init() {}
}
