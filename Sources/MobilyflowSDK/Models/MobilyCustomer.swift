//
//  MobilyCustomer.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/07/2024.
//

import Foundation

@objc public class MobilyCustomer: Serializable {
    @objc public let id: UUID
    @objc public let createdAt: Date
    @objc public let updatedAt: Date
    @objc public let externalRef: String
    @objc public var forwardNotificationEnable: Bool
    @objc public var testOfferCodeMode: String?

    @objc init(id: UUID, createdAt: Date, updatedAt: Date, externalRef: String, forwardNotificationEnable: Bool, testOfferCodeMode: String?) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.externalRef = externalRef
        self.forwardNotificationEnable = forwardNotificationEnable
        self.testOfferCodeMode = testOfferCodeMode
        super.init()
    }

    static func parse(_ jsonCustomer: [String: Any]) -> MobilyCustomer {
        return MobilyCustomer(
            id: parseUUID(jsonCustomer["id"] as! String),
            createdAt: parseDate(jsonCustomer["createdAt"] as! String),
            updatedAt: parseDate(jsonCustomer["updatedAt"] as! String),
            externalRef: jsonCustomer["externalRef"] as! String,
            forwardNotificationEnable: jsonCustomer["forwardNotificationEnable"] as! Bool,
            testOfferCodeMode: jsonCustomer["testOfferCodeMode"] as? String
        )
    }
}
