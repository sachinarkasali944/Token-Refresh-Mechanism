# Token Refresh Mechanism — iOS Interview Deep Dive

> **Interview Question:** Multiple API calls can fail with `401 Unauthorized` at the same time. How do you ensure **only ONE** token refresh network call fires, while all waiting callers resume correctly once the new token is available?

---

## Table of Contents
1. [The Problem](#the-problem)
2. [The Solution](#the-solution)
3. [Project Structure](#project-structure)
4. [Architecture & Key Concepts](#architecture--key-concepts)
5. [How It Works — Step by Step](#how-it-works--step-by-step)
6. [Code Walkthrough](#code-walkthrough)
7. [Running the Demo](#running-the-demo)
8. [Interview Talking Points](#interview-talking-points)
9. [Concepts Used](#concepts-used)

---

## The Problem

Imagine your app fires 5 API calls simultaneously (e.g. dashboard loading data from multiple endpoints). The user's access token has just expired. All 5 calls come back with `HTTP 401 Unauthorized`.

**Without a proper mechanism:**
- All 5 callers independently detect the 401.
- All 5 independently call the refresh endpoint.
- You get 5 parallel refresh requests → race conditions, wasted calls, potential server-side invalidation of all tokens.

```
Request-1 → 401 → refreshToken() ─┐
Request-2 → 401 → refreshToken()   ├── All fire at the same time 💥
Request-3 → 401 → refreshToken() ──┘
```

**The goal:** Ensure exactly **one** refresh fires. All other callers *wait* for it, then resume with the new token.

```
Request-1 → 401 → refreshToken()  ← fires the refresh
Request-2 → 401 → waits… ─────────┐
Request-3 → 401 → waits… ─────────┤ all coalesced, resume together ✅
Request-4 → 401 → waits… ─────────┘
```

---

## The Solution

Use Swift's **`actor`** + **`Task` coalescing** pattern:

1. An `actor` enforces serial access to shared state — no locks needed.
2. The first caller to detect a 401 creates a `Task` and stores it.
3. Every subsequent 401 caller checks: *"Is a refresh Task already running?"* If yes, it **awaits the same Task** instead of creating a new one.
4. When the Task completes, **all awaiting callers** resume with the new token simultaneously.
5. The Task reference is cleared so future sessions can refresh again.

---

## Project Structure

```
Token Refresh Mechanism/
├── Core/
│   └── TokenManager.swift       ← ⭐ The heart of the solution (actor + Task coalescing)
├── Network/
│   └── APIClient.swift          ← Simulates API calls; handles 401 → refresh → retry
├── Models/
│   └── RequestLog.swift         ← Observable model for UI state per request
├── ViewModels/
│   └── DemoViewModel.swift      ← @Observable VM; fires concurrent requests
├── ContentView.swift             ← SwiftUI demo UI
└── Token_Refresh_MechanismApp.swift
```

---

## Architecture & Key Concepts

### 1. Swift `actor` — the concurrency gate

```swift
actor TokenManager {
    private var ongoingRefreshTask: Task<String, Error>?
}
```

- An `actor` serialises access to its stored properties.
- No two callers can read/write `ongoingRefreshTask` at the exact same time — the runtime queues them.
- This is safer and simpler than `NSLock` or `DispatchSemaphore`.

### 2. Task coalescing — the deduplication trick

```swift
func refreshAccessToken() async throws -> String {
    if let existingTask = ongoingRefreshTask {
        return try await existingTask.value   // ← join the in-flight task
    }

    let task = Task { try await performRefresh() }
    ongoingRefreshTask = task
    // ... await and clean up
}
```

- `existingTask.value` suspends the caller until the Task finishes.
- Multiple callers awaiting `.value` on the same Task all resume when it completes.
- **Zero extra network calls.**

### 3. Retry-once pattern in APIClient

```swift
func request(name: String) async throws -> APIResponse {
    let token = await tokenManager.getAccessToken()
    let result = await simulateServerCall(token: token)

    if case .failure(.unauthorized) = result {
        let newToken = try await tokenManager.refreshAccessToken()
        return try await simulateServerCall(token: newToken) // retry once
    }
    // ...
}
```

---

## How It Works — Step by Step

```
Time ──────────────────────────────────────────────────────────────▶

[Request-1]  send(stale) → 401 → refreshAccessToken() → creates Task T
[Request-2]  send(stale) → 401 → refreshAccessToken() → sees T, awaits T.value
[Request-3]  send(stale) → 401 → refreshAccessToken() → sees T, awaits T.value
                                          │
                              Task T performs network refresh
                              (1 call, ~1.5s simulated latency)
                                          │
                              T completes → new token = "access_token_4231"
                                          │
                         ┌────────────────┴─────────────────┐
                    Request-1 resumes             Request-2 resumes
                    retry with new token          retry with new token
                                             Request-3 resumes
                                             retry with new token

Result: 3 requests, 1 refresh call ✅
```

---

## Code Walkthrough

### `TokenManager.swift`

The core actor. Key lines:

```swift
// Gate check — join existing refresh
if let existingTask = ongoingRefreshTask {
    return try await existingTask.value
}

// First caller — create and store the Task
let task = Task<String, Error> { try await performRefresh() }
ongoingRefreshTask = task

do {
    let newToken = try await task.value
    accessToken = newToken
    ongoingRefreshTask = nil   // ← clear gate for future refreshes
    return newToken
} catch {
    ongoingRefreshTask = nil   // ← always clear on failure too
    throw error
}
```

### `APIClient.swift`

Simulate a server call; intercept 401; delegate to `TokenManager`:

```swift
if token.hasPrefix("initial") {
    return .failure(.unauthorized)   // simulate stale token → 401
}
```

### `DemoViewModel.swift`

Fire concurrent requests using `TaskGroup`:

```swift
await withTaskGroup(of: Void.self) { group in
    for log in logs {
        group.addTask { await self.perform(log: log) }
    }
}
```

---

## Running the Demo

1. Open `Token Refresh Mechanism.xcodeproj` in Xcode.
2. Select any iOS 17+ simulator.
3. Build & Run (`⌘R`).
4. Tap **Run Demo** — observe the Xcode console:
   - All requests show `401 Unauthorized`.
   - Exactly **one** log line reads `🔄 [TokenManager] Starting token refresh…`.
   - All others read `⏳ [TokenManager] Refresh already in progress — waiting for result…`.
   - After ~1.5 s all requests succeed.

**Console output example:**
```
──────────────────────────────────────────────────
🚀 Firing 5 concurrent requests
──────────────────────────────────────────────────
📡 [Request-1] Sending request…
📡 [Request-2] Sending request…
📡 [Request-3] Sending request…
📡 [Request-4] Sending request…
📡 [Request-5] Sending request…
🚨 [Request-1] 401 Unauthorized — requesting token refresh
🔄 [TokenManager] Starting token refresh…        ← only once!
🚨 [Request-2] 401 Unauthorized — requesting token refresh
⏳ [TokenManager] Refresh already in progress — waiting for result…
🚨 [Request-3] 401 Unauthorized — requesting token refresh
⏳ [TokenManager] Refresh already in progress — waiting for result…
✅ [TokenManager] Token refreshed → access_token_4231
🔁 [Request-1] Retrying with new token: access_token_4231
🔁 [Request-2] Retrying with new token: access_token_4231
🔁 [Request-3] Retrying with new token: access_token_4231
📊 Done — 5/5 succeeded. Token refresh fired: 1 time(s).
```

---

## Interview Talking Points

| Question | Answer |
|---|---|
| Why `actor` instead of `DispatchSemaphore`? | Actors are Swift-native, compile-time safe, and avoid thread-blocking. Semaphores block a thread; actors suspend without blocking. |
| Why store the `Task` instead of a Bool flag? | Storing the Task lets all callers *await its result* directly. A Bool would require a separate mechanism (e.g. continuation queue) to deliver the new token. |
| What happens if the refresh fails? | The Task throws, all awaiting callers also throw, and `ongoingRefreshTask` is cleared so the next request can try again. |
| What if the refresh itself gets a 401? | `performRefresh` would throw `TokenError.serverRejected`. You'd propagate the error and force a logout / re-authentication flow. |
| Can this cause a deadlock? | No. Actors use cooperative scheduling — awaiting inside an actor suspends the caller without blocking any thread. |
| How would you test this? | Inject a mock `TokenManagerProtocol`, control timing with `CheckedContinuation`, assert the mock's `refresh()` was called exactly once. |

---

## Concepts Used

- **Swift Concurrency** — `async/await`, `actor`, `Task`, `TaskGroup`
- **Task Coalescing** — deduplicating async work by sharing a `Task` reference
- **`@Observable`** — macro-based observation for SwiftUI state
- **Retry-once pattern** — intercept 401, refresh, retry the original request
- **Protocol-oriented design** — easy to swap real vs. mock implementations
- **Structured Concurrency** — `withTaskGroup` for bounded concurrent work

---

## Requirements

- Xcode 15+
- iOS 17+ (uses `@Observable` macro)
- Swift 5.9+

---

*Built as a structured learning project to demonstrate iOS interview-level concurrency knowledge.*
