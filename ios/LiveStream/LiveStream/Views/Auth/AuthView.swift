import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)

                    Text("LiveStream")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Go live on 0G")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        signIn()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Sign in")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isLoading)

                    Text("Powered by Dynamic · Stored on 0G")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    private func signIn() {
        isLoading = true
        // TODO: Replace with Dynamic SDK auth
        // DynamicSDK.shared.showAuth()
        // For now, simulate login after short delay
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            appState.simulateLogin()
            isLoading = false
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
}
