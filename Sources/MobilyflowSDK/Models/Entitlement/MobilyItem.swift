//
//  MobilyItem.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 06/11/2025.
//

import Foundation

@objc public class MobilyItem: Serializable {
    @objc public let id: String
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let productId: String
    @objc public let quantity: Int
    @objc public let Product: MobilyProduct

    @objc init(id: String, createdAt: Date, updatedAt: Date, productId: String, quantity: Int, Product: MobilyProduct) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productId = productId
        self.quantity = quantity
        self.Product = Product
        super.init()
    }

    static func parse(jsonItem: [String: Any]) async -> MobilyItem {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]

        return MobilyItem(
            id: jsonItem["id"] as! String,
            createdAt: dateFormatter.date(from: jsonItem["createdAt"]! as! String)!,
            updatedAt: dateFormatter.date(from: jsonItem["updatedAt"]! as! String)!,
            productId: jsonItem["productId"] as! String,
            quantity: jsonItem["quantity"] as! Int,
            Product: await MobilyProduct.parse(jsonProduct: jsonItem["Product"] as! [String: Any]),
        )
    }
}
