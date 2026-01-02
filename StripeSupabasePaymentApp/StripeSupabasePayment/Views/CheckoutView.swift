//
//  CheckoutView.swift
//  StripeSupabasePayment
//
//  Created by Itsuki on 2026/01/02.
//

import WebKit
import SwiftUI

struct CheckoutView: View {
    static let callbackScheme = "https://itsuki.enjoy.StripeSupabasePayments"
    private static let success = "success"
    private static let cancelled = "cancelled"
    static var successURL: String {
        return "\(self.callbackScheme)?\(self.success)"
    }
    
    static var cancelledURL: String {
        return "\(self.callbackScheme)?\(self.cancelled)"
    }

    let urlString: String
    @State private var webpage: WebPage?
    @State private var navigationTask: Task<Void, Error>?

    @Environment(\.dismiss) private var dismiss
    @State private var decider = NavigationDecider()
    
    var body: some View {
        NavigationStack {
            Group {
                if let webpage = self.webpage {
                    WebView(webpage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    Text("something went wrong")
                }
            }
            .onAppear {
                self.initWebpage()
            }
            .navigationTitle("Checkout")
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing, content: {
                    Button(action: {
                        self.dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                    })
                    .buttonStyle(.glassProminent)
                })
            })
        }
    }
    
    private func initWebpage() {
        self.decider.onCancel = {
            print("cancelled")
            self.dismiss()
        }
        self.decider.onSuccess = {
            print("onSuccess")
            self.dismiss()
        }
        var configuration = WebPage.Configuration()
        
        var navigationPreference = WebPage.NavigationPreferences()
        
        navigationPreference.allowsContentJavaScript = true
        navigationPreference.preferredHTTPSNavigationPolicy = .keepAsRequested
        navigationPreference.preferredContentMode = .mobile
        
        configuration.defaultNavigationPreferences = navigationPreference
    
               
        let page = WebPage(configuration: configuration, navigationDecider: self.decider)
        self.webpage = page
        guard let url = URL(string: self.urlString) else {
            print("invalid url")
            return
        }
        
        page.load(URLRequest(url: url))
        
    }
    
    private struct NavigationDecider: WebPage.NavigationDeciding {
        var onCancel: (() -> Void)?
        var onSuccess: (() -> Void)?
        
        func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
//            print(action)
            guard let url = action.request.url else {
                return .allow
            }
            let urlString = url.absoluteString
            print(urlString)
            if urlString.localizedCaseInsensitiveContains(CheckoutView.callbackScheme) {
                print("cancelled")
                if urlString.localizedCaseInsensitiveContains(CheckoutView.success) {
                    self.onSuccess?()
                }
                if urlString.localizedCaseInsensitiveContains(CheckoutView.cancelled) {
                    self.onCancel?()
                }
                
                return .cancel
            }
            print("allow")
            return .allow
        }
    }

}
