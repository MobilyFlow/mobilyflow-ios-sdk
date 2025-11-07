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
    let environment: String
    let locale: String

    let API_URL: String
    let helper: ApiHelper

    init(
        appId: String,
        apiKey: String,
        environment: String,
        locales: [String],
        apiURL: String?
    ) {
        self.API_URL = apiURL ?? "https://api.mobilyflow.com/v1/"
        self.appId = appId
        self.apiKey = apiKey
        self.environment = environment
        self.locale = locales.joined(separator: ",")

        self.helper = ApiHelper(baseURL: API_URL, defaultHeaders: [
            "Authorization": "ApiKey \(apiKey)",
            "platform": "ios",
            "sdk_version": MobilyFlowVersion.current,
        ])
    }

    /**
     Log user into MobilyFlow with his externalRef and return his uuid.
     Throws on error.
     */
    public func login(externalRef: String) async throws -> LoginResponse {
        let request = ApiRequest(method: "POST", url: "/apps/me/customers/login/ios")
        _ = request.setData([
            "externalRef": externalRef,
            "environment": environment,
            "locale": self.locale,
            "region": await StorePrice.getMostRelevantRegion() ?? NSNull(), // TODO: Check this is not a problem
        ])

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            let data = res.json()["data"] as! [String: Any]

            return LoginResponse(
                customer: data["customer"] as! [String: Any],
                entitlements: data["entitlements"] as! [[String: Any]],
                platformOriginalTransactionIds: data["platformOriginalTransactionIds"] as! [String],
                appleRefundRequests: data["appleRefundRequests"] as? [[String: Any]],
                haveMonitoringRequests: data["haveMonitoringRequests"] as? Bool ?? false
            )
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

        let request = ApiRequest(method: "GET", url: "/apps/me/products/for-app")
        _ = request.addParam("environment", environment)
        _ = request.addParam("locale", self.locale)
        _ = request.addParam("platform", "ios")

        if let region = await StorePrice.getMostRelevantRegion() {
            _ = request.addParam("region", region)
        }

        if identifiers != nil {
            _ = request.addParam("identifiers", identifiers!.joined(separator: ","))
        }

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.json()["data"] as! [[String: Any]]
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Get products in JSON Array format
     */
    public func getSubscriptionGroups(identifiers: [String]?) async throws -> [[String: Any]] {
        if identifiers != nil && identifiers?.count == 0 {
            return []
        }

        let request = ApiRequest(method: "GET", url: "/apps/me/subscription-groups/for-app")
        _ = request.addParam("environment", environment)
        _ = request.addParam("locale", self.locale)
        _ = request.addParam("platform", "ios")

        if let region = await StorePrice.getMostRelevantRegion() {
            _ = request.addParam("region", region)
        }

        if identifiers != nil {
            _ = request.addParam("identifiers", identifiers!.joined(separator: ","))
        }

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.json()["data"] as! [[String: Any]]
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Get products in JSON Array format
     */
    public func getSubscriptionGroupById(id: String) async throws -> [String: Any] {
        let request = ApiRequest(method: "GET", url: "/apps/me/subscription-groups/for-app/\(id)")
        _ = request.addParam("environment", environment)
        _ = request.addParam("locale", self.locale)
        _ = request.addParam("platform", "ios")

        if let region = await StorePrice.getMostRelevantRegion() {
            _ = request.addParam("region", region)
        }

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.json()["data"] as! [String: Any]
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Get entitlements
     */
    public func getCustomerEntitlements(customerId: UUID) async throws -> [[String: Any]] {
        let request = ApiRequest(method: "GET", url: "/apps/me/customers/\(customerId.uuidString.lowercased())/entitlements")
        _ = request.addParam("locale", self.locale)
        _ = request.addParam("loadProduct", "true")

        if let region = await StorePrice.getMostRelevantRegion() {
            _ = request.addParam("region", region)
        }

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.json()["data"] as! [[String: Any]]
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Get external entitlements
     */
    public func getCustomerExternalEntitlements(customerId: UUID, transactions: [String]) async throws -> [[String: Any]] {
        let request = ApiRequest(method: "POST", url: "/apps/me/customers/\(customerId.uuidString.lowercased())/external-entitlements")
        _ = request.setData([
            "locale": self.locale,
            "region": await StorePrice.getMostRelevantRegion() ?? NSNull(), // TODO: Check this is not a problem
            "platform": "ios",
            "loadProduct": true,
            "transactions": transactions,
        ])

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.json()["data"] as! [[String: Any]]
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Get products in JSON Array format
     */
    public func getLastTxPlatformIdForProduct(customerId: UUID, productId: UUID) async throws -> String {
        let request = ApiRequest(method: "GET", url: "/apps/me/transactions/last-platform-tx-id/ios/\(productId.uuidString)")
        _ = request.addParam("customerId", customerId.uuidString.lowercased())

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.json()["data"] as! String
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
            let jsonResponse = res.json()["data"] as! [String: Any]
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
     Take a customerId and an offerId (offerId from MobilyFlow) and return an offer code with redeemURL

     Throws on error.
     */
    public func appleOfferCode(customerId: UUID, offerId: UUID) async throws -> [String: Any] {
        let request = ApiRequest(method: "POST", url: "/apps/me/products/offer-code/ios")
        _ = request.setData(["customerId": customerId.uuidString.lowercased(), "offerId": offerId.uuidString])

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            return res.json()["data"] as! [String: Any]
        } else {
            if res.status == 404 {
                throw MobilyInternalError.no_offer_code_available
            } else {
                throw MobilyError.unknown_error
            }
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
     Flag a refund request.
     Throws on error.
     */
    public func flagRefundRequest(requestId: String, accepted: Bool) async throws {
        let request = ApiRequest(method: "POST", url: "/apps/me/apple-refund-requests/\(requestId)/flag")
        _ = request.setData(["accepted": accepted])

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
        let request = ApiRequest(method: "POST", url: "/apps/me/customer-transfer-ownerships/request/ios")
        _ = request.setData(["customerId": customerId.uuidString.lowercased(), "transactions": transactions])

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        let jsonResponse = res.json()
        if res.success {
            return (jsonResponse["data"] as! [String: Any])["id"]! as! String
        } else {
            if let errorCode = jsonResponse["errorCode"] as? String {
                if let error = MobilyTransferOwnershipError.parse(errorCode) {
                    throw error
                }
            }
            throw MobilyError.unknown_error
        }
    }

    /**
     Get transfer ownership request status from requestId
     */
    public func getTransferRequestStatus(requestId: String) async throws -> String {
        let request = ApiRequest(method: "GET", url: "/apps/me/customer-transfer-ownerships/\(requestId)/status")

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            let jsonResponse = res.json()["data"] as! [String: Any]
            let status = jsonResponse["status"] as! String
            if status == "error" {
                throw MobilyTransferOwnershipError.webhook_failed
            }
            return status
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Force the webhook to be triggered (before Apple Server Notification was send)

     type is "purchase" | "upgrade"
     */
    public func forceWebhook(transactionId: UInt64, productId: UUID, isSandbox: Bool) async throws {
        let request = ApiRequest(method: "POST", url: "/apps/me/platform-notifications/force-webhook/ios")
        _ = request.addData("platformTxId", String(transactionId))
        _ = request.addData("productId", productId.uuidString)
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
    public func getWebhookStatus(transactionOriginalId: UInt64, transactionId: UInt64, isSandbox: Bool, downgradeToProductId: UUID?, downgradeAfterDate: Date?) async throws -> String {
        let request = ApiRequest(method: "GET", url: "/apps/me/events/webhook-status/ios")
        _ = request.addParam("isSandbox", String(isSandbox))
        _ = request.addParam("platformTxOriginalId", String(transactionOriginalId))
        _ = request.addParam("platformTxId", String(transactionId))

        if downgradeToProductId != nil {
            _ = request.addParam("downgradeToProductId", downgradeToProductId!.uuidString)
        }
        if downgradeAfterDate != nil {
            _ = request.addParam("downgradeAfterDate", String(Int(downgradeAfterDate!.timeIntervalSince1970 * 1000)))
        }

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            let jsonResponse = res.json()["data"] as! [String: Any]
            return jsonResponse["status"] as! String
        } else {
            throw MobilyError.unknown_error
        }
    }

    /**
     Upload monitoring file
     */
    public func uploadMonitoring(customerId: UUID?, file: URL) async throws {
        let request = ApiRequest(method: "POST", url: "/apps/me/monitoring/upload")
        _ = request.addData("platform", "ios")
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

    public func isForwardingEnable(externalRef: String?) async throws -> Bool {
        let request = ApiRequest(method: "GET", url: "/apps/me/customers/is-forwarding-enable")
        if externalRef != nil {
            _ = request.addParam("externalRef", externalRef!)
        }
        _ = request.addParam("environment", environment)
        _ = request.addParam("platform", "ios")

        guard let res = try? await self.helper.request(request) else {
            throw MobilyError.server_unavailable
        }

        if res.success {
            let jsonResponse = res.json()["data"] as! [String: Any]
            return jsonResponse["enable"] as! Bool
        } else {
            throw MobilyError.unknown_error
        }
    }
}
