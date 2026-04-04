import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            StreamFeedView()
                .tabItem {
                    Label("Feed", systemImage: "play.rectangle.fill")
                }

            MarketsView()
                .tabItem {
                    Label("Markets", systemImage: "chart.bar.xaxis")
                }

            BroadcastView()
                .tabItem {
                    Label("Go Live", systemImage: "video.badge.plus")
                }

            AgentsView()
                .tabItem {
                    Label("Agents", systemImage: "cpu")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
        .tint(.red)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
