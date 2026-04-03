import SwiftUI

@main
struct LiveStreamApp: App {
    @StateObject private var appState = AppState()

    init() {
        // TODO: Initialize Dynamic SDK once added via SPM
        // let config = DynamicSDKConfiguration(
        //     environmentId: Constants.dynamicEnvironmentId,
        //     appName: Constants.appName,
        //     appLogoUrl: Constants.appLogoUrl,
        //     redirectUrl: Constants.redirectUrl,
        //     appOrigin: Constants.appOrigin
        // )
        // DynamicSDK.initialize(config: config)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
