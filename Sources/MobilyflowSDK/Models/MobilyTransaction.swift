//
//  MobilyTransaction.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 07/11/2025.
//

import Foundation

@objc public class MobilyTransaction: Serializable {
    @objc public let id: UUID
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let storeId: String
    @objc public let storeOriginalId: String?
    @objc public let customerId: UUID
    @objc public let quantity: Int
    @objc public let country: String
    @objc public let priceMillis: Int
    @objc public let currency: String
    @objc public let convertedPriceMillis: Int
    @objc public let convertedCurrency: String
    @objc public let status: String
    @objc public let refundedPercent: Double
    @objc public let productId: UUID
    @objc public let subscriptionId: UUID?
    @objc public let itemId: UUID?
    @objc public let productOfferId: UUID?
    @objc public let platform: String
    /// Store where the purchase was made (`MobilyStore`), whereas `platform` is the OS of the device.
    /// nil for purchases made before this field existed, until the backend backfill runs.
    @objc public let store: String?
    @objc public let startsAt: Date?
    @objc public let endsAt: Date?
    @objc public let refundedAt: Date?
    @objc public let isSandbox: Bool

    @objc init(id: UUID, createdAt: Date, updatedAt: Date, storeId: String, storeOriginalId: String?, customerId: UUID, quantity: Int, country: String, priceMillis: Int, currency: String, convertedPriceMillis: Int, convertedCurrency: String, status: String, refundedPercent: Double, productId: UUID, subscriptionId: UUID?, itemId: UUID?, productOfferId: UUID?, platform: String, store: String?, startsAt: Date?, endsAt: Date?, refundedAt: Date?, isSandbox: Bool) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.storeId = storeId
        self.storeOriginalId = storeOriginalId
        self.customerId = customerId
        self.quantity = quantity
        self.country = country
        self.priceMillis = priceMillis
        self.currency = currency
        self.convertedPriceMillis = convertedPriceMillis
        self.convertedCurrency = convertedCurrency
        self.status = MobilyTransactionStatus.parse(status)
        self.refundedPercent = refundedPercent
        self.productId = productId
        self.subscriptionId = subscriptionId
        self.itemId = itemId
        self.productOfferId = productOfferId
        self.platform = MobilyPlatform.parse(platform)
        self.store = MobilyStore.parse(store)
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.refundedAt = refundedAt
        self.isSandbox = isSandbox
        super.init()
    }

    static func parse(_ json: [String: Any]) -> MobilyTransaction {
        let platform = json["platform"] as! String
        var storeOriginalId = json["storeOriginalId"] as? String

        if platform == MobilyPlatform.ANDROID {
            storeOriginalId = nil
        }

        return MobilyTransaction(
            id: parseUUID(json["id"] as! String),
            createdAt: parseDate(json["createdAt"] as! String),
            updatedAt: parseDate(json["updatedAt"] as! String),
            storeId: json["storeId"] as! String,
            storeOriginalId: storeOriginalId,
            customerId: parseUUID(json["customerId"] as! String),
            quantity: (json["quantity"] as? Int) ?? 1,
            country: json["country"] as! String,
            priceMillis: json["priceMillis"] as! Int,
            currency: json["currency"] as! String,
            convertedPriceMillis: json["convertedPriceMillis"] as! Int,
            convertedCurrency: json["convertedCurrency"] as! String,
            status: MobilyTransactionStatus.parse(json["status"] as! String),
            refundedPercent: json["refundedPercent"] as? Double ?? 0.0,
            productId: parseUUID(json["productId"] as! String),
            subscriptionId: parseUUIDOpt(json["subscriptionId"] as? String),
            itemId: parseUUIDOpt(json["itemId"] as? String),
            productOfferId: parseUUIDOpt(json["productOfferId"] as? String),
            platform: platform,
            store: json["store"] as? String,
            startsAt: parseDateOpt(json["startsAt"] as? String),
            endsAt: parseDateOpt(json["endsAt"] as? String),
            refundedAt: parseDateOpt(json["refundedAt"] as? String),
            isSandbox: json["isSandbox"] as! Bool,
        )
    }
}
