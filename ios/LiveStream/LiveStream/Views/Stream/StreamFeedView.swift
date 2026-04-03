import SwiftUI

struct StreamFeedView: View {
    @StateObject private var api = APIClient.shared
    @State private var streams: [Stream] = []
    @State private var isLoading = false
    @State private var selectedStream: Stream?

    var liveStreams: [Stream] { streams.filter { $0.status == .live } }
    var archivedStreams: [Stream] { streams.filter { $0.status == .archived } }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && streams.isEmpty {
                    ProgressView("Loading streams…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if streams.isEmpty {
                    ContentUnavailableView("No streams yet", systemImage: "video.slash", description: Text("Be the first to go live."))
                } else {
                    List {
                        if !liveStreams.isEmpty {
                            Section("🔴 Live Now") {
                                ForEach(liveStreams) { stream in
                                    StreamCard(stream: stream)
                                        .onTapGesture { selectedStream = stream }
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                            }
                        }

                        if !archivedStreams.isEmpty {
                            Section("Recent") {
                                ForEach(archivedStreams) { stream in
                                    StreamCard(stream: stream)
                                        .onTapGesture { selectedStream = stream }
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await loadStreams() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await loadStreams() }
            .sheet(item: $selectedStream) { stream in
                if stream.status == .live {
                    LivePlayerView(stream: stream)
                } else {
                    StreamPlayerView(stream: stream)
                }
            }
        }
        .task { await loadStreams() }
    }

    private func loadStreams() async {
        isLoading = true
        defer { isLoading = false }
        streams = (try? await APIClient.shared.getStreams()) ?? []
    }
}

// MARK: - Stream card

struct StreamCard: View {
    let stream: Stream

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 52)
                Image(systemName: "video.fill")
                    .foregroundStyle(.gray)
                if stream.status == .live {
                    VStack {
                        HStack {
                            Spacer()
                            Text("LIVE")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.red)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        Spacer()
                    }
                    .padding(4)
                    .frame(width: 80, height: 52)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stream.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(stream.shortAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)

                Text(stream.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StreamFeedView()
}
