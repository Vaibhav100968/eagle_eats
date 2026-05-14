import Foundation

enum SupabaseConfig {

    static let url: URL = {
        guard let raw = value(for: "SUPABASE_URL"),
              let url = URL(string: raw) else {
            fatalError("Missing SUPABASE_URL in Secrets.plist — see Secrets.plist.example")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = value(for: "SUPABASE_ANON_KEY"), !key.isEmpty,
              !key.hasPrefix("YOUR_") else {
            fatalError("Missing SUPABASE_ANON_KEY in Secrets.plist — see Secrets.plist.example")
        }
        return key
    }()

    private static func value(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let val = dict[key] as? String else {
            return nil
        }
        return val
    }
}
