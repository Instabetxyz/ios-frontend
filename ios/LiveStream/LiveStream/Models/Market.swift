import Foundation

// MARK: - Enums

enum SBMarketStatus: String, Codable {
    case active, resolved, cancelled
}

enum SBBetSide: String, Codable {
    case yes, no
}

enum SBFollowMode: String, Codable {
    case copy, short, none
}

// MARK: - Market list item (GET /v1/markets)

struct SBMarket: Identifiable, Codable {
    var id: String { marketId }
    let marketId: String
    let streamId: String
    let title: String
    let condition: String
    let streamUrl: String
    let status: SBMarketStatus
    let createdBy: String
    let isAgentStream: Bool
    let yesOdds: Double
    let noOdds: Double
    let yesPoolWei: String
    let noPoolWei: String
    let totalVolumeWei: String
    let startsAt: Int
    let endsAt: Int
    let secondsRemaining: Int?
    let nextCursor: String?
    let total: Int?

    var yesPoolEth: Double { weiToEth(yesPoolWei) }
    var noPoolEth: Double { weiToEth(noPoolWei) }
    var totalVolumeEth: Double { weiToEth(totalVolumeWei) }
}

struct PaginatedMarkets: Codable {
    let markets: [SBMarket]
    let nextCursor: String?
    let total: Int
}

// MARK: - Market detail (GET /v1/markets/:id)

struct SBMarketDetail: Codable {
    let marketId: String
    let streamId: String
    let streamUrl: String
    let title: String
    let condition: String
    let status: SBMarketStatus
    let outcome: String?
    let resolutionReason: String?
    let trioExplanation: String?
    let resolvedAt: Int?
    let resolveTxHash: String?
    let yesOdds: Double
    let noOdds: Double
    let yesPoolWei: String
    let noPoolWei: String
    let totalVolumeWei: String
    let startsAt: Int
    let endsAt: Int
    let agentPositions: [SBAgentPosition]
    let recentBets: [SBRecentBet]

    var yesPoolEth: Double { weiToEth(yesPoolWei) }
    var noPoolEth: Double { weiToEth(noPoolWei) }
    var totalVolumeEth: Double { weiToEth(totalVolumeWei) }
}

struct SBAgentPosition: Codable {
    let agentId: String
    let agentName: String
    let side: SBBetSide
    let amountWei: String
    let pctPool: Double

    var amountEth: Double { weiToEth(amountWei) }
}

struct SBRecentBet: Identifiable, Codable {
    var id: String { betId }
    let betId: String
    let userId: String
    let side: SBBetSide
    let amountWei: String
    let placedAt: Int

    var amountEth: Double { weiToEth(amountWei) }
}

// MARK: - Bet response (POST /v1/markets/:id/bet)

struct SBBetResponse: Codable {
    let betId: String
    let marketId: String
    let userId: String
    let side: SBBetSide
    let amountWei: String
    let txHash: String
    let placedAt: Int
    let updatedOdds: SBUpdatedOdds
    let mirroredBets: [SBMirroredBet]
}

struct SBUpdatedOdds: Codable {
    let yesOdds: Double
    let noOdds: Double
    let yesPoolWei: String
    let noPoolWei: String
    let totalVolumeWei: String
}

struct SBMirroredBet: Codable {
    let betId: String
    let userId: String
    let side: SBBetSide
    let amountWei: String
}

// MARK: - Stream market (POST /v1/stream)

struct SBStreamMarket: Codable {
    let streamId: String
    let marketId: String
    let trioJobId: String
    let streamUrl: String
    let condition: String
    let title: String
    let status: SBMarketStatus
    let createdBy: String
    let isAgentStream: Bool
    let market: SBMarketPool
    let startsAt: Int
    let endsAt: Int
    let resolved: Bool
    let txHash: String
}

struct SBMarketPool: Codable {
    let yesPoolWei: String
    let noPoolWei: String
    let yesOdds: Double
    let noOdds: Double
    let totalVolumeWei: String
    let bettorsCount: Int
}

// MARK: - Agents (GET /v1/agents)

struct SBAgent: Identifiable, Codable {
    var id: String { agentId }
    let agentId: String
    let name: String
    let inftId: String?
    let walletAddress: String
    let pnlWei: String
    let winRate: Double
    let totalBets: Int
    let followersCount: Double
    let totalVolumeWei: String
    let registeredAt: Int

    var pnlEth: Double { weiToEth(pnlWei) }
    var totalVolumeEth: Double { weiToEth(totalVolumeWei) }
    var shortAddress: String {
        guard walletAddress.count > 10 else { return walletAddress }
        return walletAddress.prefix(6) + "..." + walletAddress.suffix(4)
    }
}

struct PaginatedAgents: Codable {
    let agents: [SBAgent]
    let nextCursor: String?
    let total: Int
}

// MARK: - Agent detail (GET /v1/agents/:id)

struct SBAgentDetail: Codable {
    let agentId: String
    let name: String
    let description: String?
    let walletAddress: String
    let inftId: String?
    let inftMetadataUri: String?
    let ogStorageKey: String?
    let stats: SBAgentStats
    let followers: [SBFollower]
    let pnlHistory: [SBPnLHistory]
    let recentBets: [SBAgentBet]
    let registeredAt: Int
}

struct SBAgentStats: Codable {
    let pnlWei: String
    let winRate: Double
    let totalBets: Int
    let avgBetSizeWei: String
    let followersCount: Double
    let totalVolumeWei: String

    var pnlEth: Double { weiToEth(pnlWei) }
    var avgBetSizeEth: Double { weiToEth(avgBetSizeWei) }
    var totalVolumeEth: Double { weiToEth(totalVolumeWei) }
}

struct SBFollower: Codable {
    let userId: String
    let mode: SBFollowMode
    let copyFraction: Double?
    let maxBetWei: String?
}

struct SBPnLHistory: Codable {
    let period: String
    let pnlWei: String

    var pnlEth: Double { weiToEth(pnlWei) }
}

struct SBAgentBet: Identifiable, Codable {
    var id: String { betId }
    let betId: String
    let marketId: String
    let side: SBBetSide
    let amountWei: String
    let placedAt: Int
    let outcome: String?

    var amountEth: Double { weiToEth(amountWei) }
}

struct SBFollowResponse: Codable {
    let followerId: String
    let agentId: String
    let mode: SBFollowMode
    let copyFraction: Double?
    let maxBetWei: String?
    let registryTxHash: String
    let activeSince: Int
}

// MARK: - WebSocket event models

struct WSEvent: Codable {
    let type: String
}

struct WSOddsUpdate: Codable {
    let type: String
    let marketId: String
    let yesOdds: Double
    let noOdds: Double
    let yesPoolWei: String
    let noPoolWei: String
    let totalVolumeWei: String
    let secondsRemaining: Int
    let ts: Int
}

struct WSBetPlaced: Identifiable, Codable {
    var id: String { betId }
    let type: String
    let marketId: String
    let betId: String
    let userId: String
    let isAgent: Bool
    let side: SBBetSide
    let amountWei: String
    let txHash: String
    let ts: Int

    var amountEth: Double { weiToEth(amountWei) }
}

struct WSMarketResolved: Codable {
    let type: String
    let marketId: String
    let outcome: String
    let resolutionReason: String
    let trioExplanation: String?
    let resolvedAt: Int
    let txHash: String
    let winningPoolWei: String?
    let totalPotWei: String
}

struct WSAgentBet: Codable {
    let type: String
    let marketId: String
    let betId: String
    let agentId: String
    let agentName: String
    let side: SBBetSide
    let amountWei: String
    let ts: Int
}

// MARK: - Helpers

private func weiToEth(_ wei: String) -> Double {
    guard let value = Double(wei) else { return 0 }
    return value / 1e18
}
