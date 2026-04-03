import Foundation
import Combine

/// Wraps Dynamic SDK wallet operations.
@MainActor
class WalletService: ObservableObject {
    static let shared = WalletService()

    @Published var address: String?
    @Published var balance: String = "0"

    private var cancellables = Set<AnyCancellable>()

    func onWalletsUpdated() {
        // Called by AppState when Dynamic SDK reports wallet changes.
        // Fetch balance once we have an address.
        guard let addr = address else { return }
        _ = addr // will be used when we call getBalance below
        Task { await refreshBalance() }
    }

    func refreshBalance() async {
        // TODO: uncomment once Dynamic SDK is linked
        // guard let wallet = DynamicSDK.shared.wallets.userWallets.first(where: { $0.chain == "EVM" }) else { return }
        // balance = (try? await DynamicSDK.shared.wallets.getBalance(wallet: wallet)) ?? "0"
        balance = "0.00 OG"
    }
}
