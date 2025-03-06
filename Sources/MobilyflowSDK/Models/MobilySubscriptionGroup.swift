//
//  MobilyProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

@objc public class MobilySubscriptionGroup: NSObject {
    @objc public let id: String
    @objc public let identifier: String

    @objc public let name: String
    @objc public let details: String

    @objc public let ios_groupId: String
    @objc public let extras: [String: Any]?

    @objc public var products: [MobilyProduct]

    @objc init(
        id: String, identifier: String, name: String, details: String, ios_groupId: String, extras: [String: Any]? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.details = details
        self.ios_groupId = ios_groupId
        self.extras = extras
        self.products = []

        super.init()
    }

    static func parse(jsonGroup: [String: Any]) -> MobilySubscriptionGroup {
        return MobilySubscriptionGroup(
            id: jsonGroup["id"]! as! String,
            identifier: jsonGroup["identifier"]! as! String,
            name: jsonGroup["name"]! as! String,
            details: jsonGroup["description"] as? String ?? "",
            ios_groupId: jsonGroup["ios_groupId"]! as! String,
            extras: jsonGroup["extras"] as? [String: Any]
        )
    }
}
