import SwiftUI
import Combine

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject private var appState:      AppState
    @EnvironmentObject private var diningService: DiningService
    @EnvironmentObject private var plateVM:       PlateViewModel

    @StateObject private var recEngine = RecommendationEngine.shared
    @StateObject private var locationService = LocationService.shared

    @State private var selectedHall:      DiningHall?     = nil
    @State private var headerVisible:     Bool            = false
    @State private var cardsVisible:      Bool            = false
    @State private var currentTime:       Date            = Date()
    @State private var showMap:           Bool            = false

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var currentPeriod: MealPeriod { MealPeriod.current(for: currentTime) }
    private var openHalls:  [DiningHall]  { diningService.halls.filter { $0.isOpen } }
    private var favoriteHalls: [DiningHall] {
        diningService.halls.filter { appState.isFavorite($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient.untSubtleGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: Header
                        homeHeader
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : -20)

                        // MARK: Meal Period Banner
                        mealPeriodBanner
                            .padding(.horizontal, 22)
                            .padding(.bottom, 28)
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : -10)

                        // MARK: Tomorrow Banner (all halls closed)
                        if diningService.isShowingTomorrowMenu {
                            tomorrowBanner
                                .padding(.horizontal, 22)
                                .padding(.bottom, 20)
                                .opacity(headerVisible ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: headerVisible)
                        }

                        // MARK: Best Option Recommendation
                        if let topRec = recEngine.hallRecommendations.first, topRec.score > 20 {
                            BestOptionCard(
                                recommendation: topRec,
                                onSelectHall: { selectedHall = $0 }
                            )
                            .padding(.bottom, 28)
                        }

                        // MARK: Open Now Strip
                        if !openHalls.isEmpty {
                            openNowSection
                                .padding(.bottom, 30)
                        }

                        // MARK: Favorites Row
                        if !favoriteHalls.isEmpty {
                            favoritesSection
                                .padding(.bottom, 30)
                        }

                        // MARK: All Halls
                        allHallsSection
                            .padding(.bottom, 30)

                        // MARK: Dining Dollars Locations
                        diningDollarsSection

                        Spacer().frame(height: 90)
                    }
                }

                // Plate FAB
                if plateVM.hasItems {
                    plateFAB
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .scale(scale: 0.8)).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showMap = true } label: {
                        Image(systemName: "map.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.untGreenPrimary)
                    }
                }
            }
            .navigationDestination(item: $selectedHall) { hall in
                DiningHallDetailView(hall: hall)
            }
            .sheet(isPresented: $showMap) {
                CampusMapView()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.05)) { headerVisible = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.25)) { cardsVisible  = true }
            Task {
                await diningService.fetchAllMenus()
                recEngine.recommend(
                    settings: appState.settings,
                    plate: plateVM.plate,
                    favoriteIds: appState.favoriteHallIds
                )
            }
            if locationService.authorizationStatus == .notDetermined {
                locationService.requestPermission()
            } else {
                locationService.requestLocation()
            }
        }
        .onChange(of: locationService.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationService.requestLocation()
            }
        }
        .onReceive(timer) { currentTime = $0 }
    }

    // MARK: - Header

    private var homeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.untGreenPrimary)
                    .textCase(.uppercase)
                    .letterSpacing(0.8)

                Text(formattedDate)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer()

            // Live clock
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedTime)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: formattedTime)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.statusOpen)
                        .frame(width: 6, height: 6)
                        .opacity(Double(currentTime.timeIntervalSinceReferenceDate).truncatingRemainder(dividingBy: 2) < 1 ? 1 : 0.3)
                    Text("Live")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Meal Period Banner

    private var mealPeriodBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(currentPeriod.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: currentPeriod.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(currentPeriod.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(currentPeriod.greeting)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .contentTransition(.interpolate)
                    .animation(.spring(response: 0.5), value: currentPeriod)

                Text("\(openHalls.count) dining \(openHalls.count == 1 ? "hall" : "halls") open right now")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    // MARK: - Open Now Section

    private var openNowSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Open Now", icon: "circle.fill", iconColor: .statusOpen)
                .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(openHalls.enumerated()), id: \.element.id) { index, hall in
                        OpenHallChip(hall: hall, onSelect: { selectedHall = hall })
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(x: cardsVisible ? 0 : 40)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.78)
                                    .delay(Double(index) * 0.06),
                                value: cardsVisible
                            )
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Favorites", icon: "star.fill", iconColor: .macroFat)
                .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(favoriteHalls) { hall in
                        DiningHallCard(hall: hall, isCompact: true, onSelect: { selectedHall = hall })
                            .frame(width: 200)
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    // MARK: - All Halls Section

    private var allHallsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All Dining Halls", icon: "building.2.fill", iconColor: .untGreenPrimary)
                .padding(.horizontal, 22)

            VStack(spacing: 16) {
                ForEach(Array(diningService.halls.enumerated()), id: \.element.id) { index, hall in
                    DiningHallCard(hall: hall, isCompact: false, onSelect: { selectedHall = hall })
                        .padding(.horizontal, 22)
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 30)
                        .animation(
                            .spring(response: 0.55, dampingFraction: 0.78)
                                .delay(Double(index) * 0.08 + 0.1),
                            value: cardsVisible
                        )
                }
            }
        }
    }

    // MARK: - Dining Dollars Section

    private var diningDollarsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Dining Dollars", icon: "creditcard.fill", iconColor: Color(hex: "8B5CF6"))
                    .padding(.horizontal, 22)
                Spacer()
                NavigationLink {
                    RetailLocationsView()
                } label: {
                    Text("See All")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.untGreenPrimary)
                        .padding(.trailing, 22)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RetailLocation.allLocations.prefix(6)) { loc in
                        RetailChip(location: loc)
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    // MARK: - Plate FAB

    private var plateFAB: some View {
        Button {
            plateVM.showingPlateSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Plate")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("\(plateVM.itemCount) items • \(Int(plateVM.plate.totalCalories)) cal")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.untGreenMedium, .untGreenDark], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.untGreenDark.opacity(0.4), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 22)
        }
        .buttonStyle(SpringButtonStyle())
        .sheet(isPresented: $plateVM.showingPlateSheet) {
            PlateBuilderView()
        }
    }

    // MARK: - Computed Props

    private var greetingText: String {
        switch currentPeriod {
        case .breakfast: return "Good Morning"
        case .lunch:     return "Good Afternoon"
        case .dinner:    return "Good Evening"
        default:         return "Eagle Eats"
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: currentTime)
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: currentTime)
    }

    // MARK: - Tomorrow Banner

    private var tomorrowBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.macroFiber)
            VStack(alignment: .leading, spacing: 2) {
                Text("All dining halls are closed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("Showing tomorrow's menus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.macroFiber.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.macroFiber.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title:     String
    let icon:      String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
        }
    }
}

// MARK: - Open Hall Chip

private struct OpenHallChip: View {
    let hall:     DiningHall
    var onSelect: (() -> Void)? = nil
    @StateObject private var crowdFlow = CrowdFlowService.shared

    private var snap: CrowdSnapshot { crowdFlow.snapshot(for: hall.id) }

    var body: some View {
        Button(action: { HapticService.shared.light(); onSelect?() }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: hall.gradientStart).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: hall.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: hall.gradientStart))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(hall.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    HStack(spacing: 6) {
                        Text(hall.currentMealPeriod.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(hall.currentMealPeriod.color)
                        if snap.score > 0 {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: snap.level.tint))
                                    .frame(width: 5, height: 5)
                                Text(snap.level.rawValue)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(hex: snap.level.tint))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(hex: hall.gradientStart).opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(DiningCardButtonStyle())
    }
}

// MARK: - Retail Chip

private struct RetailChip: View {
    let location: RetailLocation

    var body: some View {
        Button {
            HapticService.shared.light()
            let placemark = MKPlacemark(
                coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            )
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = location.name
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
            ])
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: location.category.tint).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: location.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: location.category.tint))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text(location.building)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Campus Map

import MapKit

struct CampusMapView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService.shared

    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.2100, longitude: -97.1530),
        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
    ))

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position) {
                    ForEach(DiningHall.sampleHalls) { hall in
                        Annotation(hall.name,
                                   coordinate: CLLocationCoordinate2D(
                                    latitude: hall.latitude,
                                    longitude: hall.longitude
                                   )) {
                            Button {
                                HapticService.shared.light()
                                MapService.openDirections(to: hall)
                            } label: {
                                VStack(spacing: 2) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hall.gradientStart))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: hall.iconName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    Text(hall.name)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                }
                            }
                        }
                    }
                    ForEach(RetailLocation.allLocations) { loc in
                        Annotation(loc.name, coordinate: loc.coordinate) {
                            Button {
                                HapticService.shared.light()
                                let placemark = MKPlacemark(coordinate: loc.coordinate)
                                let item = MKMapItem(placemark: placemark)
                                item.name = loc.name
                                item.openInMaps(launchOptions: [
                                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
                                ])
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: loc.category.tint))
                                        .frame(width: 24, height: 24)
                                    Image(systemName: loc.category.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    UserAnnotation()
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .including([.university])))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }

                // Hall list overlay
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(DiningHall.sampleHalls) { hall in
                            MapHallChip(hall: hall, locationService: locationService)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Campus Map")
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

private struct MapHallChip: View {
    let hall: DiningHall
    let locationService: LocationService

    private var distanceText: String? {
        guard let meters = locationService.distance(to: hall) else { return nil }
        return MapService.formattedDistance(meters: meters)
    }

    var body: some View {
        Button {
            HapticService.shared.light()
            MapService.openDirections(to: hall)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: hall.gradientStart))
                        .frame(width: 32, height: 32)
                    Image(systemName: hall.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(hall.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    HStack(spacing: 4) {
                        if let dist = distanceText {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text(dist)
                                .font(.system(size: 11, weight: .medium))
                        }
                        if hall.isOpen {
                            Text(hall.isOpen ? "Open" : "Closed")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(hall.isOpen ? Color.statusOpen : Color.statusClosed)
                        }
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.macroCarbs)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
