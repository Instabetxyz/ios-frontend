import Foundation

enum Constants {    
    static let dynamicEnvironmentId = "bd2e9ff1-167f-4fa8-bc77-bcaf79335c81"
    static let appLogoUrl = "https://avatars.githubusercontent.com/u/105617514"
    static let appName = "Arcadia"
    static let redirectScheme = "arcadia"
    static let redirectUrl = "arcadia://callback"
    static let appOrigin = "https://arcadia.app"

    // 0G Galileo Testnet
    static let chainId: Int = 16602
    static let rpcUrl = "https://evmrpc-testnet.0g.ai"

    // Backend (stubbed for now — set to your ngrok/backend URL when ready)
    static let backendBaseUrl = "http://localhost:3000"

    // StreamBet prediction market API
    static let streamBetBaseUrl = "https://api.streambet.xyz/v1"
    static let streamBetWsUrl = "wss://api.streambet.xyz/v1/stream/websocket"
}
