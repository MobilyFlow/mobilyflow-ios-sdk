//
//  Serializable.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 18/03/2025.
//

import Foundation

@objc public class Serializable: NSObject {
    static func parseValue(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .collection {
            let rawArray = value as! [Any]
            return rawArray.map {
                Serializable.parseValue($0)
            }
        } else {
            if let val = value as? Serializable {
                return val.toDictionary()
            } else if let val = value as? Date {
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                return dateFormatter.string(from: val)
            } else if let val = value as? any RawRepresentable {
                return val.rawValue
            } else {
                return value
            }
        }
    }

    @objc public func toDictionary() -> [String: Any] {
        var dict = [String: Any]()

        let mirror = Mirror(reflecting: self)

        for child in mirror.children {
            if let label = child.label {
                dict[label] = Serializable.parseValue(child.value)
            }
        }

        return dict
    }
}
