//
//  ApiHelper.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

class ApiHelper {
    let baseURL: String
    let defaultHeaders: [String: String]?

    init(baseURL: String, defaultHeaders: [String: String]? = nil) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
    }

    /**
         Perform an HTTP request.

         - Parameter req: The request to execute
         - Returns: data (parsed json result), response, error if any
     */
    func request(_ req: ApiRequest) async throws -> ApiResponse {
        if defaultHeaders != nil {
            for (key, value) in defaultHeaders! {
                _ = req.addHeader(key, value)
            }
        }

        let urlRequest = try! req.buildRequest(baseURL)

        let (bytesData, rawResponse) = try await URLSession.shared.data(for: urlRequest)

        let httpRes = rawResponse as! HTTPURLResponse
        return ApiResponse(status: httpRes.statusCode, data: bytesData)
    }
}
