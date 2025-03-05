//
//  MobilyPurchaseAPI.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 24/10/2024.
//

import Foundation
import StoreKit

class MobilyPurchaseAPI {
    let appId: String
    let apiKey: String
    let environment: MobilyEnvironment
    let lang: String

    let API_URL: String
    let helper: ApiHelper

    init(
        appId: String,
        apiKey: String,
        environment: MobilyEnvironment,
        languages: [String],
        apiURL: String?
    ) {
        self.API_URL = apiURL ?? "https://api.mobilyflow.com/v1/"
        self.appId = appId
        self.apiKey = apiKey
        self.environment = environment
        self.lang = languages.joined(separator: ",")

        self.helper = ApiHelper(baseURL: API_URL, defaultHeaders: ["Authorization": "Bearer \(apiKey)"])
    }

    /**
     Log user into MobilyFlow with his externalId and return his uuid.
     Throws on error.
     */
    public func login(externalId: String) async throws -> LoginResponse {
        let request = ApiRequest(method: "POST", url: "/apps/me/customers/login/ios")
        _ = request.setData(["externalId": externalId, "environment": environment.toString()])

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            let data = res.json()
            return LoginResponse(customerId: UUID(uuidString: data["id"] as! String)!, platformOriginalTransactionIds: data["platformOriginalTransactionIds"] as! [String])
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Get products in JSON Array format
     */
    public func getProducts(identifiers: [String]?) async throws -> [[String: Any]] {
        if identifiers != nil && identifiers?.count == 0 {
            return []
        }

        let request = ApiRequest(method: "GET", url: "/apps/me/products/")
        _ = request.addParam("environment", environment.toString())
        _ = request.addParam("lang", self.lang)

        if identifiers != nil {
            _ = request.addParam("identifiers", identifiers!.joined(separator: ","))
        }

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.jsonArray()
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Get products in JSON Array format
     */
    public func getCustomerEntitlements(customerId: UUID) async throws -> [[String: Any]] {
        let request = ApiRequest(method: "GET", url: "/apps/me/customers/\(customerId.uuidString.lowercased())/entitlements")
        _ = request.addParam("lang", self.lang)

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.jsonArray()
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Take a customerId and an offerId (offerId from MobilyFlow) and return the signed offer, like explained in the doc:
     https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/subscriptions_and_offers/generating_a_signature_for_promotional_offers

     Throws on error.
     */
    @available(iOS 17.4, *)
    public func signOffer(customerId: UUID, offerId: String) async throws -> Product.SubscriptionOffer.Signature {
        let request = ApiRequest(method: "POST", url: "/apps/me/products/sign-offer/ios")
        _ = request.setData(["customerId": customerId.uuidString.lowercased(), "offerId": offerId])

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            let jsonResponse = res.json()
            return Product.SubscriptionOffer.Signature(
                keyID: jsonResponse["keyID"] as! String,
                nonce: UUID(uuidString: jsonResponse["nonce"] as! String)!,
                timestamp: jsonResponse["timestamp"] as! Int,
                signature: Data(base64Encoded: jsonResponse["signature"] as! String)!
            )
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Map transaction to this customer.
     Throws on error.
     */
    public func mapTransactions(customerId: UUID, transactions: [String]) async throws {
        let request = ApiRequest(method: "POST", url: "/apps/me/customers/mappings/ios")
        _ = request.setData(["customerId": customerId.uuidString.lowercased(), "transactions": transactions])

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if !res.success {
            throw MobilyError.unknown_error
        }
    }

    /**
     Request transfer ownership of local device transactions, and return requestId.
     Throws on error.
     */
    public func transferOwnershipRequest(customerId: UUID, transactions: [String]) async throws -> String {
        let request = ApiRequest(method: "POST", url: "/apps/me/customers/transfer-ownership/request/ios")
        _ = request.setData(["customerId": customerId.uuidString.lowercased(), "transactions": transactions])

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        let jsonResponse = res.json()
        if res.success {
            return jsonResponse["id"]! as! String
        } else {
            let error = MobilyTransferOwnershipError.parse(jsonResponse["errorCode"]! as! String)
            if error != nil {
                throw error!
            } else {
                throw MobilyError.unknown_error
            }
        }
    }

    /**
     Get transfer ownership request status from requestId
     */
    public func getTransferRequestStatus(requestId: String) async throws -> TransferOwnershipStatus {
        let request = ApiRequest(method: "GET", url: "/apps/me/customers/transfer-ownership/\(requestId)/status")

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            let jsonResponse = res.json()
            return TransferOwnershipStatus.parse(jsonResponse["status"] as! String)!
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Force the webhook to be triggered (before Apple Server Notification was send)

     type is "purchase" | "upgrade"
     */
    public func forceWebhook(transactionId: UInt64, type: String, isSandbox: Bool) async throws {
        let request = ApiRequest(method: "POST", url: "/apps/me/platform-notifications/force-webhook/ios")
        _ = request.addData("platformTxId", String(transactionId))
        _ = request.addData("type", type)
        _ = request.addData("isSandbox", isSandbox)

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if !res.success {
            throw MobilyError.unknown_error
        }
    }

    /**
     Get webhook status from transactionID
     */
    public func getWebhookStatus(transactionId: UInt64, isSandbox: Bool) async throws -> WebhookStatus {
        let request = ApiRequest(method: "GET", url: "/apps/me/events/webhook-status/ios")
        _ = request.addParam("isSandbox", String(isSandbox))
        _ = request.addParam("platformTxId", String(transactionId))

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            let jsonResponse = res.json()
            return WebhookStatus.parse(jsonResponse["status"] as! String)!
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Upload monitoring file
     */
    public func uploadMonitoring(customerId: UUID?, file: URL) async throws {
        let request = ApiRequest(method: "POST", url: "/apps/me/monitoring/upload")
        if customerId != nil {
            _ = request.addData("customerId", customerId!.uuidString.lowercased())
        }
        _ = request.addFile("logFile", file)

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if !res.success {
            throw MobilyError.unknown_error
        }
    }
}
