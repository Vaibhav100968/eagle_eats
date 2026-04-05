import SwiftUI

// MARK: - Live Crowd Strip
// Compact indicator shown at the top of DiningHallDetailView.
// Uses CrowdFlowService data with smooth animated transitions.

struct LiveCrowdStrip: View {
    let hallId: String
    @StateObject private var crowdFlow = CrowdFlowService.shared
    @State private var appeared = false

    private var snap: CrowdSnapshot {
        crowdFlow.snapshot(for: hallId)
    }

    private var barColor: Color {
        Color(hex: snap.level.tint)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(barColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: snap.level.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(barColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Live Crowd")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text(snap.level.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(barColor)
                        .clipShape(Capsule())
                }

                Text(snap.prediction)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // Crowd bar
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor.opacity(0.15))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor)
                            .frame(width: geo.size.width * (Double(snap.score) / 100.0))
                            .animation(.spring(response: 0.8, dampingFraction: 0.75), value: snap.score)
                    }
                }
                .frame(width: 60, height: 6)

                Text("\(snap.score)%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: snap.score)
            }
        }
        .padding(14)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}
