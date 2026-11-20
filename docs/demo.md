# SpendKit live demo script

The [two-minute narrated walkthrough](spendkit-demo.mp4) uses captured Flutter screens. Use the script below for a live walkthrough with the app running at a mobile viewport. Use a phone with enrolled biometrics if you want to capture the native prompt. The browser flow uses code **2048**.

| Time | Show | Narration |
| --- | --- | --- |
| 0:00–0:15 | Sign in and pause on the dashboard. | “SpendKit is a fictional business credit app. The Flutter app consumes a standalone UI package, and Riverpod wires up the local session and mock data.” |
| 0:15–0:35 | Switch months, then open Activity. Search for Figma and apply the Software category. | “Monthly analytics and transaction filters use the same fixture data. Amounts stay in integer pence through aggregation.” |
| 0:35–1:00 | Freeze the card. Enter a wrong code first, then 2048. Show the frozen status. | “The core requires fresh verification for card changes. The visible status updates after the local write succeeds.” |
| 1:00–1:20 | Enable high contrast, then open the component gallery. | “The gallery uses the same buttons, panels, fields, and notices as the app. It reflects the active theme and accessibility preferences.” |
| 1:20–1:45 | Change the button radius in `packages/spendkit_ui/lib/src/components.dart` and hot reload. Show the gallery and the card controls. Undo the change after recording. | “One change to the shared widget appears in multiple flows. The UI kit can run its own widget and component golden tests independently.” |
| 1:45–2:00 | Show the Codemagic workflow and the architecture diagram. | “Codemagic analyzes and tests both packages, then builds Android and an unsigned iOS app. The app core keeps routing and verification out of the shared components.” |

Export the recording as `spendkit-demo.mp4` at 1080p. Link the recording from the repository README after uploading it to your preferred host.
