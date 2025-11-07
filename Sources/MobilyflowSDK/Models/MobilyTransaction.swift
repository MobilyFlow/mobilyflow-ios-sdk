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
    @objc public let platformTxId: String
    @objc public let platformTxOriginalId: String?
    @objc public let customerId: String
    @objc public let quantity: Int
    @objc public let country: String
    @objc public let priceMillis: Int
    @objc public let currency: String
    @objc public let convertedPriceMillis: Int
    @objc public let convertedCurrency: String
    @objc public let status: String
    @objc public let refundedPercent: Double
    @objc public let productId: String
    @objc public let subscriptionId: String?
    @objc public let itemId: String?
    @objc public let productOfferId: String?
    @objc public let platform: String
    @objc public let startDate: Date?
    @objc public let endDate: Date?
    @objc public let refundDate: Date?
    @objc public let isSandbox: Bool

    @objc init(id: UUID, createdAt: Date, updatedAt: Date, platformTxId: String, platformTxOriginalId: String?, customerId: String, quantity: Int, country: String, priceMillis: Int, currency: String, convertedPriceMillis: Int, convertedCurrency: String, status: String, refundedPercent: Double, productId: String, subscriptionId: String?, itemId: String?, productOfferId: String?, platform: String, startDate: Date?, endDate: Date?, refundDate: Date?, isSandbox: Bool) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.platformTxId = platformTxId
        self.platformTxOriginalId = platformTxOriginalId
        self.customerId = customerId
        self.quantity = quantity
        self.country = country
        self.priceMillis = priceMillis
        self.currency = currency
        self.convertedPriceMillis = convertedPriceMillis
        self.convertedCurrency = convertedCurrency
        self.status = status
        self.refundedPercent = refundedPercent
        self.productId = productId
        self.subscriptionId = subscriptionId
        self.itemId = itemId
        self.productOfferId = productOfferId
        self.platform = platform
        self.startDate = startDate
        self.endDate = endDate
        self.refundDate = refundDate
        self.isSandbox = isSandbox
        super.init()
    }

    static func parse(_ json: [String: Any]) -> MobilyTransaction {
        let platform = json["platform"] as! String
        var platformTxOriginalId = json["platformTxOriginalId"] as? String

        if platform == MobilyPlatform.ANDROID {
            platformTxOriginalId = nil
        }

        return MobilyTransaction(
            id: UUID(uuidString: json["id"] as! String)!,
            createdAt: parseDate(json["createdAt"] as! String),
            updatedAt: parseDate(json["updatedAt"] as! String),
            platformTxId: json["platformTxId"] as! String,
            platformTxOriginalId: platformTxOriginalId,
            customerId: json["customerId"] as! String,
            quantity: (json["quantity"] as? Int) ?? 1,
            country: json["country"] as! String,
            priceMillis: json["priceMillis"] as! Int,
            currency: json["currency"] as! String,
            convertedPriceMillis: json["convertedPriceMillis"] as! Int,
            convertedCurrency: json["convertedCurrency"] as! String,
            status: json["status"] as! String,
            refundedPercent: json["refundedPercent"] as? Double ?? 0.0,
            productId: json["productId"] as! String,
            subscriptionId: json["subscriptionId"] as? String,
            itemId: json["itemId"] as? String,
            productOfferId: json["productOfferId"] as? String,
            platform: platform,
            startDate: parseDateOpt(json["startDate"] as? String),
            endDate: parseDateOpt(json["endDate"] as? String),
            refundDate: parseDateOpt(json["refundDate"] as? String),
            isSandbox: json["isSandbox"] as! Bool,
        )
    }
}
