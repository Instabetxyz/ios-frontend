import SwiftUI
import AVKit
import DynamicSDKSwift

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let videoExtension: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            return view
        }
        let player = AVPlayer(url: url)
        player.isMuted = true
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(playerLayer)
        player.play()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct AuthView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            LoopingVideoPlayer(videoName: "bg", videoExtension: "mp4")
                .ignoresSafeArea()

            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)

                    Text("Arcadia")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)        
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        do {
                            try DynamicSDK.shared.ui.showAuth()
                        } catch {
                            print("Error showing auth: \(error)")
                        }
                    } label: {
                        Text("Sign in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.purple)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }                    
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
}
