# Token Refresh Mechanism

> One shared refresh operation for concurrent requests that receive HTTP 401.

A Swift Concurrency learning demo showing how an actor and a shared Task coordinate token refresh, followed by a single retry of each original request.

## Highlights

- Coalesce concurrent refresh attempts.
- Retry an unauthorised request once after refresh.
- Observe simulated requests and their results in SwiftUI.
- Separate token management from the API client and demo view model.

## Open and run

1. Clone this repository and open `Token Refresh Mechanism/Token Refresh Mechanism.xcodeproj` in Xcode.
2. Select the app scheme and a simulator compatible with the deployment target in **Build Settings → iOS Deployment Target**. Use an Xcode version with SDK support for that target.
3. Build and run with **⌘R**. For a physical device, select your development team.

```bash
git clone https://github.com/sachinarkasali944/Token-Refresh-Mechanism.git
cd Token-Refresh-Mechanism
open "Token Refresh Mechanism/Token Refresh Mechanism.xcodeproj"
```

## Demo scope

Requests, server responses, and tokens are simulated. No live authentication server or production credential storage is provided.

## Explore the code

- [Xcode project](./Token%20Refresh%20Mechanism/Token%20Refresh%20Mechanism.xcodeproj)
- [Project files](./Token%20Refresh%20Mechanism)

## Further reading

[Read the detailed implementation guide](./Token%20Refresh%20Mechanism/README.md).
