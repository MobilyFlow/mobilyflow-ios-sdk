//
//  MobilyEvent.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 07/11/2025.
//

import Foundation
import StoreKit

@objc public class MobilyEvent: Serializable {
    @objc public let id: UUID
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let transactionId: UUID?
    @objc public let subscriptionId: UUID?
    @objc public let itemId: UUID?
    @objc public let type: String
    @objc public let extras: [String: Any]?
    @objc public let platform: String
    @objc public let isSandbox: Bool

    @objc public let Customer: MobilyCustomer?
    @objc public let Product: MobilyProduct?
    @objc public let ProductOffer: MobilySubscriptionOffer?
    @objc public let Transaction: MobilyTransaction?
    @objc public let Subscription: MobilySubscription?
    @objc public let Item: MobilyItem?

    @objc init(id: UUID, createdAt: Date, updatedAt: Date, transactionId: UUID?, subscriptionId: UUID?, itemId: UUID?, type: String, extras: [String: Any]?, platform: String, isSandbox: Bool, Customer: MobilyCustomer?, Product: MobilyProduct?, ProductOffer: MobilySubscriptionOffer?, Transaction: MobilyTransaction?, Subscription: MobilySubscription?, Item: MobilyItem?) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transactionId = transactionId
        self.subscriptionId = subscriptionId
        self.itemId = itemId
        self.type = type
        self.extras = extras
        self.platform = MobilyPlatform.parse(platform)
        self.isSandbox = isSandbox
        self.Customer = Customer
        self.Product = Product
        self.ProductOffer = ProductOffer
        self.Transaction = Transaction
        self.Subscription = Subscription
        self.Item = Item
        super.init()
    }

    static func parse(_ json: [String: Any], storeAccountTransactions: [UInt64: Transaction]) async -> MobilyEvent {
        let jsonCustomer = json["Customer"] as? [String: Any]
        let jsonProduct = json["Product"] as? [String: Any]
        let jsonProductOffer = json["ProductOffer"] as? [String: Any]
        let jsonTransaction = json["Transaction"] as? [String: Any]
        let jsonSubscription = json["Subscription"] as? [String: Any]
        let jsonItem = json["Item"] as? [String: Any]

        var product: MobilyProduct? = nil
        var productOffer: MobilySubscriptionOffer? = nil

        if let jsonProduct = jsonProduct {
            product = await MobilyProduct.parse(jsonProduct)

            if let jsonProductOffer = jsonProductOffer {
                let iosProduct = MobilyPurchaseRegistry.getIOSProduct(product!.ios_sku)
                productOffer = await MobilySubscriptionOffer.parse(jsonProduct: jsonProduct, jsonOffer: jsonProductOffer, iosProduct: iosProduct)
            }
        }

        return MobilyEvent(
            id: parseUUID(json["id"] as! String)!,
            createdAt: parseDate(json["createdAt"] as! String),
            updatedAt: parseDate(json["updatedAt"] as! String),
            transactionId: parseUUID(json["transactionId"] as? String),
            subscriptionId: parseUUID(json["subscriptionId"] as? String),
            itemId: parseUUID(json["itemId"] as? String),
            type: json["type"] as! String,
            extras: json["extras"] as? [String: Any],
            platform: json["platform"] as! String,
            isSandbox: json["isSandbox"] as! Bool,

            Customer: jsonCustomer != nil ? MobilyCustomer.parse(jsonCustomer!) : nil,
            Product: product,
            ProductOffer: productOffer,
            Transaction: jsonTransaction != nil ? MobilyTransaction.parse(jsonTransaction!) : nil,
            Subscription: jsonSubscription != nil ? await MobilySubscription.parse(jsonSubscription!, storeAccountTransactions: storeAccountTransactions) : nil,
            Item: jsonItem != nil ? await MobilyItem.parse(jsonItem!) : nil,
        )
    }
}
