//
//  RequestLog.swift
//  Token Refresh Mechanism
//
//  View model for a single request's status in the demo UI.
//

import Foundation

// MARK: - RequestStatus

enum RequestStatus {
    case pending
    case waiting        // Waiting for an ongoing token refresh
    case retrying       // Has the new token; firing retry
    case success(String)
    case failed(String)

    var displayText: String {
        switch self {
        case .pending:           return "⏳ Pending"
        case .waiting:           return "🔄 Waiting for refresh…"
        case .retrying:          return "🔁 Retrying…"
        case .success(let msg):  return "✅ \(msg)"
        case .failed(let msg):   return "❌ \(msg)"
        }
    }

    var color: String {
        switch self {
        case .pending:   return "gray"
        case .waiting:   return "orange"
        case .retrying:  return "blue"
        case .success:   return "green"
        case .failed:    return "red"
        }
    }
}

// MARK: - RequestLog

/// Represents a single API call in the demo log list.
@Observable
final class RequestLog: Identifiable {
    let id = UUID()
    let name: String
    var status: RequestStatus = .pending

    init(name: String) {
        self.name = name
    }
}
