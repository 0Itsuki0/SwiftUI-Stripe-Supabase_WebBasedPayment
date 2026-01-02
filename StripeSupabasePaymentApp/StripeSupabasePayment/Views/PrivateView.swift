//
//  PrivateView.swift
//  StripeSupabasePayment
//
//  Created by Itsuki on 2026/01/02.
//

import SwiftUI
import Supabase

struct PrivateView: View {
    @Environment(UserManager.self) private var userManager: UserManager
    
    var session: Session
    
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var urlString: String? = nil
    @State private var showCheckoutView: Bool = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        let user = session.user

        List {
            Section("User Info") {
                row("ID", user.id.uuidString)
                if let email = user.email {
                    row("Email", email)
                }
                row("Create At", user.createdAt.formatted())
                if let lastSignInAt = user.lastSignInAt {
                    row("Last Sign In At", lastSignInAt.formatted())
                }
            }
        
        
            Section("Subscription") {
                if let entitlement = userManager.entitlement, let priceId = entitlement.price_id, let product = SubscriptionProduct(priceId: priceId) {
                    row("Current Plan", product.productName)
                    Button(action: {
                        guard let url = URL(string: UserManager.customerPortalLink) else {
                            return
                        }
                        openURL(url)
                    }, label: {
                        Text("Manage Subscription")
                    })
                } else {
                    HStack(spacing: 24) {
                        ForEach(SubscriptionProduct.allProducts) { product in
                            Button(action: {
                                self.createCheckoutSession(for: product)
                            }, label: {
                                Text(product.productName)
                            })
                            .buttonStyle(.borderedProminent)
                            .containerRelativeFrame(.horizontal, count: 2, spacing: 24)
                        }

                    }
                    .listRowBackground(Color.clear)
                   
                    
                }
            }
            
            Button(
                action: {
                    Task {
                        self.isLoading = true
                        do {
                            try await userManager.signOut()
                        } catch (let error) {
                            self.errorMessage = error.localizedDescription
                        }
                        self.isLoading = false
                    }
                },
                label: {
                    Text("Sign Out")
                }
            )

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Your Private World!")
        .navigationBarBackButtonHidden()
        .disabled(self.isLoading)
        .overlay {
            if self.isLoading {
                ProgressView()
                    .controlSize(.extraLarge)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.gray.opacity(0.7))
            }
        }
        .task {
            do {
                try await self.userManager.initializeEntitlement()
                try await self.userManager.listenForEntitlementChanges()
            } catch(let error) {
                print(error)
                self.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: self.urlString, {
            if self.urlString != nil {
                self.showCheckoutView = true
            }
        })
        .onChange(of: self.showCheckoutView, {
            if !showCheckoutView {
                self.urlString = nil
            }
        })
        .sheet(isPresented: $showCheckoutView, content: {
            if let urlString {
                CheckoutView(urlString: urlString)
            }
        })
    }
    
    @ViewBuilder
    private func row(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            Text(right)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

        }
    }
    
    private func createCheckoutSession(for product: SubscriptionProduct) {
        Task {
            self.isLoading = true
            do {
                let url = try await self.userManager.createCheckoutSession(for: product)
                self.urlString = url
            } catch(let error) {
                print(error.localizedDescription)
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false

        }
    }

}
