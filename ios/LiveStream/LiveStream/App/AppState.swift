import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var walletAddress: String?
    @Published var userName: String?

    // TODO: Wire to Dynamic SDK publishers once SDK is linked
    // Example:
    //   DynamicSDK.shared.auth.authenticatedUserChanges
    //     .receive(on: DispatchQueue.main)
    //     .sink { [weak self] user in
    //         self?.isAuthenticated = user != nil
    //         self?.userName = user?.email
    //     }
    //     .store(in: &cancellables)
    //
    //   DynamicSDK.shared.wallets.userWalletsChanges
    //     .receive(on: DispatchQueue.main)
    //     .sink { [weak self] wallets in
    //         self?.walletAddress = wallets.first(where: { $0.chain == "EVM" })?.address
    //     }
    //     .store(in: &cancellables)

    // DEV ONLY: call this to simulate a successful login while Dynamic SDK isn't wired up
    func simulateLogin() {
        isAuthenticated = true
        walletAddress = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        userName = "demo@example.com"
    }

    func logout() {
        isAuthenticated = false
        walletAddress = nil
        userName = nil
        // TODO: DynamicSDK.shared.auth.logout()
    }

    var shortAddress: String? {
        guard let addr = walletAddress, addr.count > 10 else { return walletAddress }
        return addr.prefix(6) + "..." + addr.suffix(4)
    }
}
