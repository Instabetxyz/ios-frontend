import SwiftUI

struct AgentDetailView: View {
    let agentId: String

    @State private var detail: SBAgentDetail?
    @State private var isLoading = true
    @State private var showFollowSheet = false
    @State private var followMode: SBFollowMode = .copy
    @State private var copyFraction: Double = 0.5
    @State private var isFollowing = false
    @State private var followError: String?
    @State private var followSuccess = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading agent…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection(detail)
                            statsSection(detail.stats)
                            pnlHistorySection(detail.pnlHistory)
                            recentBetsSection(detail.recentBets)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("Agent not found", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle(detail?.name ?? "Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Follow") { showFollowSheet = true }
                        .disabled(detail == nil)
                }
            }
            .sheet(isPresented: $showFollowSheet) {
                followSheet
            }
            .alert("Following agent!", isPresented: $followSuccess) {
                Button("OK", role: .cancel) {}
            }
            .alert("Follow failed", isPresented: Binding(get: { followError != nil }, set: { if !$0 { followError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(followError ?? "")
            }
        }
        .task { await loadDetail() }
    }

    // MARK: - Sections

    private func headerSection(_ detail: SBAgentDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.purple.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: "cpu")
                        .font(.title2)
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(shortAddress(detail.walletAddress))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
            }

            if let description = detail.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statsSection(_ stats: SBAgentStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "PnL", value: String(format: "%+.4f ETH", stats.pnlEth), positive: stats.pnlEth >= 0)
                StatCard(title: "Win Rate", value: String(format: "%.0f%%", stats.winRate * 100), positive: stats.winRate >= 0.5)
                StatCard(title: "Total Bets", value: "\(stats.totalBets)", positive: nil)
                StatCard(title: "Followers", value: "\(Int(stats.followersCount))", positive: nil)
                StatCard(title: "Avg Bet", value: String(format: "%.4f ETH", stats.avgBetSizeEth), positive: nil)
                StatCard(title: "Volume", value: String(format: "%.2f ETH", stats.totalVolumeEth), positive: nil)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func pnlHistorySection(_ history: [SBPnLHistory]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PnL History")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(history, id: \.period) { entry in
                    VStack(spacing: 4) {
                        Text(entry.period)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%+.4f", entry.pnlEth))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(entry.pnlEth >= 0 ? .green : .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recentBetsSection(_ bets: [SBAgentBet]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Bets")
                .font(.headline)

            if bets.isEmpty {
                Text("No bets yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bets) { bet in
                    HStack {
                        Image(systemName: outcomeIcon(bet.outcome))
                            .font(.caption)
                            .foregroundStyle(outcomeColor(bet.outcome))
                        Text(bet.side.rawValue.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(bet.side == .yes ? .green : .red)
                        Spacer()
                        Text(String(format: "%.4f ETH", bet.amountEth))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        outcomeTag(bet.outcome)
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var followSheet: some View {
        NavigationStack {
            Form {
                Section("Follow Mode") {
                    Picker("Mode", selection: $followMode) {
                        Text("Copy (mirror bets)").tag(SBFollowMode.copy)
                        Text("Short (opposite bets)").tag(SBFollowMode.short)
                        Text("None (stop following)").tag(SBFollowMode.none)
                    }
                    .pickerStyle(.inline)
                }

                if followMode != .none {
                    Section("Copy Fraction: \(Int(copyFraction * 100))%") {
                        Slider(value: $copyFraction, in: 0.01...1.0, step: 0.01)
                    }
                }
            }
            .navigationTitle("Follow Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showFollowSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Follow") {
                        Task { await followAgent() }
                    }
                    .disabled(isFollowing)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        detail = try? await StreamBetClient.shared.getAgentDetail(id: agentId)
    }

    private func followAgent() async {
        isFollowing = true
        defer { isFollowing = false }
        do {
            _ = try await StreamBetClient.shared.followAgent(
                agentId: agentId,
                mode: followMode,
                copyFraction: followMode != .none ? copyFraction : nil,
                maxBetWei: nil
            )
            showFollowSheet = false
            followSuccess = true
        } catch {
            showFollowSheet = false
            followError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func shortAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return address.prefix(6) + "..." + address.suffix(4)
    }

    private func outcomeIcon(_ outcome: String?) -> String {
        switch outcome {
        case "win": return "checkmark.circle.fill"
        case "loss": return "xmark.circle.fill"
        default: return "clock.circle"
        }
    }

    private func outcomeColor(_ outcome: String?) -> Color {
        switch outcome {
        case "win": return .green
        case "loss": return .red
        default: return .secondary
        }
    }

    private func outcomeTag(_ outcome: String?) -> some View {
        let label = outcome ?? "pending"
        return Text(label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(outcomeColor(outcome).opacity(0.2))
            .foregroundStyle(outcomeColor(outcome))
            .clipShape(Capsule())
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let positive: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(
                    positive == nil ? .primary :
                    positive! ? .green : .red
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
