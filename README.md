# carplaymaps

MapKit navigator: search, route, live ETA, turn list. Built for the car — big type, dark map, one-thumb flow.

## CarPlay screen

Navigation apps on the CarPlay display require Apple's `com.apple.developer.carplay-maps` entitlement, granted per-team via the [CarPlay entitlement request form](https://developer.apple.com/contact/carplay/). Until it's granted this runs on the phone; the CarPlay scene ships in the release after approval. Live traffic data lands in v2.

## Build

XcodeGen + CI (macos-26) → TestFlight on push to `main`. No local Xcode needed.
