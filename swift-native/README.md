# SpendKit for SwiftUI

A native Apple-platform client for the existing SpendKit demo. Both clients use the same Node.js API and SQLite account state. Card actions still require the demo access code, and the payment simulator evaluates fictional attempts without moving money.

## Run on an iPhone simulator

1. From the repository root, run `node backend/server.mjs` with Node.js 24.
2. Open `swift-native/SpendKitNative.xcodeproj` in Xcode 16 or newer with an iOS simulator runtime installed.
3. Select the **SpendKitNative** scheme, choose an iPhone simulator, and Run. Sign in with **2048**.

The default API address is `http://localhost:8787` for the local simulator and Mac preview. Set `SPENDKIT_API_URL` in the Xcode Run scheme to use another address. A physical iPhone needs a reachable API, typically over HTTPS, because its localhost is the phone itself.

## Preview on a Mac

With the backend running, run:

```sh
swift run --package-path swift-native SpendKitNative
```

On this Mac, the default macOS 27 command-line SDK is missing the SwiftUI macro plug-in. Select the installed 26.5 SDK for the preview:

```sh
swift run --package-path swift-native --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk SpendKitNative
```

Swift Package Manager builds the same SwiftUI sources into a macOS executable. The iOS target is configured separately in the Xcode project.

## How it fits together

- **SwiftUI** renders the dashboard, transaction filters, card controls, simulator and settings.
- **Observation** exposes the signed-in account and server responses to the views. Form values remain local to each screen.
- **URLSession and Codable** communicate with the shared API and decode its response types.
- **LocalAuthentication** provides optional biometric unlock for a locked, still-valid in-memory session. The simulator needs enrolled or simulated biometrics to exercise that path.
- **AppStorage** persists appearance and biometric preferences. SQLite remains the source of truth for card settings.

Run `swift test --package-path swift-native` for the currency tests. To also run the API contract test, set `SPENDKIT_TEST_API` to a SpendKit server started with a fresh, disposable database. The contract test writes card settings.
