//
//  ApiResponse.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

struct ApiResponse {
    let status: Int
    let data: Data

    var success: Bool {
        return status >= 200 && status < 300
    }

    init(status: Int, data: Data) {
        self.status = status
        self.data = data
    }

    func json() -> [String: Any] {
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func jsonArray() -> [[String: Any]] {
        return try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
    }

    func string() -> String {
        return String(data: data, encoding: .utf8)!
    }
}
