//
//  RefundDialogResult.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 10/05/2025.
//

import Foundation

@objc public enum RefundDialogResult: Int {
    case cancelled = 0
    case success = 1
    case transaction_not_found = 2
}
