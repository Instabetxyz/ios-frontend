import SwiftUI
import AVFoundation

struct BroadcastView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var broadcaster = HLSBroadcastService.shared
    @StateObject private var machinefi = MachineFiService.shared
    @State private var streamTitle = ""
    @State private var isStartingStream = false
    @State private var currentStreamId: String?
    @State private var showEndConfirm = false
    @State private var showPermissionAlert = false
    @State private var showMarketSheet = false
    @State private var pendingMarketStreamId: String?
    @State private var marketCondition = ""
    @State private var isCreatingMarket = false
    @State private var createdMarketId: String?
    @State private var verifyCondition = "Is there a person visible in the frame?"

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
        .sheet(isPresented: $showMarketSheet) {
            marketCreationSheet
        }
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

                VStack(spacing: 8) {
                    // Stream info + end button
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

                    // MachineFi verification panel
                    machineFiPanel
                }
                .padding()
                .background(.black.opacity(0.6))
            }
        }
        .confirmationDialog("End live stream?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Stream", role: .destructive) {
                Task { await endStream() }
            }
            Button("Keep Streaming", role: .cancel) {}
        }
    }

    private var machineFiPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MachineFi Verify")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button {
                    guard let sid = currentStreamId else { return }
                    Task { await machinefi.checkStream(streamId: sid, condition: verifyCondition) }
                } label: {
                    if machinefi.isChecking {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Text("Check")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.purple)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .disabled(machinefi.isChecking || currentStreamId == nil)
            }

            if let result = machinefi.lastResult {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: result.triggered ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.triggered ? .green : .red)
                        .font(.caption)
                    Text(result.explanation)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(3)
                }
            } else if let err = machinefi.errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .padding(.top, 4)
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
            pendingMarketStreamId = streamId
            showMarketSheet = true
        } catch {
            broadcaster.error = error.localizedDescription
        }
    }

    private var marketCreationSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 44))
                        .foregroundStyle(.purple)
                    Text("Create Prediction Market")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Let viewers bet on what happens in your stream")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bet Condition")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("e.g. Will I finish this feature in 60 seconds?", text: $marketCondition, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }
                .padding(.horizontal)

                if let marketId = createdMarketId {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Market created!")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(marketId.prefix(8) + "…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontDesign(.monospaced)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task { await createMarket() }
                    } label: {
                        HStack {
                            if isCreatingMarket {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Market")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(marketCondition.trimmingCharacters(in: .whitespaces).count < 5 || isCreatingMarket || createdMarketId != nil)

                    Button("Skip") { showMarketSheet = false }
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showMarketSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func createMarket() async {
        guard let streamId = pendingMarketStreamId else { return }
        let condition = marketCondition.trimmingCharacters(in: .whitespaces)
        guard condition.count >= 5 else { return }
        isCreatingMarket = true
        defer { isCreatingMarket = false }
        do {
            let streamUrl = APIClient.shared.hlsUrl(for: streamId).absoluteString
            let result = try await StreamBetClient.shared.createStreamMarket(
                streamUrl: streamUrl,
                condition: condition,
                title: streamTitle.isEmpty ? nil : streamTitle
            )
            createdMarketId = result.marketId
        } catch {
            print("Failed to create market: \(error)")
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
