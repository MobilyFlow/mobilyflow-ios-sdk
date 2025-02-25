//
//  MobilyProduct.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation
import StoreKit

public class MobilySubscriptionGroup {
    public let id: String
    public let identifier: String

    public let name: String
    public let description: String

    public let ios_groupId: String
    public let extras: [String: Any]?

    public var products: [MobilyProduct]

    init(
        id: String, identifier: String, name: String, description: String, ios_groupId: String, extras: [String: Any]? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.name = name
        self.description = description
        self.ios_groupId = ios_groupId
        self.extras = extras
        self.products = []
    }

    static func parse(jsonGroup: [String: Any]) -> MobilySubscriptionGroup {
        return MobilySubscriptionGroup(
            id: jsonGroup["id"]! as! String,
            identifier: jsonGroup["identifier"]! as! String,
            name: jsonGroup["name"]! as! String,
            description: jsonGroup["description"] as? String ?? "",
            ios_groupId: jsonGroup["ios_groupId"]! as! String,
            extras: jsonGroup["extras"] as? [String: Any]
        )
    }
}
