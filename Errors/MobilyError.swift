//
//  MobilyFetchError.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 26/07/2024.
//

import Foundation

public enum MobilyError: Error {
    case store_unavailable
    case server_unavailable
    case no_customer_logged
    case unknown_error
}
