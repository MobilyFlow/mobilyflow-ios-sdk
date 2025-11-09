//
//  MobilyItem.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 06/11/2025.
//

import Foundation

@objc public class MobilyItem: Serializable {
    @objc public let id: UUID
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let productId: UUID
    @objc public let quantity: Int
    @objc public let Product: MobilyProduct?

    @objc init(id: UUID, createdAt: Date, updatedAt: Date, productId: UUID, quantity: Int, Product: MobilyProduct?) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productId = productId
        self.quantity = quantity
        self.Product = Product
        super.init()
    }

    static func parse(_ jsonItem: [String: Any]) async -> MobilyItem {
        let jsonProduct = jsonItem["Product"] as? [String: Any]

        return MobilyItem(
            id: parseUUID(jsonItem["id"] as! String)!,
            createdAt: parseDate(jsonItem["createdAt"] as! String),
            updatedAt: parseDate(jsonItem["updatedAt"] as! String),
            productId: parseUUID(jsonItem["productId"] as! String)!,
            quantity: jsonItem["quantity"] as! Int,
            Product: jsonProduct != nil ? await MobilyProduct.parse(jsonProduct!) : nil,
        )
    }
}
