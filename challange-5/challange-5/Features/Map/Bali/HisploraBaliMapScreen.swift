import ContentKit
import DesignSystem
import SwiftUI

/// Full-screen Whole Bali vintage cultural heritage map screen for Hisplora.
struct HisploraBaliMapScreen: View {

    @Bindable private var model: HisploraBaliMapViewModel
    private let onBack: (() -> Void)?
    private let onSwitchScope: (() -> Void)?
    private let onOpenQuest: ((HisploraBaliLandmark) -> Void)?

    init(
        model: HisploraBaliMapViewModel,
        onBack: (() -> Void)? = nil,
        onSwitchScope: (() -> Void)? = nil,
        onOpenQuest: ((HisploraBaliLandmark) -> Void)? = nil
    ) {
        self.model = model
        self.onBack = onBack
        self.onSwitchScope = onSwitchScope
        self.onOpenQuest = onOpenQuest
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. The Interactive Whole Bali Vintage Map Component
            HisploraBaliMapView(
                userLocation: model.userLocation,
                userHeading: model.userHeading,
                landmarks: model.landmarks,
                selectedCategory: model.selectedCategory,
                onSelectLandmark: { landmark in
                    model.selectLandmark(landmark)
                },
                onOpenQuest: { landmark in
                    onOpenQuest?(landmark)
                }
            )

            // 2. Top Editorial Header & Category Filter Bar
            VStack(spacing: KultaraMetrics.sm) {
                topHeaderBar
                categoryFilterBar
            }
            .padding(.top, 8)
        }
        .onAppear {
            model.startLiveTracking()
        }
        .onDisappear {
            model.stopLiveTracking()
        }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        HStack(alignment: .center, spacing: 8) {
            if let onBack {
                Button(action: onBack) {
                    ZStack {
                        Circle()
                            .fill(HisploraMapStyle.parchmentWarm.color)
                            .frame(width: 38, height: 38)
                            .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.18), radius: 3, y: 1.5)

                        Circle()
                            .stroke(HisploraMapStyle.roadCasing.color, lineWidth: 1.2)
                            .frame(width: 38, height: 38)

                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HisploraMapStyle.inkText.color)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            VStack(alignment: onBack == nil ? .center : .leading, spacing: 2) {
                Text("PULAU BALI")
                    .font(.system(size: 14, weight: .black, design: .serif))
                    .tracking(1.8)
                    .foregroundStyle(HisploraMapStyle.inkText.color)

                Text("CULTURAL HERITAGE ATLAS")
                    .font(.system(size: 8, weight: .bold, design: .serif))
                    .tracking(1.0)
                    .foregroundStyle(HisploraMapStyle.roadCasing.color.opacity(0.8))
            }
            .frame(maxWidth: onBack == nil ? .infinity : nil)

            Spacer()

            // Scope switcher button to Denpasar
            if let onSwitchScope {
                Button(action: onSwitchScope) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 11, weight: .bold))
                        Text("DENPASAR")
                            .font(.system(size: 9.5, weight: .black, design: .serif))
                            .tracking(0.8)
                    }
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(HisploraMapStyle.parchmentWarm.color)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.18), radius: 3, y: 1.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch to Denpasar Walking Map")
            }

            // Total Landmarks Badge
            HStack(spacing: 4) {
                Text("✦")
                    .font(.system(size: 8))
                    .foregroundStyle(HisploraMapStyle.markerActive.color)

                Text("\(model.totalLandmarksCount) SITES")
                    .font(.system(size: 9, weight: .heavy, design: .serif))
                    .tracking(0.6)
                    .foregroundStyle(HisploraMapStyle.inkText.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(HisploraMapStyle.parchmentWarm.color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(HisploraMapStyle.roadCasing.color, lineWidth: 1.0)
            )
            .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.12), radius: 2, y: 1)
        }
        .padding(.horizontal, KultaraMetrics.lg)
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KultaraMetrics.xs) {
                ForEach(HisploraBaliLandmarkCategory.allCases) { category in
                    let isSelected = model.selectedCategory == category
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            model.selectCategory(category)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))

                            Text(category.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .serif))
                        }
                        .foregroundStyle(isSelected ? HisploraMapStyle.parchmentWarm.color : HisploraMapStyle.inkText.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? HisploraMapStyle.markerActive.color : HisploraMapStyle.parchmentWarm.color)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(HisploraMapStyle.roadCasing.color, lineWidth: isSelected ? 1.4 : 1.0)
                        )
                        .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.12), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, KultaraMetrics.lg)
        }
    }
}

// MARK: - Preview

#Preview("Whole Bali Heritage Map") {
    HisploraBaliMapScreen(
        model: HisploraBaliMapViewModel(
            userLocation: Coordinate(lat: -8.6565, lon: 115.2125),
            userHeading: 42.0
        ),
        onBack: {},
        onOpenQuest: { landmark in
            print("Tapped quest: \(landmark.name)")
        }
    )
}
