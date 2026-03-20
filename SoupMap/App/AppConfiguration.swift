import Foundation

struct AppConfiguration {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let mapboxAccessToken: String
    let urlScheme: String
    let bundleIdentifier: String

    var authCallbackURL: URL {
        URL(string: "\(urlScheme)://auth/callback")!
    }

    init(bundle: Bundle = .main) {
        guard
            let supabaseURLString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let supabaseURL = URL(string: supabaseURLString),
            let supabaseAnonKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let mapboxAccessToken = bundle.object(forInfoDictionaryKey: "MAPBOX_ACCESS_TOKEN") as? String,
            let urlScheme = bundle.object(forInfoDictionaryKey: "SOUPMAP_URL_SCHEME") as? String,
            let bundleIdentifier = bundle.object(forInfoDictionaryKey: "SOUPMAP_BUNDLE_ID") as? String,
            !supabaseAnonKey.isEmpty,
            !mapboxAccessToken.isEmpty,
            !urlScheme.isEmpty,
            !bundleIdentifier.isEmpty
        else {
            fatalError("Missing runtime configuration. Populate Config/Secrets.xcconfig before launching SoupMap.")
        }

        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.mapboxAccessToken = mapboxAccessToken
        self.urlScheme = urlScheme
        self.bundleIdentifier = bundleIdentifier
    }
}
