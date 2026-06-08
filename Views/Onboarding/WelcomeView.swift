import SwiftUI
import WebKit

// MARK: - Auth Gate
// Every user lands here before entering the app.
// They MUST authenticate via UNT portal (SSO) — no guest mode.

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showPortal:       Bool = false
    @State private var webLoading:       Bool = false
    @State private var webExtracting:    Bool = false
    @State private var showWelcomeEmail: Bool = false
    @State private var extractedName:    String? = nil

    // Animation state
    @State private var heroVisible:    Bool = false
    @State private var formVisible:    Bool = false
    @State private var buttonsVisible: Bool = false

    private let portalURL = URL(string: "https://mealplans.unt.edu")!

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "002B16"), Color(hex: "004D2C"), Color(hex: "00853E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            blobLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: Hero branding
                    heroSection
                        .padding(.top, 60)
                        .padding(.bottom, 32)

                    // MARK: Info card
                    infoCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    // MARK: Sign In button
                    signInButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: Security notice
                    securityNotice
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)

                    // MARK: Footer
                    VStack(spacing: 6) {
                        Text("Built for UNT Students")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Your credentials go directly to UNT's secure portal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .multilineTextAlignment(.center)
                    .opacity(buttonsVisible ? 1 : 0)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showPortal) {
            MealPlanWebSheet(
                url:           portalURL,
                webLoading:    $webLoading,
                webExtracting: $webExtracting,
                onDataExtracted: handleDataExtracted,
                onAuthDetected:  handleAuthDetected,
                onSessionExpired: handleSessionExpired
            )
        }
        .alert("Welcome to Mean Eats!", isPresented: $showWelcomeEmail) {
            Button("Let's Go!") {
                appState.auth.markWelcomeEmailSent()
                appState.didSignIn()
            }
        } message: {
            Text("You're signed in with your UNT account. Enjoy tracking your dining!")
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) { heroVisible = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35)) { formVisible = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.55)) { buttonsVisible = true }
        }
    }

    // MARK: - Portal Auth Callbacks

    private func handleDataExtracted(_ info: MealPlanInfo) {
        withAnimation(.easeOut(duration: 0.22)) { showPortal = false }

        MealPlanService.shared.cache(info)
        MealPlanService.shared.markSessionValid(true)

        let name = info.accountHolder
        extractedName = name
        appState.auth.authenticateWithPortal(displayName: name)

        if appState.auth.isFirstLogin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showWelcomeEmail = true
            }
        } else {
            appState.didSignIn()
        }
    }

    private func handleAuthDetected() {
        withAnimation(.easeOut(duration: 0.22)) {
            webExtracting = false
            showPortal = false
        }

        MealPlanService.shared.markSessionValid(true)
        appState.auth.authenticateWithPortal(displayName: nil)

        if appState.auth.isFirstLogin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showWelcomeEmail = true
            }
        } else {
            appState.didSignIn()
        }
    }

    private func handleSessionExpired() {
        withAnimation(.easeOut(duration: 0.22)) { showPortal = false }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("Mean Eats")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .letterSpacing(-0.5)

                Text("UNT Dining, Beautifully Simplified")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FeatureChip(icon: "map.fill", text: "5 Halls", color: "27AE60")
                    FeatureChip(icon: "chart.pie.fill", text: "Macros", color: "3B82F6")
                    FeatureChip(icon: "clock.fill", text: "Live Hours", color: "F59E0B")
                    FeatureChip(icon: "leaf.fill", text: "Dietary", color: "5ED68A")
                    FeatureChip(icon: "creditcard.fill", text: "Meal Plan", color: "8B5CF6")
                }
                .padding(.horizontal, 28)
            }
            .padding(.top, 8)
        }
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : 20)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Text("Sign in with your UNT account")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Use your EUID and password to securely log in through UNT's official portal.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 12) {
                InfoFeatureRow(icon: "fork.knife.circle.fill", title: "Dining Swipes & Flex",
                               desc: "See your remaining meal plan balance", color: .untGreenPrimary)
                InfoFeatureRow(icon: "chart.pie.fill", title: "Nutrition Tracking",
                               desc: "Build plates and track macros", color: .macroCarbs)
                InfoFeatureRow(icon: "arrow.clockwise.circle.fill", title: "Auto-Refresh",
                               desc: "Balance updates without re-entering credentials", color: .macroFat)
            }
        }
        .padding(22)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 10)
        .opacity(formVisible ? 1 : 0)
        .offset(y: formVisible ? 0 : 30)
    }

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button { showPortal = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign In with UNT")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Opens secure UNT portal")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: [.untGreenMedium, .untGreenDark],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.untGreenDark.opacity(0.5), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(SpringButtonStyle())
        .opacity(buttonsVisible ? 1 : 0)
        .offset(y: buttonsVisible ? 0 : 16)
    }

    // MARK: - Security Notice

    private var securityNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))
            Text("Mean Eats never stores your UNT password. You sign in directly on UNT's secure portal.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .opacity(buttonsVisible ? 1 : 0)
        .animation(.easeIn(duration: 0.3).delay(0.6), value: buttonsVisible)
    }

    // MARK: - Blob Layer

    @State private var blob1Offset: CGSize = .zero
    @State private var blob2Offset: CGSize = .zero

    private var blobLayer: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color(hex: "27AE60").opacity(0.2))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -geo.size.width * 0.3 + blob1Offset.width,
                            y: -geo.size.height * 0.15 + blob1Offset.height)

                Circle()
                    .fill(Color(hex: "5ED68A").opacity(0.15))
                    .frame(width: 220, height: 220)
                    .blur(radius: 50)
                    .offset(x: geo.size.width * 0.25 + blob2Offset.width,
                            y: geo.size.height * 0.2 + blob2Offset.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                blob1Offset = CGSize(width: 30, height: -35)
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                blob2Offset = CGSize(width: -25, height: 30)
            }
        }
    }
}

// MARK: - Info Feature Row

private struct InfoFeatureRow: View {
    let icon: String; let title: String; let desc: String; let color: Color
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.textPrimary)
                Text(desc).font(.system(size: 12)).foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Feature Chip

private struct FeatureChip: View {
    let icon: String
    let text: String
    let color: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: color))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Spring Button Style

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
