//
//  SupabaseClient.swift
//  RecipeBox
//

import Foundation

/// Lightweight Supabase REST + Edge Functions client built directly on
/// `URLSession`. Using plain networking instead of the Supabase Swift SDK keeps
/// the app free of embedded third-party dynamic frameworks, which is what allows
/// it to be signed and installed on a device without issues.
///
/// The Rork Auth JWT (stored in the Keychain) is forwarded as the bearer token so
/// PostgREST Row Level Security and the edge functions' `requireAuth` both see the
/// signed-in user.
nonisolated enum Supabase {
    private static let baseURL = Config.EXPO_PUBLIC_SUPABASE_URL
    private static let anonKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY

    enum SupabaseError: Error, CustomStringConvertible {
        case invalidURL
        case http(status: Int, body: String)

        var description: String {
            switch self {
            case .invalidURL:
                return "invalid_url"
            case let .http(status, body):
                return "http_\(status): \(body)"
            }
        }
    }

    // MARK: - Coders matching PostgREST / edge function payloads

    /// Encodes dates as ISO-8601 with fractional seconds (what timestamptz expects).
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(isoFormatter.string(from: date))
        }
        return encoder
    }()

    /// Decodes the timestamp variants PostgREST returns (with or without
    /// fractional seconds, with `Z` or `+00:00` offsets).
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseTimestamp(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unparseable timestamp: \(raw)"
            )
        }
        return decoder
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parseTimestamp(_ raw: String) -> Date? {
        // PostgREST emits "+00:00" offsets and may include microseconds; normalize
        // to something ISO8601DateFormatter accepts.
        var value = raw
        if value.hasSuffix("+00:00") {
            value = String(value.dropLast(6)) + "Z"
        }
        // Trim fractional seconds to milliseconds (formatter supports up to 3 digits).
        if let dotIndex = value.firstIndex(of: "."),
           let zIndex = value.firstIndex(of: "Z") {
            let fraction = value[value.index(after: dotIndex)..<zIndex]
            if fraction.count > 3 {
                let trimmed = fraction.prefix(3)
                value = String(value[..<value.index(after: dotIndex)]) + trimmed + "Z"
            }
        }
        return isoFormatter.date(from: value) ?? isoFormatterPlain.date(from: value)
    }

    // MARK: - Request plumbing

    private static func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        let token = KeychainHelper.get("access_token")
        let bearer = (token?.isEmpty == false) ? token! : anonKey
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        return request
    }

    @discardableResult
    private static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.http(status: -1, body: "no_response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.http(status: http.statusCode, body: body)
        }
        return data
    }

    // MARK: - PostgREST

    /// Selects every row from a table the signed-in user can see (RLS applies).
    static func select<T: Decodable & Sendable>(_ table: String, as type: T.Type = T.self) async throws -> [T] {
        guard let url = URL(string: "\(baseURL)/rest/v1/\(table)?select=*") else {
            throw SupabaseError.invalidURL
        }
        let data = try await send(makeRequest(url: url, method: "GET"))
        return try decoder.decode([T].self, from: data)
    }

    /// Inserts or updates rows, merging on the primary key.
    static func upsert<T: Encodable & Sendable>(_ table: String, values: [T]) async throws {
        guard !values.isEmpty else { return }
        guard let url = URL(string: "\(baseURL)/rest/v1/\(table)") else {
            throw SupabaseError.invalidURL
        }
        var request = makeRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(values)
        try await send(request)
    }

    /// Convenience for upserting a single row.
    static func upsert<T: Encodable & Sendable>(_ table: String, value: T) async throws {
        try await upsert(table, values: [value])
    }

    /// Patches rows matching `column == value`.
    static func update<T: Encodable & Sendable>(
        _ table: String,
        values: T,
        eqColumn: String,
        eqValue: String
    ) async throws {
        let encodedValue = eqValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? eqValue
        guard let url = URL(string: "\(baseURL)/rest/v1/\(table)?\(eqColumn)=eq.\(encodedValue)") else {
            throw SupabaseError.invalidURL
        }
        var request = makeRequest(url: url, method: "PATCH")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(values)
        try await send(request)
    }

    // MARK: - Edge Functions

    /// Invokes an edge function with a JSON body and decodes its JSON response.
    static func invokeFunction<Body: Encodable & Sendable, T: Decodable & Sendable>(
        _ name: String,
        body: Body
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)/functions/v1/\(name)") else {
            throw SupabaseError.invalidURL
        }
        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try encoder.encode(body)
        let data = try await send(request)
        return try decoder.decode(T.self, from: data)
    }
}
