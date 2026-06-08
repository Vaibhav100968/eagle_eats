import SwiftUI
import MapKit

// MARK: - Retail Locations View
// Shows all places on campus that accept Dining Dollars.
// Accessible from Home screen via a "Dining Dollars" section.

struct RetailLocationsView: View {
    @StateObject private var locationService = LocationService.shared
    @State private var selectedCategory: RetailCategory? = nil
    @State private var searchText: String = ""
    @State private var appeared = false

    private var filteredLocations: [RetailLocation] {
        var locs = RetailLocation.allLocations
        if let cat = selectedCategory {
            locs = locs.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            locs = locs.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.building.localizedCaseInsensitiveContains(searchText)
            }
        }
        return locs
    }

    var body: some View {
        List {
            // Category filter
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(label: "All", icon: "mappin.and.ellipse",
                                     isSelected: selectedCategory == nil) {
                            withAnimation { selectedCategory = nil }
                        }
                        ForEach(RetailCategory.allCases) { cat in
                            CategoryChip(label: cat.rawValue, icon: cat.icon,
                                         tint: Color(hex: cat.tint),
                                         isSelected: selectedCategory == cat) {
                                withAnimation {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
            }

            // Locations
            Section {
                ForEach(filteredLocations) { loc in
                    RetailLocationRow(location: loc, locationService: locationService)
                }
            } header: {
                Text("\(filteredLocations.count) locations")
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search locations")
        .navigationTitle("Where to Spend")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Retail Location Row

private struct RetailLocationRow: View {
    let location: RetailLocation
    let locationService: LocationService

    private var distanceText: String? {
        guard let loc = locationService.currentLocation else { return nil }
        let user = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let dest = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return MapService.formattedDistance(meters: user.distance(from: dest))
    }

    var body: some View {
        Button {
            HapticService.shared.light()
            openDirections()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: location.category.tint).opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: location.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: location.category.tint))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(location.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(location.building)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(location.hoursText)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.textTertiary)

                        if let dist = distanceText {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                Text(dist)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Color.macroCarbs)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.macroCarbs)

                    if location.acceptsFlex {
                        Text("Flex")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.untGreenPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.untGreenPrimary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: location.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let label: String
    let icon: String
    var tint: Color = .untGreenPrimary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? tint : Color.surfaceRaised)
            .foregroundStyle(isSelected ? .white : Color.textSecondary)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
