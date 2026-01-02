//
//  ContentView.swift
//  StripeSupabasePayment
//
//  Created by Itsuki on 2025/12/30.
//

import SwiftUI

struct ContentView: View {
    @State private var userManager: UserManager? =
        try? UserManager()

    var body: some View {
        NavigationStack {
            Group {
                if let userManager = self.userManager {
                    LoginView()
                        .environment(userManager)
                } else {
                    ContentUnavailableView(
                        "Supabase Config Missing",
                        systemImage: "slash.circle",
                        description: Text(
                            "Make sure to have `Supabase.plist` set up correctly."
                        )
                    )
                }
            }
        }
    }
}
