//
//  SupabaseError.swift
//  SupabaseAuth
//
//  Created by Itsuki on 2025/12/30.
//

import Foundation

enum SupabaseError: Error, LocalizedError {
    case missingSupabaseConfig
    case userNotLoggedIn
}
