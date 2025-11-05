//
//  ApiRequest.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

class ApiRequest {
    private let method: String
    private let url: String

    private var params: [String: String]?
    private var data: [String: Any]?
    private var headers: [String: String]
    private var files: [String: URL]?

    init(method: String, url: String) {
        self.method = method
        self.url = url
        self.headers = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    func addHeader(_ key: String, _ value: String) -> ApiRequest {
        self.headers[key] = value
        return self
    }

    func setParams(_ params: [String: String]) -> ApiRequest {
        self.params = params
        return self
    }

    func addParam(_ key: String, _ value: String) -> ApiRequest {
        if self.params == nil {
            self.params = [:]
        }

        self.params![key] = value
        return self
    }

    func setData(_ data: [String: Any]) -> ApiRequest {
        self.data = data
        return self
    }

    func addData(_ key: String, _ value: Any) -> ApiRequest {
        if self.data == nil {
            self.data = [:]
        }

        self.data![key] = value
        return self
    }

    func addFile(_ key: String, _ value: URL) -> ApiRequest {
        if self.files == nil {
            self.files = [:]
        }

        self.files![key] = value
        return self
    }

    private func createMultipartBody(request: inout URLRequest) throws -> Data {
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add fields
        if self.data != nil {
            for (key, value) in self.data! {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }

        // Add the file
        if self.files != nil {
            for (key, fileURL) in self.files! {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
                try body.append(Data(contentsOf: fileURL))
                body.append("\r\n".data(using: .utf8)!)
            }
        }

        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    func buildRequest(_ baseUrl: String) throws -> URLRequest {
        // 1. Build URL

        // a. baseURL + requestURL
        var url = baseUrl

        if !baseUrl.hasSuffix("/") && !self.url.hasPrefix("/") {
            url += "/" + self.url
        } else if baseUrl.hasSuffix("/") && self.url.hasPrefix("/") {
            url += String(self.url.dropFirst(1))
        } else {
            url += self.url
        }

        // b. Query params
        if params != nil, params?.isEmpty == false {
            url += "?"
            for (key, value) in params! {
                if !url.hasSuffix("?") {
                    url += "&"
                }
                url += key + "=" + String(describing: value)
            }
        }

        // 2. Build request
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method

        if !headers.isEmpty {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        if self.files != nil {
            request.httpBody = try createMultipartBody(request: &request)
            request.timeoutInterval = 30
        } else {
            request.timeoutInterval = 30 // 30s in case of cold start
            if data != nil, data?.isEmpty == false {
                request.httpBody = try JSONSerialization.data(withJSONObject: data!, options: [])
            }
        }

        return request
    }
}
