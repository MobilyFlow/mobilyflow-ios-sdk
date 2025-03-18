//
//  MobilyProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

@objc public class MobilyProduct: Serializable {
    @objc public let id: String
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let identifier: String
    @objc public let appId: String

    @objc public let name: String
    @objc public let details: String

    @objc public let ios_sku: String
    @objc public let type: ProductType
    @objc public let extras: [String: Any]?

    @objc public let status: ProductStatus
    @objc public let oneTimeProduct: MobilyOneTimeProduct?
    @objc public let subscriptionProduct: MobilySubscriptionProduct?

    @objc init(
        id: String, createdAt: Date, updatedAt: Date, identifier: String, appId: String, name: String, details: String, ios_sku: String, type: ProductType, extras: [String: Any]? = nil, status: ProductStatus, oneTimeProduct: MobilyOneTimeProduct? = nil, subscriptionProduct: MobilySubscriptionProduct? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.identifier = identifier
        self.appId = appId
        self.name = name
        self.details = details
        self.ios_sku = ios_sku
        self.type = type
        self.extras = extras
        self.status = status
        self.oneTimeProduct = oneTimeProduct
        self.subscriptionProduct = subscriptionProduct
        super.init()
    }

    static func parse(jsonProduct: [String: Any]) async -> MobilyProduct {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]

        let type = ProductType.parse(jsonProduct["type"]! as! String)!

        var status: ProductStatus
        var oneTimeProduct: MobilyOneTimeProduct? = nil
        var subscriptionProduct: MobilySubscriptionProduct? = nil

        if type == .one_time {
            oneTimeProduct = MobilyOneTimeProduct.parse(jsonProduct: jsonProduct)
            status = oneTimeProduct!.status
        } else {
            subscriptionProduct = await MobilySubscriptionProduct.parse(jsonProduct: jsonProduct)
            status = subscriptionProduct!.status
        }

        let product = MobilyProduct(
            id: jsonProduct["id"]! as! String,
            createdAt: dateFormatter.date(from: jsonProduct["createdAt"]! as! String)!,
            updatedAt: dateFormatter.date(from: jsonProduct["updatedAt"]! as! String)!,
            identifier: jsonProduct["identifier"]! as! String,
            appId: jsonProduct["appId"]! as! String,
            name: jsonProduct["name"]! as! String,
            details: jsonProduct["description"]! as! String,
            ios_sku: jsonProduct["ios_sku"]! as! String,
            type: type,
            extras: jsonProduct["extras"]! as! [String: Any]?,
            status: status,
            oneTimeProduct: oneTimeProduct,
            subscriptionProduct: subscriptionProduct
        )

        return product
    }
}
