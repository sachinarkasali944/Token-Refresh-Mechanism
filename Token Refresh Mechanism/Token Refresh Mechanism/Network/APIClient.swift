//
//  APIClient.swift
//  Token Refresh Mechanism
//
//  Simulates real API calls that can fail with HTTP 401.
//  On 401 it delegates token refresh to TokenManager and retries ONCE.
//  All callers sharing the same TokenManager will coalesce their refresh.
//

import Foundation

// MARK: - APIClient

final class APIClient {

    // MARK: Singleton
    static let shared = APIClient()
    private init() {}

    private let tokenManager = TokenManager.shared

    // MARK: - Simulated API call

    /// Makes a fake API request identified by `requestName`.
    ///
    /// Flow:
    /// 1. Attach current token.
    /// 2. Simulate the server call.
    /// 3. If the server returns 401, refresh the token and retry once.
    /// 4. Return success or propagate the error.
    func request(name: String) async throws -> APIResponse {
        print("📡 [\(name)] Sending request…")

        let token = await tokenManager.getAccessToken()
        let result = await simulateServerCall(requestName: name, token: token)

        switch result {
        case .success(let response):
            return response

        case .failure(let error) where error == .unauthorized:
            // ── 401 path ────────────────────────────────────────────────────
            print("🚨 [\(name)] 401 Unauthorized — requesting token refresh")
            let newToken = try await tokenManager.refreshAccessToken()
            print("🔁 [\(name)] Retrying with new token: \(newToken)")

            // Retry once with the refreshed token
            let retryResult = await simulateServerCall(requestName: name, token: newToken)
            switch retryResult {
            case .success(let response): return response
            case .failure(let retryError): throw retryError
            }

        case .failure(let error):
            throw error
        }
    }

    // MARK: - Private helpers

    /// Simulates a server response.
    /// Forces a 401 on the FIRST call so all demo requests trigger refresh.
    private var callCount = 0
    private let lock = NSLock()

    private func simulateServerCall(requestName: String,
                                    token: String) async -> Result<APIResponse, APIError> {
        // Simulate network latency (0.1 – 0.5 s)
        let delay = UInt64.random(in: 100_000_000...500_000_000)
        try? await Task.sleep(nanoseconds: delay)

        lock.lock()
        callCount += 1
        let count = callCount
        lock.unlock()

        // First few calls use a stale token → simulate 401
        if token.hasPrefix("initial") {
            print("🔴 [\(requestName)] Server: 401 (stale token detected)")
            return .failure(.unauthorized)
        }

        print("🟢 [\(requestName)] Server: 200 OK (call #\(count))")
        return .success(APIResponse(requestName: requestName,
                                    data: "Response data for \(requestName)",
                                    token: token))
    }
}

// MARK: - Supporting types

struct APIResponse {
    let requestName: String
    let data: String
    let token: String
}

enum APIError: Error, Equatable {
    case unauthorized
    case networkError(String)
}
