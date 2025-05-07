//
//  MobilyPurchaseSDKOptions.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 25/02/2025.
//

import Foundation

@objc public class MobilyPurchaseSDKOptions: NSObject {
    let locales: [String]?
    let debug: Bool
    let apiURL: String?

    @objc public init(
        locales: [String]? = nil,
        debug: Bool = false,
        apiURL: String? = nil
    ) {
        self.locales = locales
        self.debug = debug
        self.apiURL = apiURL
        super.init()
    }
}
