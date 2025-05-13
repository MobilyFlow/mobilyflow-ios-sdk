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
    @objc public let externalRef: String?
    @objc public var isForwardingEnable: Bool

    @objc init(id: UUID, createdAt: Date, updatedAt: Date, externalRef: String?, isForwardingEnable: Bool) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.externalRef = externalRef
        self.isForwardingEnable = isForwardingEnable
        super.init()
    }

    static func parse(jsonCustomer: [String: Any], isForwardingEnable: Bool) -> MobilyCustomer {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]

        return MobilyCustomer(
            id: UUID(uuidString: jsonCustomer["id"]! as! String)!,
            createdAt: dateFormatter.date(from: jsonCustomer["createdAt"]! as! String)!,
            updatedAt: dateFormatter.date(from: jsonCustomer["updatedAt"]! as! String)!,
            externalRef: jsonCustomer["externalRef"]! as? String,
            isForwardingEnable: isForwardingEnable,
        )
    }
}
