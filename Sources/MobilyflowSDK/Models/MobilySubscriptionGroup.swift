//
//  MobilyProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

@objc public class MobilySubscriptionGroup: Serializable {
    @objc public let id: String
    @objc public let identifier: String

    @objc public let referenceName: String
    @objc public let name: String
    @objc public let details: String

    @objc public let ios_groupId: String
    @objc public let extras: [String: Any]?

    @objc public var products: [MobilyProduct]

    @objc init(
        id: String, identifier: String, referenceName: String, name: String, details: String, ios_groupId: String, extras: [String: Any]? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.referenceName = referenceName
        self.name = name
        self.details = details
        self.ios_groupId = ios_groupId
        self.extras = extras
        self.products = []

        super.init()
    }

    static func parse(jsonGroup: [String: Any], onlyAvailableProducts: Bool = false) async -> MobilySubscriptionGroup {
        let group = MobilySubscriptionGroup(
            id: jsonGroup["id"]! as! String,
            identifier: jsonGroup["identifier"]! as! String,
            referenceName: jsonGroup["referenceName"]! as! String,
            name: getTranslationValue(jsonGroup["_translations"] as! [[String: Any]], field: "name")!,
            details: getTranslationValue(jsonGroup["_translations"] as! [[String: Any]], field: "description") ?? "",
            ios_groupId: jsonGroup["ios_groupId"]! as! String,
            extras: jsonGroup["extras"] as? [String: Any]
        )

        if let jsonProducts = jsonGroup["Products"] as? [[String: Any]] {
            for jsonProduct in jsonProducts {
                let product = await MobilyProduct.parse(jsonProduct: jsonProduct, fromSubscriptionGroup: group)

                if !onlyAvailableProducts || product.status == .available {
                    group.products.append(product)
                }
            }
        }

        return group
    }
}
