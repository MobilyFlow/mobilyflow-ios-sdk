//
//  MobilyPurchaseError.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 26/07/2024.
//

import Foundation

public enum MobilyPurchaseError: Error {
    case purchase_already_pending

    case product_unavailable
    case network_unavailable

    case webhook_failed
    case webhook_not_processed

    case already_purchased
    case renew_already_on_this_plan
    case not_managed_by_this_store_account
    case store_account_already_have_purchase

    case user_canceled
    case failed
    case pending
}
