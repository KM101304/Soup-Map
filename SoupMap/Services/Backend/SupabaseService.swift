import Foundation
import Supabase

final class SupabaseService {
    let client: SupabaseClient

    init(configuration: AppConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.supabaseURL,
            supabaseKey: configuration.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(flowType: .pkce)
            )
        )
    }
}
