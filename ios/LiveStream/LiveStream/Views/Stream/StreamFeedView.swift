import SwiftUI
import AVKit

// MARK: - BetView

struct BetView: View {
    let videoName: String

    var body: some View {
        ZStack {
            LoopingVideoPlayer(videoName: videoName, videoExtension: "mp4")
                .ignoresSafeArea()
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        .ignoresSafeArea()
    }
}

// MARK: - StreamFeedView

struct StreamFeedView: View {
    private let videos = ["1", "2", "3"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(videos, id: \.self) { name in
                    BetView(videoName: name)
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea()
    }
}

#Preview {
    StreamFeedView()
}
