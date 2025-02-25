//
//  MobilyTransferOwnershipError.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 17/01/2025.
//

import Foundation

enum MobilyTransferOwnershipError: Error {
    case nothing_to_transfer
    case transfer_to_same_customer

    case already_pending
    case webhook_failed
    case webhook_not_processed

    static func parse(_ rawValue: String) -> MobilyTransferOwnershipError? {
        if rawValue == "nothing_to_transfer" {
            return .nothing_to_transfer
        } else if rawValue == "transfer_to_same_customer" {
            return .transfer_to_same_customer
        } else if rawValue == "already_pending" {
            return .already_pending
        } else if rawValue == "webhook_failed" {
            return .webhook_failed
        } else if rawValue == "webhook_not_processed" {
            return .webhook_not_processed
        } else {
            return nil
        }
    }
}
