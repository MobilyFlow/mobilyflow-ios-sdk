//
//  utils.swift
//  MobilyPurchaseSDK
//
//  Created by Gregoire Taja on 17/10/2024.
//

import Foundation
import StoreKit

/**
 * Coalesce function that return the first non-nil or non-NSNull value
 */
func coalesce(_ values: Any?...) -> Any? {
    for val in values {
        if val != nil, !(val! is NSNull) {
            return val
        }
    }
    return nil
}

func formatPrice(_ price: Decimal, currencyCode: String) -> String {
    let formatter = NumberFormatter()
    formatter.currencyCode = currencyCode
    formatter.numberStyle = .currency

    if let formatted = formatter.string(from: price as NSDecimalNumber) {
        return formatted
    } else {
        Logger.e("formatPrice fail for args \(price) \(currencyCode) -> fallback")
        return price.formatted() + currencyCode
    }
}

func calcWaitWebhookTime(_ retry: Int) -> UInt32 {
    var delay: Decimal = 2.0 + Decimal(retry) * 0.5
    delay = min(delay, 5.0)
    return UInt32(truncating: NSDecimalNumber(decimal: delay * 1000000.0)) // convert to micro seconds
}

/**
 Check if directory is empty (this ignore the precense of .DS_Store file)
 */
func isDirectoryEmpty(_ url: URL) -> Bool {
    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        var countFile = 0
        for file in fileURLs {
            let filename = file.lastPathComponent
            if !(filename == ".DS_Store" || filename == "." || filename == "..") {
                countFile += 1
            }
        }
        return countFile == 0
    } catch {
        return false
    }
}

func getPreferredLocales(_ locales: [String]?) -> [String] {
    return locales != nil ? locales! : NSLocale.preferredLanguages
}

func isSandboxTransaction(transaction: Transaction) -> Bool {
    let isSandbox: Bool

    if #available(iOS 16.0, *) {
        isSandbox = transaction.environment != .production
    } else {
        // This is not 100% reliable: it can produce false negative, but the worst behavior in that case is
        // error during waiting but in Sandbox only
        isSandbox = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    return isSandbox
}

func printTransaction(transaction: Transaction) async {
    print("==== TX \(transaction.id) ====")

    print("id = ", transaction.id)
    print("originalID = ", transaction.originalID)
    print("productID = ", transaction.productID)
    print("appAccountToken = ", transaction.appAccountToken?.uuidString.lowercased() ?? "nil")
    print("quantity = ", transaction.purchasedQuantity)
    print("purchaseDate = ", transaction.purchaseDate)
    print("expirationDate = ", transaction.expirationDate ?? "nil")
    print("signedDate = ", transaction.signedDate)
    print("revocationDate = ", transaction.revocationDate ?? "nil")
    print("isUpgraded = ", transaction.isUpgraded)
    print("==============================")
}
