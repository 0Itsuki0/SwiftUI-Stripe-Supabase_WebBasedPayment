//
//  LoginView.swift
//  StripeSupabasePayment
//
//  Created by Itsuki on 2026/01/02.
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(UserManager.self) private var userManager

    @State private var error: Error?
    @State private var loadingMessage: String? = nil

    var body: some View {
        @Bindable var userManager = userManager

        VStack {
            SignInWithAppleButton(.signIn, onRequest: { request in
                request.requestedScopes = [.email, .fullName]
            }, onCompletion: { result in
                Task {
                    do {
                        try await self.userManager.signInWithApple(result)
                    } catch(let error) {
                        self.error = error
                    }
                }
            })
            .fixedSize()
            
            if let error {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            }

        }
        .padding()
        .navigationTitle("Auth With Apple!")
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
        .navigationDestination(
            item: $userManager.session,
            destination: { session in
                PrivateView(session: session)
                    .environment(userManager)
            }
        )
        .overlay {
            if let loadingMessage {
                ProgressView(loadingMessage)
                    .controlSize(.extraLarge)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.gray.opacity(0.7))
            }
        }

    }

}

