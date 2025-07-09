//
//  MobilyPurchaseRefundRequests.swift
//  MobilyflowSDK
//
//  Created by Gregoire Taja on 09/07/2025.
//

import StoreKit
import UIKit

class MobilyPurchaseRefundRequestManager {
    private let API: MobilyPurchaseAPI

    init(API: MobilyPurchaseAPI) {
        self.API = API
    }

    private func showDialog(request: [String: Any]) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Information", message: request["message"] as? String, preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                    continuation.resume(returning: false)
                }))

                alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { _ in
                    continuation.resume(returning: true)
                }))

                if let topVC = getTopViewController() {
                    topVC.present(alert, animated: true, completion: nil)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func manageRefundRequests(_ refundRequests: [[String: Any]]) async {
        for request in refundRequests {
            let result = await self.showDialog(request: request)
            if result {
                let requestType = request["type"] as! String
                let transactionId = UInt64(request["iosTransactionId"] as! String)!

                if requestType == "refund" {
                    try? await Transaction.beginRefundRequest(for: transactionId, in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
                } else if requestType == "cancel" {
                    try? await AppStore.showManageSubscriptions(in: UIApplication.shared.connectedScenes.first as! UIWindowScene)
                }
            }
            try? await self.API.flagRefundRequest(requestId: request["id"] as! String, accepted: result)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 sec
        }
    }
}
