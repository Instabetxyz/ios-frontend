import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                HomeView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}
