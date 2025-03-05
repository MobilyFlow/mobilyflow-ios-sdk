//
//  MobilyPurchaseSDKOptions.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 25/02/2025.
//

@objc public class MobilyPurchaseSDKOptions: NSObject {
    let languages: [String]?
    let debug: Bool?
    let apiURL: String?

    init(
        languages: [String]? = nil,
        debug: Bool? = nil,
        apiURL: String? = nil
    ) {
        self.languages = languages
        self.debug = debug
        self.apiURL = apiURL
        super.init()
    }
}
