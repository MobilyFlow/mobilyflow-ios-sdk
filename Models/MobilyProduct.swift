//
//  MobilyProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

class MobilyProduct {
    public let id: String
    public let createdAt: Date
    public let updatedAt: Date
    public let identifier: String
    public let appId: String

    public let name: String
    public let description: String

    public let ios_sku: String
    public let type: ProductType
    public let extras: [String: Any]?

    public let status: ProductStatus
    public let oneTimeProduct: MobilyOneTimeProduct?
    public let subscriptionProduct: MobilySubscriptionProduct?

    init(
        id: String, createdAt: Date, updatedAt: Date, identifier: String, appId: String, name: String, description: String, ios_sku: String, type: ProductType, extras: [String: Any]? = nil, status: ProductStatus, oneTimeProduct: MobilyOneTimeProduct? = nil, subscriptionProduct: MobilySubscriptionProduct? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.identifier = identifier
        self.appId = appId
        self.name = name
        self.description = description
        self.ios_sku = ios_sku
        self.type = type
        self.extras = extras
        self.status = status
        self.oneTimeProduct = oneTimeProduct
        self.subscriptionProduct = subscriptionProduct
    }

    static func parse(jsonProduct: [String: Any]) async -> MobilyProduct {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFractionalSeconds]

        let type = ProductType(rawValue: jsonProduct["type"]! as! String)!

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
            description: jsonProduct["description"]! as! String,
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
