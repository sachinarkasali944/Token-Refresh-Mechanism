//
//  DemoViewModel.swift
//  Token Refresh Mechanism
//
//  Drives the demo UI.
//  Fires N concurrent API requests and records each one's lifecycle.
//

import Foundation
import Observation

// MARK: - DemoViewModel

@Observable
@MainActor
final class DemoViewModel {

    // MARK: State
    var logs: [RequestLog] = []
    var refreshCount: Int = 0
    var isRunning: Bool = false
    var summary: String = ""

    private let apiClient = APIClient.shared

    // MARK: - Actions

    /// Fires `count` concurrent API requests to demonstrate the refresh coalescing.
    func runDemo(requestCount: Int = 5) async {
        guard !isRunning else { return }

        // Reset state
        isRunning = true
        refreshCount = 0
        summary = ""
        logs = (1...requestCount).map { RequestLog(name: "Request-\($0)") }

        print("\n" + String(repeating: "─", count: 50))
        print("🚀 Firing \(requestCount) concurrent requests")
        print(String(repeating: "─", count: 50))

        // Track how many refreshes actually fire (should always be 1)
        await withTaskGroup(of: Void.self) { group in
            for log in logs {
                group.addTask { [weak self] in
                    await self?.perform(log: log)
                }
            }
        }

        // Build summary
        let successCount = logs.filter {
            if case .success = $0.status { return true }
            return false
        }.count

        summary = "Done — \(successCount)/\(requestCount) succeeded. Token refresh fired: \(refreshCount) time(s)."
        print("\n📊 \(summary)")
        isRunning = false
    }

    func reset() {
        logs = []
        refreshCount = 0
        summary = ""
        isRunning = false
    }

    // MARK: - Private

    private func perform(log: RequestLog) async {
        do {
            log.status = .pending
            let response = try await apiClient.request(name: log.name)
            log.status = .success(response.data)
        } catch {
            log.status = .failed(error.localizedDescription)
        }
    }
}
