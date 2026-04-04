import SwiftUI
import DynamicSDKSwift

@main
struct LiveStreamApp: App {
    @StateObject private var appState = AppState()

    init() {
        _ = DynamicSDK.initialize(
            props: ClientProps(
                environmentId: Constants.dynamicEnvironmentId,
                appLogoUrl: Constants.appLogoUrl,
                appName: Constants.appName,
                redirectUrl: Constants.redirectUrl,
                appOrigin: Constants.appOrigin
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
