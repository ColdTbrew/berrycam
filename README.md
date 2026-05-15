# BerryCam

BerryCam is a native Swift pet monitor for watching a cat at home while traveling.

The Mac app hosts the MacBook camera and runs a tiny local signaling server. The iPhone app connects to the Mac over Tailscale and receives the live camera feed through WebRTC.

## Architecture

- `BerryCamMac`: macOS SwiftUI host app
  - Captures the MacBook camera with WebRTC's native camera capturer.
  - Runs an HTTP signaling server on the selected port.
  - Answers one iPhone WebRTC offer at a time.
- `BerryCamWatch`: iOS SwiftUI viewer app
  - Connects to the Mac's Tailscale host or `100.x.y.z` address.
  - Creates a receive-only WebRTC offer.
  - Renders the remote video track natively.
- `Shared`: small WebRTC signaling models and SwiftUI video view wrappers.

## Why WebRTC

BerryCam uses WebRTC as the main and only streaming path. It is the right fit for low-latency live video, and Tailscale gives both devices a private address without exposing the MacBook to the public internet.

The project follows the same broad pattern used by native WebRTC demos such as `stasel/WebRTC-iOS`: exchange SDP and ICE candidates through signaling, then let WebRTC carry the media directly.

## Setup

1. Install Xcode.
2. Install XcodeGen if needed:

```bash
brew install xcodegen
```

3. Generate the project:

```bash
xcodegen generate
```

4. Open `BerryCam.xcodeproj`.
5. Let Xcode resolve the Swift Package dependency:

```text
https://github.com/stasel/WebRTC.git
```

## Travel Flow

1. Install Tailscale on the MacBook and iPhone.
2. Sign in to the same Tailscale account on both devices.
3. Start `BerryCamMac` on the MacBook.
4. Enter a private access code and start the host.
5. In `BerryCamWatch`, enter:

```text
MacBook Tailscale name or 100.x.y.z
```

6. Use the same access code and connect.

## MacBook Checklist

- Plug the MacBook into power.
- Disable sleep while plugged in.
- Keep the lid open so the camera remains available.
- Test from iPhone cellular data before leaving.
- Use a private access code.

## Current Status

This is an early native WebRTC implementation. The Xcode project is generated with XcodeGen, and the app code is structured around a Mac-hosted signaling server plus native iOS/macOS WebRTC peers.
