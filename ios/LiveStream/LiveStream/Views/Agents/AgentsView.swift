import SwiftUI

struct AgentsView: View {
    @State private var agents: [SBAgent] = []
    @State private var isLoading = false
    @State private var nextCursor: String?
    @State private var selectedAgent: SBAgent?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && agents.isEmpty {
                    ProgressView("Loading agents…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if agents.isEmpty {
                    ContentUnavailableView(
                        "No agents yet",
                        systemImage: "cpu",
                        description: Text("AI trading agents will appear here.")
                    )
                } else {
                    List {
                        ForEach(Array(agents.enumerated()), id: \.element.id) { index, agent in
                            AgentRow(rank: index + 1, agent: agent)
                                .onTapGesture { selectedAgent = agent }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .onAppear {
                                    if agent.id == agents.last?.id, let cursor = nextCursor {
                                        Task { await loadMore(cursor: cursor) }
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Agents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await loadAgents() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await loadAgents() }
            .sheet(item: $selectedAgent) { agent in
                AgentDetailView(agentId: agent.agentId)
            }
        }
        .task { await loadAgents() }
    }

    private func loadAgents() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await StreamBetClient.shared.getAgents(sortBy: "pnl")
            agents = result.agents
            nextCursor = result.nextCursor
        } catch {
            print("Failed to load agents: \(error)")
        }
    }

    private func loadMore(cursor: String) async {
        do {
            let result = try await StreamBetClient.shared.getAgents(sortBy: "pnl", cursor: cursor)
            agents.append(contentsOf: result.agents)
            nextCursor = result.nextCursor
        } catch {
            print("Failed to load more agents: \(error)")
        }
    }
}

// MARK: - Agent Row

struct AgentRow: View {
    let rank: Int
    let agent: SBAgent

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(rank <= 3 ? .yellow : .secondary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text(agent.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(agent.shortAddress)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let pnlPositive = agent.pnlEth >= 0
                Text(String(format: "%@%.4f ETH", pnlPositive ? "+" : "", agent.pnlEth))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(pnlPositive ? .green : .red)

                Text(String(format: "%.0f%% win", agent.winRate * 100))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AgentsView()
}
