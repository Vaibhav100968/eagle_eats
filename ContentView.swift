import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.authState {
            case .unknown:
                SplashView()
            case .onboarding:
                WelcomeView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .signedIn:
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: appState.authState)
        .task {
            if appState.authState == .unknown {
                try? await Task.sleep(nanoseconds: 800_000_000)
                if AppState.shared.authState == .unknown {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        AppState.shared.authState = .onboarding
                    }
                }
            }
        }
    }
}

// MARK: - Splash / Launch

private struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient.untHeroGradient.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .scaleEffect(scale)
                Text("Mean Eats")
                    .font(.displayMedium)
                    .foregroundStyle(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) { scale = 1 }
            withAnimation(.easeIn(duration: 0.4).delay(0.3)) { opacity = 1 }
        }
    }
}
