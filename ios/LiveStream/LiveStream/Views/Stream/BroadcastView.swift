import SwiftUI
import AVFoundation

struct BroadcastView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var broadcaster = HLSBroadcastService.shared
    @State private var streamTitle = ""
    @State private var isStartingStream = false
    @State private var currentStreamId: String?
    @State private var showEndConfirm = false
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if broadcaster.isLive {
                    liveView
                } else {
                    previewView
                }
            }
            .navigationTitle(broadcaster.isLive ? "" : "Go Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Pre-live setup

    private var previewView: some View {
        VStack(spacing: 0) {
            CameraPreviewView(session: broadcaster.session)
                .frame(maxWidth: .infinity)
                .aspectRatio(9/16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)

            VStack(spacing: 20) {
                TextField("Stream title…", text: $streamTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button {
                    Task { await goLive() }
                } label: {
                    HStack {
                        if isStartingStream {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text("Go Live")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }
                .disabled(streamTitle.isEmpty || isStartingStream)
            }
            .padding(.top, 24)

            Spacer()
        }
        .onAppear { broadcaster.startSession() }
        .onDisappear { if !broadcaster.isLive { broadcaster.stopSession() } }
        .alert("Camera Access Needed", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera and microphone access in Settings.")
        }
    }

    // MARK: - Live broadcast

    private var liveView: some View {
        ZStack {
            CameraPreviewView(session: broadcaster.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    liveBadge
                    Spacer()
                    Text(timeString(broadcaster.elapsedSeconds))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .padding()

                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(streamTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(appState.shortAddress ?? "")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .fontDesign(.monospaced)
                    }
                    Spacer()
                    Button {
                        showEndConfirm = true
                    } label: {
                        Text("End")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(.black.opacity(0.4))
            }
        }
        .confirmationDialog("End live stream?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Stream", role: .destructive) {
                Task { await endStream() }
            }
            Button("Keep Streaming", role: .cancel) {}
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
            Text("LIVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func goLive() async {
        guard await checkPermissions() else {
            showPermissionAlert = true
            return
        }

        isStartingStream = true
        defer { isStartingStream = false }

        do {
            let streamId = try await APIClient.shared.startStream(
                title: streamTitle,
                creatorAddress: appState.walletAddress ?? "unknown"
            )
            currentStreamId = streamId
            broadcaster.startBroadcast(streamId: streamId)
        } catch {
            broadcaster.error = error.localizedDescription
        }
    }

    private func endStream() async {
        await broadcaster.stopBroadcast()
        if let streamId = currentStreamId {
            _ = try? await APIClient.shared.endStream(streamId: streamId)
        }
        currentStreamId = nil
        streamTitle = ""
        broadcaster.stopSession()
    }

    private func checkPermissions() async -> Bool {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if videoStatus == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .video)
        }
        if audioStatus == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
        return videoStatus == .authorized && audioStatus == .authorized
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Camera preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        var session: AVCaptureSession? {
            didSet { previewLayer.session = session }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.videoGravity = .resizeAspectFill
        }
    }
}

#Preview {
    BroadcastView()
        .environmentObject(AppState())
}
