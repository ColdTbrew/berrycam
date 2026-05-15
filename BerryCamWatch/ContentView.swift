import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewer: ViewerWebRTCService
    @State private var host = "100.x.y.z"
    @State private var port = "3000"
    @State private var accessCode = "berrycam"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            WebRTCVideoView(track: viewer.remoteVideoTrack)
                .ignoresSafeArea()
                .opacity(viewer.remoteVideoTrack == nil ? 0 : 1)

            if viewer.remoteVideoTrack == nil {
                VStack(spacing: 12) {
                    Image(systemName: "cat")
                        .font(.system(size: 54, weight: .semibold))
                    Text("Waiting for BerryCam")
                        .font(.title2.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.76))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("BerryCam")
                        .font(.title2.weight(.bold))
                    Spacer()
                    Text(viewer.connectionState)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.82))
                        .clipShape(Capsule())
                }

                if !viewer.isWatching {
                    TextField("Mac Tailscale host", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    SecureField("Access code", text: $accessCode)

                    Button {
                        viewer.connect(host: host, port: UInt16(port) ?? 3000, accessCode: accessCode)
                    } label: {
                        Label("Connect", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        viewer.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(16)
        }
    }
}
