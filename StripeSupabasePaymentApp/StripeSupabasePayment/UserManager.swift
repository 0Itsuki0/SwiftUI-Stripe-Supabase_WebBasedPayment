//
//  SupabaseManager.swift
//  SupabaseAuth
//
//  Created by Itsuki on 2025/12/29.
//

import AuthenticationServices
import Supabase
import SwiftUI


@Observable
class UserManager {
    static let customerPortalLink: String =
        "https://billing.stripe.com/p/login/xxx"

    var showResetPasswordView: Bool = false

    var session: Session? {
        didSet {
            if let session {
                print(session.accessToken)
            }
        }
    }

    private(set) var entitlement: Entitlement? {
        didSet {
            if let entitlement {
                print(entitlement)
            }
        }
    }

    private let supabase: SupabaseClient

    @ObservationIgnored
    private var authStateChangeTask: Task<Void, Error>?

    @ObservationIgnored
    private var entitlementChangeTask: Task<Void, Error>?

    @ObservationIgnored
    private var channel: RealtimeChannelV2?

    init() throws {
        guard let urlString = SupabaseConfig["SUPABASE_URL"],
            let url = URL(string: urlString),
            let key = SupabaseConfig["SUPABASE_ANON_KEY"]
        else {
            throw SupabaseError.missingSupabaseConfig
        }

        self.supabase = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            //    Initial session emitted after attempting to refresh the local stored session.
            //    This is incorrect behavior and will be fixed in the next major release since it's a breaking change.
            //    To opt-in to the new behavior now, set `emitLocalSessionAsInitialSession: true` in your AuthClient configuration.
            //    The new behavior ensures that the locally stored session is always emitted, regardless of its validity or expiration.
            //    If you rely on the initial session to opt users in, you need to add an additional check for `session.isExpired` in the session.
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )

        self.listenForAuthChange()
    }

    deinit {
        self.authStateChangeTask?.cancel()
        self.authStateChangeTask = nil
        self.entitlementChangeTask?.cancel()
        self.entitlementChangeTask = nil
        Task { [weak self] in
            await self?.supabase.removeAllChannels()
        }
    }

    func initializeEntitlement() async throws {
        self.entitlement = try await self.supabase.from("user_entitlements")
            .select().single().execute().value
    }

    func listenForEntitlementChanges() async throws {
        guard self.entitlementChangeTask == nil else {
            return
        }
        let channel = supabase.channel("table-db-changes")
        self.channel = channel

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "user_entitlements"
        )

        try await channel.subscribeWithError()

        print("subscribed")

        self.entitlementChangeTask = Task {
            for await update in updates {
                print("updates")
                guard !Task.isCancelled else {
                    return
                }
                do {
                    let record =
                        try update.decodeRecord(
                            decoder: PostgrestClient.Configuration.jsonDecoder
                        ) as Entitlement
                    self.entitlement = record
                } catch (let error) {
                    print(error)
                }
            }
        }
    }

    func createCheckoutSession(for product: SubscriptionProduct) async throws
        -> String
    {
        guard session != nil else {
            throw SupabaseError.userNotLoggedIn
        }

        let response: CreateCheckoutSessionResponse =
            try await supabase.functions.invoke(
                "create-checkout-session",
                options: .init(
                    method: .post,
                    body: CreateCheckoutSessionRequest(
                        price_id: product.priceId,
                        success_url: CheckoutView.successURL,
                        cancelled_url: CheckoutView.cancelledURL
                    )
                )
            )

        print(response)
        return response.url
    }

    // set up auth state change listener to listen for any session updates.
    func listenForAuthChange() {
        self.authStateChangeTask = Task {
            // alternative with callback
            // await self.supabase.auth.onAuthStateChange({ event, session in   })

            for await (event, session) in self.supabase.auth.authStateChanges {
                guard !Task.isCancelled else {
                    break
                }
                print("auth state change for event: \(event)")

                // Note:
                // The session emitted in the `AuthChangeEvent/initialSession` event may have been expired since last launch, consider checking for `Session/isExpired`. If this is the case, then expect a `AuthChangeEvent/tokenRefreshed` after.
                if session?.isExpired == true {
                    continue
                }

                self.session = session

            }

        }
    }

    func signInWithApple(_ result: Result<ASAuthorization, any Error>)
        async throws
    {
        let identityToken: String
        let appleIdCredential: ASAuthorizationAppleIDCredential

        switch result {
        case .failure(let error):
            throw error

        case .success(let authorization):
            guard
                let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential
            else {
                throw NSError(domain: "invalid credential type", code: 500)
            }

            appleIdCredential = credential

            guard
                let data = credential.identityToken,
                let token = String(data: data, encoding: .utf8)
            else {
                throw NSError(domain: "invalid identity token", code: 500)
            }

            identityToken = token

        }

        _ = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: identityToken
            )
        )

        // fullName is provided only in the first time (account creation),
        // so checking if it is non-nil to not erase data on login.
        if let fullName = appleIdCredential.fullName?.formatted() {
            _ = try? await supabase.auth.update(
                user: UserAttributes(data: ["full_name": .string(fullName)])
            )
        }

    }

    func signOut() async throws {
        guard self.session != nil else { return }
        try await supabase.auth.signOut()
    }
}
