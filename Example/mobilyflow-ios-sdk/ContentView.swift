//
//  ContentView.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 16/07/2024.
//

import mobilyflow_ios_sdk
import StoreKit
import SwiftUI

struct ContentView: View {
    let mobily = MobilyPurchaseSDK(
        appId: "caecc000-45ce-49b3-b218-46c1d985ae85",
        apiKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0eXBlIjoiYXBwLXRva2VuIiwic3ViIjoiY2FlY2MwMDAtNDVjZS00OWIzLWIyMTgtNDZjMWQ5ODVhZTg1Iiwic2NvcGUiOjEwLCJpYXQiOjE3MzczNTYyNzIsImV4cCI6MzMyOTQ5NTYyNzJ9.2GDcRmX2dJEfN3S4HANygmOwXqSyGOIsTXVHu5LrLtc",
        environment: MobilyEnvironment.development
    )

    @State var products: [MobilyProduct]?
    @State var error: String?
    @State var storeCountry: String?

    func loadData() async {
        print("appStoreReceiptURL = ", Bundle.main.appStoreReceiptURL ?? "nil")
        do {
//            try await mobily.login(externalId: "304f6c8c-18b2-462f-9df0-28b1e3754715") // gregoire-ios (5eab87d9-8fe0-4333-820e-dd5bfd0f9d82)
            try await mobily.login(externalId: "914b9a20-950b-44f7-bd7b-d81d57992294") // gregoire (4d6d544e-2e08-414a-a29f-799b1022a3d1)

            products = try await mobily.getProducts(identifiers: nil)
            error = nil
            storeCountry = await mobily.getStoreCountry()

            /* for product in products! {
                 print("Product id: \(product.id)")
                 print("Product createdAt: \(product.createdAt)")
                 print("Product updatedAt: \(product.updatedAt)")
                 print("Product identifier: \(product.identifier)")
                 print("Product appId: \(product.appId)")
                 print("Product name: \(product.name)")
                 print("Product description: \(product.description)")
                 print("Product ios_sku: \(product.ios_sku)")
                 print("Product type: \(product.type)")
                 print("Product extras: \(String(describing: product.extras))")
                 print("Product price: \(product.price)")
                 print("Product currency: \(product.currency_code)")
                 print("Product priceFormatted: \(product.price_formatted)")
                 print("Product status: \(product.status)")

                 if product.oneTimeDetails != nil {
                     print("Product isConsumable: \(product.oneTimeDetails!.isConsumable)")
                     print("Product isMultiQuantity: \(product.oneTimeDetails!.isMultiQuantity)")
                     print("Product isNonRenewableSub: \(product.oneTimeDetails!.isNonRenewableSub)")
                 } else {
                     print("ProductperiodCount: \(product.subscriptionDetails!.periodCount)")
                     print("Product periodUnit: \(product.subscriptionDetails!.periodUnit)")
                 }
                 print("===================")
             } */
        } catch MobilyError.server_unavailable {
            self.error = "Network Error"
        } catch MobilyError.store_unavailable {
            self.error = "App Store Error"
        } catch {
            self.error = "Unknown Error"
        }
    }

    var body: some View {
        VStack(spacing: 50) {
            VStack(spacing: 5) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("App Forge Test")
                Text(storeCountry ?? "Unknown")
            }.padding()
            if products == nil && error == nil {
                ProgressView().controlSize(.large)
            } else if error != nil {
                Text(error!).foregroundStyle(Color.red)
            } else {
                ScrollView {
                    VStack {
                        ForEach(products!, id: \.self.id) { product in
                            VStack {
                                ProductButton(sdk: mobily, product: product, offer: nil, quantity: nil)
                                if product.type == ProductType.subscription && product.subscriptionProduct?.promotionalOffers.count ?? 0 > 0 {
                                    VStack {
                                        ForEach(product.subscriptionProduct!.promotionalOffers, id: \.self.id) { offer in
                                            ProductButton(sdk: mobily, product: product, offer: offer, quantity: nil)
                                        }
                                    }.padding(.horizontal, 10)
                                } else if product.type == ProductType.one_time && product.oneTimeProduct?.isMultiQuantity ?? false {
                                    VStack {
                                        ProductButton(sdk: mobily, product: product, offer: nil, quantity: 2)
                                    }.padding(.horizontal, 10)
                                }
                            }
                        }
                    }
                }.padding()
            }
            VStack(spacing: 15) {
                Button("Refresh") {
                    Task {
                        print("Refreshing...")
                        await loadData()
                    }
                }
                Button("Manage subscriptions") {
                    Task {
                        await mobily.openManageSubscription()
                    }
                }
                Button("Transfer Ownership") {
                    Task {
                        do {
                            try await mobily.requestTransferOwnership()
                        } catch {
                            print("Transfer Ownership Error: \(error)")
                        }
                    }
                }
                Button("Send diagnostic") {
                    Task {
                        do {
                            mobily.sendDiagnotic()
                        } catch {
                            print("Send diagnostic Error: \(error)")
                        }
                    }
                }
                Button("Refund Request") {
                    Task {
                        /*
                         ==== TX 2000000824773181 ====
                         id =  2000000824773181
                         originalID =  2000000824773181
                         productID =  consumable_item_test
                         appAccountToken =  EBBB3F5C-F6CD-4C2D-955E-7A4AE2131DE1
                         quantity =  2
                         deviceVerification =  48 bytes
                         purchaseDate =  2025-01-08 13:09:03 +0000
                         expirationDate =  nil
                         signedDate =  2025-01-08 13:09:02 +0000
                         revocationDate =  nil
                         */
                        guard let verificationResult = await Transaction.latest(for: "non_consumable_item_test") else {
                            print("No available TX")
                            return
                        }

                        switch verificationResult {
                        case .verified(let transaction):
                            print("Refund Request: \(transaction.id)")
                            let refundResult = await mobily.openRefundDialog(transactionId: transaction.id)
                            print("Refund Result: \(refundResult)")
                        case .unverified:
                            print("Transaction is not verified")
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .task {
            await loadData()
        }
    }
}

#Preview {
    ContentView()
}
