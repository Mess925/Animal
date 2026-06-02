//
//  SupabaseClient.swift
//  PetHub
//
//  Created by Han Min Thant on 1/6/26.
//

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(
        string: "https://qtgrckjajzcepibnbwnc.supabase.co"
    )!,
    supabaseKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0Z3Jja2phanpjZXBpYm5id25jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyOTczODQsImV4cCI6MjA5NTg3MzM4NH0.MNtrJMjoWjE1TpcS7HLl1zcG2M_ciY-Rvygf7zm-Njs"
)
