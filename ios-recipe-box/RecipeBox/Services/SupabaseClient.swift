//
//  SupabaseClient.swift
//  RecipeBox
//

import Foundation
import Supabase

/// Shared Supabase client. The access-token closure feeds the Rork Auth JWT to
/// Supabase so Row Level Security can scope each user to their own recipes.
let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.EXPO_PUBLIC_SUPABASE_URL)!,
    supabaseKey: Config.EXPO_PUBLIC_SUPABASE_ANON_KEY,
    options: .init(
        auth: .init(
            accessToken: {
                KeychainHelper.get("access_token") ?? ""
            }
        )
    )
)
