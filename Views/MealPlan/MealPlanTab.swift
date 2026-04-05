import SwiftUI
import WebKit
import MapKit

// MARK: - Meal Plan Tab (Swipes & Flex)
//
// State machine:
//   .notAuthenticated  → initial load → silentRefresh
//   .loading           → spinner
//   .authenticated(info) → balance cards
//   .stale(info)       → cards + stale banner + retry
//   .sessionExpired    → sign-in prompt
//   .error(msg)        → error + retry / sign out

struct MealPlanTab: View {
    @StateObject private var mealPlanService = MealPlanService.shared
    @StateObject private var budgetEngine    = BudgetEngine.shared

    @State private var showWebView:    Bool = false
    @State private var webLoading:     Bool = false
    @State private var webExtracting:  Bool = false
    @State private var isRefreshing:   Bool = false
    @State private var bannerVisible:  Bool = false
    @State private var cardsVisible:   Bool = false
    @State private var hasAppeared:    Bool = false

    private let portalURL = URL(string: "https://mealplans.unt.edu")!

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.untSubtleGradient.ignoresSafeArea()

                switch mealPlanService.authState {
                case .notAuthenticated:
                    initialLoadingState

                case .loading:
                    loadingState

                case .authenticated(let info):
                    balanceView(info: info, isStale: false)

                case .stale(let info):
                    balanceView(info: info, isStale: true)

                case .sessionExpired:
                    sessionExpiredState

                case .error(let msg):
                    errorState(message: msg)
                }
            }
            .navigationTitle("Swipes & Flex")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
        }
        .sheet(isPresented: $showWebView) {
            MealPlanWebSheet(
                url:           portalURL,
                webLoading:    $webLoading,
                webExtracting: $webExtracting,
                onDataExtracted: { info in
                    withAnimation(.easeOut(duration: 0.22)) { showWebView = false }
                    mealPlanService.cache(info)
                    mealPlanService.markSessionValid(true)
                    AuthService.shared.authenticateWithPortal(displayName: info.accountHolder)
                    HapticService.shared.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            cardsVisible = true
                        }
                    }
                },
                onAuthDetected: {
                    withAnimation(.easeOut(duration: 0.22)) {
                        webExtracting = false
                        showWebView = false
                    }
                    mealPlanService.markSessionValid(true)
                    AuthService.shared.authenticateWithPortal(displayName: nil)
                    // Trigger a silent refresh now that we have a valid session
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await silentRefresh(force: true)
                    }
                },
                onSessionExpired: {
                    withAnimation(.easeOut(duration: 0.22)) { showWebView = false }
                    mealPlanService.authState = .sessionExpired
                    mealPlanService.markSessionValid(false)
                }
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.1)) {
                bannerVisible = true
            }
            guard !hasAppeared else { return }
            hasAppeared = true

            switch mealPlanService.authState {
            case .authenticated(let info):
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                    cardsVisible = true
                }
                if let flex = info.flexBalance {
                    budgetEngine.recordBalanceUpdate(newBalance: flex)
                }
            case .stale(let info):
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                    cardsVisible = true
                }
                if let flex = info.flexBalance {
                    budgetEngine.recomputeWith(balance: flex)
                }
                if KeychainService.shared.hasPortalSession {
                    Task { await silentRefresh(force: false) }
                }
            case .notAuthenticated:
                if KeychainService.shared.hasPortalSession {
                    Task { await silentRefresh(force: false) }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        mealPlanService.authState = .sessionExpired
                    }
                }
            default:
                break
            }
        }
        .onChange(of: mealPlanService.authState) { _, new in
            if case .authenticated(let info) = new {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    cardsVisible = true
                }
                if let flex = info.flexBalance {
                    budgetEngine.recordBalanceUpdate(newBalance: flex)
                }
            } else if case .stale(let info) = new {
                cardsVisible = true
                if let flex = info.flexBalance {
                    budgetEngine.recomputeWith(balance: flex)
                }
            } else {
                cardsVisible = false
            }
        }
    }

    // MARK: - Refresh Button

    @ViewBuilder
    private var refreshButton: some View {
        switch mealPlanService.authState {
        case .authenticated, .stale, .error:
            Button {
                Task { await silentRefresh(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.untGreenPrimary)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(
                        isRefreshing
                        ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                        : .default,
                        value: isRefreshing
                    )
            }
            .disabled(isRefreshing)
        default:
            EmptyView()
        }
    }

    // MARK: - Initial Loading State

    private var initialLoadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(Color.untGreenPrimary)
            Text("Loading your meal plan...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .onAppear {
            Task { await silentRefresh(force: false) }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(Color.untGreenPrimary)
            Text("Checking your meal plan...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Balance View

    @ViewBuilder
    private func balanceView(info: MealPlanInfo, isStale: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                if isStale {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.macroFat)
                        Text("Showing last saved data")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Button {
                            Task { await silentRefresh(force: true) }
                        } label: {
                            HStack(spacing: 4) {
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(Color.untGreenPrimary)
                                }
                                Text(isRefreshing ? "Refreshing..." : "Refresh")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.untGreenPrimary)
                            }
                        }
                        .disabled(isRefreshing)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.macroFat.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let holder = info.accountHolder {
                    HStack {
                        Text("Hi, \(holder.components(separatedBy: " ").first ?? holder)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 22).padding(.top, 8)
                }
                if let plan = info.mealPlanName {
                    HStack {
                        Text(plan).font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, info.accountHolder == nil ? 8 : -8)
                }

                // Dining Swipes
                if let swipes = info.diningSwipes {
                    BalanceCard(
                        icon:           "fork.knife.circle.fill",
                        title:          "Dining Swipes",
                        value:          "\(swipes)",
                        subtitle:       swipes == 9999 ? "meal swipes" : swipes == 1 ? "swipe remaining" : "swipes remaining",
                        gradientColors: [Color(hex: "00853E"), Color(hex: "005227")],
                        isStale:        isStale
                    )
                    .padding(.horizontal, 20)
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 24)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.05), value: cardsVisible)
                } else {
                    unavailableCard(title: "Dining Swipes", icon: "fork.knife.circle.fill",
                                    color: Color(hex: "00853E"))
                }

                // Flex Balance
                if let flex = info.flexBalance {
                    BalanceCard(
                        icon:           "dollarsign.circle.fill",
                        title:          "Flex Balance",
                        value:          String(format: "$%.2f", flex),
                        subtitle:       "Dining dollars",
                        gradientColors: [Color(hex: "1A5276"), Color(hex: "003D1F")],
                        isStale:        isStale
                    )
                    .padding(.horizontal, 20)
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 24)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.12), value: cardsVisible)
                } else {
                    unavailableCard(title: "Flex Balance", icon: "dollarsign.circle.fill",
                                    color: Color(hex: "1A5276"))
                }

                // Budget Intelligence
                if info.flexBalance != nil {
                    SpendingInsightsCard(snapshot: budgetEngine.snapshot, suggestions: budgetEngine.suggestions)
                        .padding(.horizontal, 20)
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 24)
                        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.18), value: cardsVisible)

                    WeeklyBudgetBar(
                        used: budgetEngine.weeklyBudgetUsed,
                        spent: budgetEngine.weeklySpendSoFar,
                        budget: budgetEngine.snapshot.weeklyBudget
                    )
                    .padding(.horizontal, 20)
                    .opacity(cardsVisible ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.22), value: cardsVisible)
                }

                AddFundsButton()
                    .padding(.horizontal, 20)
                    .opacity(cardsVisible ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.26), value: cardsVisible)

                lastUpdatedRow(info: info, isStale: isStale)
                    .padding(.horizontal, 22)
                    .opacity(cardsVisible ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.30), value: cardsVisible)

                // Where to Spend
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "8B5CF6"))
                        Text("Where to Spend")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        NavigationLink {
                            RetailLocationsView()
                        } label: {
                            Text("See All")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.untGreenPrimary)
                        }
                    }
                    .padding(.horizontal, 22)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(RetailLocation.allLocations.prefix(8)) { loc in
                                MealPlanRetailChip(location: loc)
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                }
                .opacity(cardsVisible ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.34), value: cardsVisible)
                .padding(.top, 4)

                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.4)) {
                        cardsVisible = false
                        mealPlanService.signOut()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 14))
                        Text("Disconnect UNT Portal").font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color.statusClosed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.statusClosed.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.statusClosed.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 20)
                }
                .buttonStyle(SpringButtonStyle())
                .opacity(cardsVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.38), value: cardsVisible)

                Spacer().frame(height: 90)
            }
            .padding(.vertical, 16)
        }
        .refreshable { await silentRefresh(force: true) }
    }

    private func unavailableCard(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color.opacity(0.7))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Balance not available")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Button { Task { await silentRefresh(force: true) } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .padding(16)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(color.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Session Expired State

    private var sessionExpiredState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.macroFat.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "lock.rotation").font(.system(size: 42, weight: .light))
                    .foregroundStyle(Color.macroFat)
            }
            VStack(spacing: 8) {
                Text("Session Expired")
                    .font(.headingLarge).foregroundStyle(Color.textPrimary)
                Text("Your UNT portal session has expired.\nSign in again to view your balance.")
                    .font(.bodyMedium).foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button { showWebView = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Sign In to UNT Portal")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [.untGreenMedium, .untGreenDark],
                                           startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 30)
                .shadow(color: Color.untGreenDark.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(SpringButtonStyle())

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                Text("Your credentials go directly to UNT's secure portal")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundStyle(Color.macroFat)
            Text("Balance Unavailable").font(.headingMedium)
            Text(message)
                .font(.bodySmall).foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 36)
            HStack(spacing: 12) {
                Button {
                    Task { await silentRefresh(force: true) }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Color.untGreenPrimary).foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(SpringButtonStyle())

                Button { showWebView = true } label: {
                    Label("Sign In", systemImage: "globe")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Color.untGreenPrimary.opacity(0.12))
                        .foregroundStyle(Color.untGreenPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(SpringButtonStyle())
            }
        }
    }

    // MARK: - Last Updated Row

    private func lastUpdatedRow(info: MealPlanInfo, isStale: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isStale ? "clock.badge.exclamationmark" : "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(isStale ? Color.macroFat : Color.untGreenPrimary)
            Text(isStale
                 ? "Cached \(info.lastUpdatedDisplay)"
                 : "Updated \(info.lastUpdatedDisplay)")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.textSecondary)
            Spacer()
        }
    }

    // MARK: - Silent Refresh
    //
    // force=true: used by Retry/Refresh — always transitions to loading
    // force=false: used on appear — only transitions if no existing data

    @MainActor
    private func silentRefresh(force: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true

        let hasExistingData: Bool = {
            switch mealPlanService.authState {
            case .authenticated(let i), .stale(let i): return i.hasAnyData
            default: return false
            }
        }()

        if force || !hasExistingData {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if !hasExistingData {
                    mealPlanService.authState = .loading
                }
            }
        }

        #if DEBUG
        print("[MealPlanTab] silentRefresh(force: \(force)) hasData: \(hasExistingData)")
        #endif

        let fetcher = SilentMealPlanFetcher()
        await withCheckedContinuation { continuation in
            fetcher.fetch { result in
                Task { @MainActor in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        switch result {
                        case .success(let info):
                            #if DEBUG
                            print("[MealPlanTab] Refresh success: swipes=\(info.diningSwipes ?? -1) flex=\(info.flexBalance ?? -1)")
                            #endif
                            self.mealPlanService.cache(info)
                            self.mealPlanService.markSessionValid(true)
                            HapticService.shared.success()

                        case .sessionExpired:
                            #if DEBUG
                            print("[MealPlanTab] Refresh → session expired")
                            #endif
                            self.mealPlanService.markSessionValid(false)
                            if hasExistingData && !force {
                                self.mealPlanService.markStale()
                            } else {
                                self.mealPlanService.authState = .sessionExpired
                            }

                        case .parseFailed:
                            #if DEBUG
                            print("[MealPlanTab] Refresh → parse failed")
                            #endif
                            if hasExistingData {
                                self.mealPlanService.markStale()
                            } else {
                                self.mealPlanService.authState = .error(
                                    "Could not read your balance from the portal. " +
                                    "Try signing in manually."
                                )
                            }
                        }
                    }
                    self.isRefreshing = false
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Balance Card

private struct BalanceCard: View {
    let icon:           String
    let title:          String
    let value:          String
    let subtitle:       String
    let gradientColors: [Color]
    let isStale:        Bool

    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.06)).frame(width: 180).offset(x: 140, y: -40)
            if isStale { Color.black.opacity(0.08) }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                        Text(title)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    }
                    Text(appeared ? value : "--")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: value)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                if isStale {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 24)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(22)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: gradientColors[0].opacity(0.35), radius: 18, x: 0, y: 8)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) { appeared = true }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String; let title: String; let desc: String; let color: Color
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12)).frame(width: 46, height: 46)
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.textPrimary)
                Text(desc).font(.system(size: 13)).foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Meal Plan Web Sheet

struct MealPlanWebSheet: View {
    let url:              URL
    @Binding var webLoading:    Bool
    @Binding var webExtracting: Bool
    let onDataExtracted:  (MealPlanInfo) -> Void
    let onAuthDetected:   () -> Void
    let onSessionExpired: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MealPlanWebView(
                    url:             url,
                    onDataExtracted: onDataExtracted,
                    onAuthDetected:  onAuthDetected,
                    onLoading:       { loading in webLoading = loading },
                    onSessionExpired: onSessionExpired
                )
                .ignoresSafeArea(edges: .bottom)

                if webLoading {
                    VStack { LinearProgressBar().frame(height: 3); Spacer() }
                }

                if webExtracting {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView().scaleEffect(1.4).tint(.white)
                            Text("Reading your balance...")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        }
                        .padding(32).background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("UNT Meal Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.system(size: 11))
                            .foregroundStyle(Color.untGreenPrimary)
                        Text("Secure").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Linear Progress Bar

private struct LinearProgressBar: View {
    @State private var progress: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.untGreenMint.opacity(0.3))
                Rectangle().fill(Color.untGreenPrimary).frame(width: geo.size.width * progress)
                    .animation(.linear(duration: 2.0), value: progress)
            }
        }
        .onAppear { progress = 0.85 }
    }
}

// MARK: - Meal Plan Retail Chip

private struct MealPlanRetailChip: View {
    let location: RetailLocation

    var body: some View {
        Button {
            HapticService.shared.light()
            let placemark = MKPlacemark(coordinate: location.coordinate)
            let item = MKMapItem(placemark: placemark)
            item.name = location.name
            item.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
            ])
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: location.category.tint).opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: location.category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: location.category.tint))
                }
                VStack(spacing: 2) {
                    Text(location.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text(location.building)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 80)
            .padding(.vertical, 10)
            .background(Color.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
