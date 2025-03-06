//
//  StorekitUtils.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 03/02/2025.
//

import StoreKit

func getRenewalInfo(tx: Transaction?) async -> Product.SubscriptionInfo.RenewalInfo? {
    guard let subscriptionStatus = await tx?.subscriptionStatus else {
        return nil
    }

    guard case .verified(let renewalInfo) = subscriptionStatus.renewalInfo else {
        return nil
    }

    return renewalInfo
}
