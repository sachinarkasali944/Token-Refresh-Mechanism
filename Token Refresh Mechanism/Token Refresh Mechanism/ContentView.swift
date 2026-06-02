//
//  ContentView.swift
//  Token Refresh Mechanism
//
//  Demo UI for the Token Refresh Mechanism interview question.
//  Shows N concurrent requests, their live status, and proves
//  that only ONE token refresh fires regardless of how many 401s occur.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    @State private var viewModel = DemoViewModel()
    @State private var requestCount: Double = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Header explainer ─────────────────────────────────────────
                headerView

                Divider()

                // ── Request log list ─────────────────────────────────────────
                if viewModel.logs.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    logListView
                }

                Divider()

                // ── Controls ─────────────────────────────────────────────────
                controlsView
            }
            .navigationTitle("Token Refresh Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Sub-views

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Interview Problem", systemImage: "questionmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Multiple API calls can fail with 401 simultaneously.\nHow do you ensure **only ONE** refresh fires?")
                .font(.subheadline)

            if !viewModel.summary.isEmpty {
                Text(viewModel.summary)
                    .font(.footnote.bold())
                    .foregroundStyle(viewModel.summary.contains("1 time") ? .green : .orange)
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Tap **Run Demo** to fire concurrent requests")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding()
    }

    private var logListView: some View {
        List(viewModel.logs) { log in
            RequestRowView(log: log)
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.logs.count)
    }

    private var controlsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Requests: \(Int(requestCount))")
                    .font(.subheadline)
                Spacer()
                Slider(value: $requestCount, in: 2...10, step: 1)
                    .frame(width: 160)
            }

            HStack(spacing: 16) {
                Button(role: .destructive) {
                    viewModel.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRunning)

                Button {
                    Task {
                        await viewModel.runDemo(requestCount: Int(requestCount))
                    }
                } label: {
                    Label(viewModel.isRunning ? "Running…" : "Run Demo",
                          systemImage: viewModel.isRunning ? "hourglass" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - RequestRowView

struct RequestRowView: View {
    let log: RequestLog

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.name)
                    .font(.subheadline.bold())
                Text(log.status.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch log.status {
        case .pending:   return .gray
        case .waiting:   return .orange
        case .retrying:  return .blue
        case .success:   return .green
        case .failed:    return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
