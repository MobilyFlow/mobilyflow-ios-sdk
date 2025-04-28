//
//  LoginResponse.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 15/01/2025.
//

import Foundation

struct LoginResponse {
    let customer: [String: Any]
    let entitlements: [[String: Any]]
    let platformOriginalTransactionIds: [String]
    let isForwardingEnable: Bool
}
