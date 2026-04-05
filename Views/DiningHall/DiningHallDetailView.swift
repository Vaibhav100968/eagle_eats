import SwiftUI

// MARK: - Dining Hall Detail View

struct DiningHallDetailView: View {
    let hall: DiningHall

    @EnvironmentObject private var diningService: DiningService
    @EnvironmentObject private var plateVM:       PlateViewModel
    @EnvironmentObject private var appState:      AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPeriod:   MealPeriod    = MealPeriod.current()
    @State private var searchText:       String        = ""
    @State private var showingNutrition: MenuItem?     = nil
    @State private var headerExpanded:   Bool          = true
    @State private var itemsVisible:     Bool          = false
    @State private var addedItem:        MenuItem?     = nil
    @State private var menuFilter:       MenuFilter    = MenuFilter()
    @State private var showFilters:      Bool          = false

    /// Ordered list of unique station names for the current period.
    private var stations: [String] { diningService.stations(for: hall, period: selectedPeriod) }

    /// All items for the period, filtered by search + MenuFilter, grouped by station.
    private var groupedItems: [(station: String, items: [MenuItem])] {
        var allItems = diningService.menuItems(for: hall, period: selectedPeriod)
        if !searchText.isEmpty {
            allItems = allItems.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        if menuFilter.isActive {
            allItems = allItems.filter { menuFilter.matches($0) }
        }
        var orderedStations: [String] = []
        var byStation: [String: [MenuItem]] = [:]
        for item in allItems {
            let s = item.station.isEmpty ? item.category.rawValue : item.station
            if !orderedStations.contains(s) { orderedStations.append(s) }
            byStation[s, default: []].append(item)
        }
        return orderedStations.map { (station: $0, items: byStation[$0] ?? []) }
    }

    private var allFilteredItems: [MenuItem] { groupedItems.flatMap(\.items) }

    private var activeFilterCount: Int {
        var count = 0
        if !menuFilter.dietaryTags.isEmpty { count += menuFilter.dietaryTags.count }
        if menuFilter.maxCalories != nil { count += 1 }
        if menuFilter.minProtein != nil { count += 1 }
        return count
    }

    private var periods: [MealPeriod] {
        [.breakfast, .lunch, .dinner].filter { period in
            !diningService.menuItems(for: hall, period: period).isEmpty
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.untGreenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: Hero Header
                    heroHeader

                    // MARK: Tomorrow Banner
                    if diningService.isShowingTomorrowMenu {
                        tomorrowBanner
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                    }

                    // MARK: Live Crowd
                    if hall.isOpen {
                        LiveCrowdStrip(hallId: hall.id)
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                    }

                    // MARK: Info Strip
                    infoStrip
                        .padding(.horizontal, 20)
                        .padding(.top, diningService.isShowingTomorrowMenu ? 10 : 16)
                        .padding(.bottom, 8)

                    // MARK: Directions
                    directionsBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // MARK: Loading State
                    if diningService.isLoading {
                        menuLoadingState
                    } else if let err = diningService.fetchError,
                              (menusByHallIsEmpty) {
                        // Failed to load AND we have no fallback sample data
                        menuErrorState(message: err)
                            .padding(.top, 40)
                    } else {
                        // MARK: Meal Period Picker
                        if !periods.isEmpty {
                            mealPeriodPicker
                                .padding(.bottom, 8)
                        }

                        // MARK: Search + Filter Bar
                        HStack(spacing: 10) {
                            searchBar
                            filterToggleButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, showFilters ? 0 : 12)

                        if showFilters {
                            menuFilterBar
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Active filter chips
                        if menuFilter.isActive && !showFilters {
                            activeFilterChips
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                        }

                        // MARK: Menu Items grouped by station
                        if allFilteredItems.isEmpty {
                            emptyState
                                .padding(.top, 60)
                        } else {
                            menuItemList
                        }
                    }

                    Spacer().frame(height: 120)
                }
            }

            // MARK: Plate FAB
            if plateVM.hasItems {
                plateFAB
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(hall.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                FavoriteButton(hallId: hall.id)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if diningService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color.untGreenPrimary)
                }
            }
        }
        .sheet(item: $showingNutrition) { item in
            NutritionDetailSheet(item: item)
        }
        .sheet(isPresented: $plateVM.showingPlateSheet) {
            PlateBuilderView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                itemsVisible = true
            }
            // Pre-populate filters from user dietary preferences
            if !appState.settings.dietaryFilters.isEmpty && menuFilter.dietaryTags.isEmpty {
                menuFilter.dietaryTags = Set(appState.settings.dietaryFilters)
            }
            Task { await diningService.fetchMenuForHallIfNeeded(hall) }
        }
        .onChange(of: selectedPeriod) { _, _ in
            withAnimation(.spring(response: 0.45)) { itemsVisible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { itemsVisible = true }
            }
        }
    }

    private var menusByHallIsEmpty: Bool {
        (diningService.menusByHall[hall.id] ?? []).isEmpty
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: hall.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)

            // Decorative elements
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 220)
                .offset(x: 160, y: -60)
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 140)
                .offset(x: 220, y: 20)

            LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: hall.iconName)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))

                VStack(alignment: .leading, spacing: 4) {
                    Text(hall.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(hall.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }

                HStack(spacing: 10) {
                    OpenClosedBadge(isOpen: hall.isOpen, period: hall.currentMealPeriod)
                    Text(hall.location)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Tomorrow Banner

    private var tomorrowBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.macroFiber)
            VStack(alignment: .leading, spacing: 2) {
                Text("All dining halls closed today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Showing tomorrow's menu")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.macroFiber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.macroFiber.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Info Strip

    private var infoStrip: some View {
        let dayLabel = diningService.isShowingTomorrowMenu ? "Tomorrow" : "Today"
        return HStack(spacing: 0) {
            InfoChip(icon: "clock.fill", label: dayLabel, value: todayHours, color: .untGreenPrimary)
            Divider().frame(height: 36).padding(.horizontal, 4)
            InfoChip(icon: "mappin.fill", label: "Location", value: hall.location, color: .macroCarbs)
            Divider().frame(height: 36).padding(.horizontal, 4)
            InfoChip(icon: hall.currentMealPeriod.icon, label: "Now", value: hall.currentMealPeriod.rawValue, color: hall.currentMealPeriod.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    // MARK: - Directions Bar

    private var directionsBar: some View {
        Button {
            HapticService.shared.light()
            MapService.openDirections(to: hall)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.macroCarbs.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "location.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.macroCarbs)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Get Directions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(hall.location)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.macroCarbs)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(DiningCardButtonStyle())
    }

    // MARK: - Menu Loading Skeleton

    private var menuLoadingState: some View {
        VStack(spacing: 14) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.surfaceBase)
                    .frame(height: 88)
                    .overlay(
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.borderSubtle.opacity(0.6))
                                .frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.borderSubtle.opacity(0.6))
                                    .frame(width: 160, height: 14)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.borderSubtle.opacity(0.4))
                                    .frame(width: 110, height: 10)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    )
                    .shimmering()
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Menu Error State

    private func menuErrorState(message: String) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.statusClosed.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "wifi.slash")
                    .font(.system(size: 32)).foregroundStyle(Color.statusClosed)
            }
            VStack(spacing: 6) {
                Text("Couldn't load menu")
                    .font(.headingMedium).foregroundStyle(Color.textPrimary)
                Text("Using sample data. Pull down or tap Retry to try again.")
                    .font(.bodySmall).foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await diningService.fetchAllMenus() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.untGreenPrimary).foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(SpringButtonStyle())
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Meal Period Picker

    private var mealPeriodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(periods, id: \.self) { period in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            selectedPeriod = period
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: period.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(period.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedPeriod == period ? period.color : Color.surfaceBase)
                        .foregroundStyle(selectedPeriod == period ? .white : Color.textSecondary)
                        .clipShape(Capsule())
                        .shadow(color: selectedPeriod == period ? period.color.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textTertiary)
            TextField("Search menu items...", text: $searchText)
                .font(.system(size: 15))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Menu Item List (grouped by station)

    private var menuItemList: some View {
        let showHeaders = groupedItems.count > 1
        return LazyVStack(spacing: 0, pinnedViews: showHeaders ? [.sectionHeaders] : []) {
            ForEach(groupedItems, id: \.station) { group in
                Section {
                    let allItems = allFilteredItems
                    ForEach(group.items) { item in
                        let index = allItems.firstIndex(where: { $0.id == item.id }) ?? 0
                        MenuItemRow(
                            item: item,
                            hall: hall,
                            plateVM: plateVM,
                            onNutritionTap: { showingNutrition = item }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .opacity(itemsVisible ? 1 : 0)
                        .offset(y: itemsVisible ? 0 : 20)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.8)
                                .delay(Double(min(index, 20)) * 0.035),
                            value: itemsVisible
                        )
                    }
                } header: {
                    if showHeaders {
                        stationHeader(group.station)
                    }
                }
            }
        }
    }

    private func stationHeader(_ name: String) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.untGreenPrimary)
            Rectangle()
                .fill(Color.untGreenPrimary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.untGreenBackground)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.untGreenMint.opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: searchText.isEmpty ? "moon.zzz.fill" : "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.untGreenMint)
            }
            VStack(spacing: 6) {
                Text(searchText.isEmpty ? "No menu items" : "No results")
                    .font(.headingMedium)
                    .foregroundStyle(Color.textPrimary)
                Text(searchText.isEmpty
                     ? "The \(selectedPeriod.rawValue.lowercased()) menu is not available yet for \(hall.name).\nTry a different meal period."
                     : "No items match \"\(searchText)\". Try a different search.")
                    .font(.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if searchText.isEmpty && !periods.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(periods, id: \.self) { period in
                            Button {
                                withAnimation(.spring(response: 0.4)) { selectedPeriod = period }
                            } label: {
                                Label(period.rawValue, systemImage: period.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(period.color.opacity(0.15))
                                    .foregroundStyle(period.color)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(SpringButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding()
    }

    // MARK: - Plate FAB

    private var plateFAB: some View {
        Button { plateVM.showingPlateSheet = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("My Plate")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("\(plateVM.itemCount) items • \(Int(plateVM.plate.totalCalories)) cal")
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(LinearGradient(colors: [.untGreenMedium, .untGreenDark], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.untGreenDark.opacity(0.4), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 20)
        }
        .buttonStyle(SpringButtonStyle())
    }

    // MARK: - Filter Toggle Button

    private var filterToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showFilters.toggle()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(menuFilter.isActive ? Color.untGreenPrimary : Color.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(Color.surfaceBase)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(menuFilter.isActive ? Color.untGreenPrimary.opacity(0.3) : Color.borderSubtle, lineWidth: 1)
                    )

                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.untGreenPrimary)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(SpringButtonStyle())
    }

    // MARK: - Menu Filter Bar

    private var menuFilterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Dietary tags
            VStack(alignment: .leading, spacing: 6) {
                Text("DIETARY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .letterSpacing(0.5)

                FlowLayout(spacing: 6) {
                    ForEach([
                        ("vegan", "Vegan", "leaf.fill"),
                        ("vegetarian", "Vegetarian", "leaf"),
                        ("gluten-free", "Gluten Free", "checkmark.seal.fill"),
                        ("high-protein", "High Protein", "bolt.fill"),
                        ("dairy-free", "Dairy Free", "drop.fill"),
                        ("halal", "Halal", "checkmark.circle.fill")
                    ], id: \.0) { id, label, icon in
                        let isOn = menuFilter.dietaryTags.contains(id)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isOn { menuFilter.dietaryTags.remove(id) }
                                else    { menuFilter.dietaryTags.insert(id) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .font(.system(size: 10, weight: .semibold))
                                Text(label)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isOn ? Color.untGreenPrimary : Color.surfaceRaised)
                            .foregroundStyle(isOn ? .white : Color.textSecondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                }
            }

            // Calorie & protein sliders
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max Calories")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        if let max = menuFilter.maxCalories {
                            Text("\(Int(max)) cal")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.macroCalories)
                        } else {
                            Text("Any")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach([200, 400, 600, 800], id: \.self) { cal in
                            let isSelected = menuFilter.maxCalories == Double(cal)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    menuFilter.maxCalories = isSelected ? nil : Double(cal)
                                }
                            } label: {
                                Text("\(cal)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(isSelected ? Color.macroCalories : Color.surfaceRaised)
                                    .foregroundStyle(isSelected ? .white : Color.textTertiary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(SpringButtonStyle())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Min Protein")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        if let min = menuFilter.minProtein {
                            Text("\(Int(min))g+")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.macroProtein)
                        } else {
                            Text("Any")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach([10, 20, 30, 40], id: \.self) { prot in
                            let isSelected = menuFilter.minProtein == Double(prot)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    menuFilter.minProtein = isSelected ? nil : Double(prot)
                                }
                            } label: {
                                Text("\(prot)g")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(isSelected ? Color.macroProtein : Color.surfaceRaised)
                                    .foregroundStyle(isSelected ? .white : Color.textTertiary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(SpringButtonStyle())
                        }
                    }
                }
            }

            // Clear all button
            if menuFilter.isActive {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        menuFilter = MenuFilter()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Clear All Filters")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.statusClosed)
                }
            }
        }
        .padding(14)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    // MARK: - Active Filter Chips

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(menuFilter.dietaryTags), id: \.self) { tagId in
                    let label = tagId.replacingOccurrences(of: "-", with: " ").capitalized
                    filterChip(label: label, color: .untGreenPrimary) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            _ = menuFilter.dietaryTags.remove(tagId)
                        }
                    }
                }
                if let max = menuFilter.maxCalories {
                    filterChip(label: "≤\(Int(max)) cal", color: .macroCalories) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { menuFilter.maxCalories = nil }
                    }
                }
                if let min = menuFilter.minProtein {
                    filterChip(label: "≥\(Int(min))g protein", color: .macroProtein) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { menuFilter.minProtein = nil }
                    }
                }
            }
        }
    }

    private func filterChip(label: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var todayHours: String {
        let cal = Calendar.current
        let isWeekend = [1, 7].contains(cal.component(.weekday, from: Date()))
        let h = isWeekend ? hall.weekendHours : hall.weekdayHours
        if h.openHour == 0 && h.closeHour == 0 { return "Closed" }
        return h.displayString
    }
}

// MARK: - Info Chip

private struct InfoChip: View {
    let icon:  String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Nutrition Detail Sheet

struct NutritionDetailSheet: View {
    let item: MenuItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.headingXL)
                            .foregroundStyle(Color.textPrimary)
                        Text(item.description)
                            .font(.bodyMedium)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, 24)

                    // Serving size
                    if let serving = item.nutrition.servingSize {
                        Text("Serving size: \(serving)")
                            .font(.labelMedium)
                            .foregroundStyle(Color.textTertiary)
                            .padding(.horizontal, 24)
                    }

                    // Main macros
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        NutritionFactRow(label: "Calories",       value: "\(Int(item.nutrition.calories))",        unit: "kcal", color: .macroCalories)
                        NutritionFactRow(label: "Protein",        value: "\(Int(item.nutrition.protein))",         unit: "g",    color: .macroProtein)
                        NutritionFactRow(label: "Carbohydrates",  value: "\(Int(item.nutrition.carbohydrates))",   unit: "g",    color: .macroCarbs)
                        NutritionFactRow(label: "Total Fat",      value: "\(Int(item.nutrition.fat))",             unit: "g",    color: .macroFat)
                        if let fiber = item.nutrition.fiber {
                            NutritionFactRow(label: "Fiber",      value: "\(Int(fiber))",                          unit: "g",    color: .macroFiber)
                        }
                        if let sodium = item.nutrition.sodium {
                            NutritionFactRow(label: "Sodium",     value: "\(Int(sodium))",                         unit: "mg",   color: Color.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Dietary tags
                    if !item.dietaryTags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Dietary Info")
                                .font(.headingSmall)
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, 24)
                            FlowLayout(spacing: 8) {
                                ForEach(item.dietaryTags) { tag in
                                    HStack(spacing: 5) {
                                        Image(systemName: tag.icon)
                                            .font(.system(size: 11))
                                        Text(tag.label)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(Color(hex: tag.color))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: tag.color).opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 24)
            }
            .background(Color.untGreenBackground.ignoresSafeArea())
            .navigationTitle("Nutrition Facts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.untGreenPrimary)
                }
            }
        }
    }
}

// MARK: - Nutrition Fact Row

private struct NutritionFactRow: View {
    let label: String
    let value: String
    let unit:  String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.labelSmall)
                    .foregroundStyle(Color.textSecondary)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.numberMedium)
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.labelSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Simple Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
