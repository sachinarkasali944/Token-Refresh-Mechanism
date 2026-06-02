//
//  TokenManager.swift
//  Token Refresh Mechanism
//
//  Core problem: Multiple API calls can fail with 401 simultaneously.
//  Ensure ONLY ONE token refresh happens, and all waiting calls resume after.
//
//  Solution: Use an actor + continuation-based queue.
//  - Actor guarantees serial access to state (no data races).
//  - When a refresh is already in progress, new callers await the same Task.
//  - Once the refresh completes, ALL waiting callers resume with the new token.
//

import Foundation

// MARK: - TokenManager

/// Thread-safe token manager using Swift `actor` to prevent data races.
/// Guarantees a single in-flight refresh even under concurrent 401 failures.
actor TokenManager {

    // MARK: Singleton
    static let shared = TokenManager()
    private init() {}

    // MARK: State
    private var accessToken: String = "initial_access_token"
    private var refreshToken: String = "initial_refresh_token"

    /// When non-nil, a refresh is already in flight.
    /// All new callers will await this same Task instead of starting another.
    private var ongoingRefreshTask: Task<String, Error>?

    // MARK: - Public API

    /// Returns the current access token.
    func getAccessToken() -> String {
        return accessToken
    }

    /// Entry point called whenever a 401 is encountered.
    /// Guarantees only one network refresh call fires, regardless of
    /// how many callers invoke this concurrently.
    func refreshAccessToken() async throws -> String {
        // ── Key insight ──────────────────────────────────────────────────────
        // If a refresh Task is already running, just await it and return its
        // result — no second network call is made.
        if let existingTask = ongoingRefreshTask {
            print("⏳ [TokenManager] Refresh already in progress — waiting for result…")
            return try await existingTask.value
        }

        // ── First caller: create the refresh Task ────────────────────────────
        print("🔄 [TokenManager] Starting token refresh…")
        let task = Task<String, Error> {
            try await performRefresh()
        }
        ongoingRefreshTask = task

        do {
            let newToken = try await task.value
            // Persist the new token and clear the gate
            accessToken = newToken
            ongoingRefreshTask = nil
            print("✅ [TokenManager] Token refreshed → \(newToken)")
            return newToken
        } catch {
            // Clear the gate so future calls can try again
            ongoingRefreshTask = nil
            print("❌ [TokenManager] Refresh failed: \(error)")
            throw error
        }
    }

    // MARK: - Private helpers

    /// Simulates a real token-refresh network call (replace with URLSession in prod).
    private func performRefresh() async throws -> String {
        // Simulate network latency
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 s

        // Simulate occasional server-side failure (20% chance)
        if Int.random(in: 1...5) == 1 {
            throw TokenError.serverRejected
        }

        let newToken = "access_token_\(Int.random(in: 1000...9999))"
        refreshToken = "refresh_token_\(Int.random(in: 1000...9999))"
        return newToken
    }
}

// MARK: - Errors

enum TokenError: LocalizedError {
    case serverRejected
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .serverRejected:  return "Server rejected the refresh request."
        case .unauthorized:    return "No valid session — please log in again."
        }
    }
}
