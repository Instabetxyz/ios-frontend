import Foundation
import Combine
import DynamicSDKSwift

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var walletAddress: String?
    @Published var userName: String?
    @Published var authToken: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        guard let sdk = try? DynamicSDK.shared else {
            print("⚠️ DynamicSDK not initialized yet")
            return
        }

        sdk.auth.authenticatedUserChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.isAuthenticated = user != nil
                self?.userName = user?.email
            }
            .store(in: &cancellables)

        sdk.auth.tokenChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] token in
                self?.authToken = token
                StreamBetClient.shared.authToken = token
                if let token {
                    StreamBetWebSocket.shared.connect(token: token)
                }
            }
            .store(in: &cancellables)

        sdk.wallets.userWalletsChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wallets in
                self?.walletAddress = wallets.first(where: { $0.chain == "EVM" })?.address
                WalletService.shared.address = self?.walletAddress
                WalletService.shared.onWalletsUpdated()
            }
            .store(in: &cancellables)
    }

    func logout() async {
        do {
            try await DynamicSDK.shared.auth.logout()
        } catch {
            print("Logout failed: \(error)")
        }
    }

    var shortAddress: String? {
        guard let addr = walletAddress, addr.count > 10 else { return walletAddress }
        return addr.prefix(6) + "..." + addr.suffix(4)
    }
}
