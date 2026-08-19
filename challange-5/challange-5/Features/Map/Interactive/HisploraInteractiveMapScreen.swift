import ContentKit
import DesignSystem
import SwiftUI

/// Full-screen interactive vintage Balinese heritage map screen for the Hisplora walking quest.
///
/// Designed to meet the vision: "I am exploring a real place through an old map."
struct HisploraInteractiveMapScreen: View {

    @Bindable private var model: HisploraMapViewModel
    private let onBack: (() -> Void)?
    private let onSwitchScope: (() -> Void)?
    private let onBeginTrace: ((HisploraQuestLocation) -> Void)?

    init(
        model: HisploraMapViewModel,
        onBack: (() -> Void)? = nil,
        onSwitchScope: (() -> Void)? = nil,
        onBeginTrace: ((HisploraQuestLocation) -> Void)? = nil
    ) {
        self.model = model
        self.onBack = onBack
        self.onSwitchScope = onSwitchScope
        self.onBeginTrace = onBeginTrace
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. The Full Interactive Vintage Map Component
            HisploraMapView(
                userLocation: model.userLocation,
                userHeading: model.userHeading,
                questLocations: model.traces,
                activeQuest: model.activeTrace,
                completedQuests: model.completedTraceIDs,
                route: model.walkingRoute,
                onSelectQuest: { trace in
                    model.selectTrace(trace)
                },
                onBeginTrace: { trace in
                    onBeginTrace?(trace)
                }
            )
            .ignoresSafeArea()

            // 2. Minimalist Vintage Top Bar Header
            topHeader
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.top, 8)
        }
        .onAppear {
            model.startLiveTracking()
        }
        .onDisappear {
            model.stopLiveTracking()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            // Back button
            if let onBack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(HisploraMapStyle.roadCasing.color)
                    .frame(width: 40, height: 40)
                    .background(HisploraMapStyle.parchmentWarm.color)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.18), radius: 3, y: 1.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go back")
            }

            Spacer()

            // Editorial Title & Discovered Traces Badge
            VStack(spacing: 2) {
                Text("THE LAST TRACES")
                    .font(.system(size: 12, weight: .black, design: .serif))
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .tracking(1.8)

                Text(model.discoveryProgressText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(HisploraMapStyle.goldStamp.color)
                    .tracking(0.8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Capsule()
                        .fill(HisploraMapStyle.parchmentWarm.color.opacity(0.95))
                    Capsule()
                        .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1)
                }
                .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.15), radius: 4, y: 1.5)
            )

            Spacer()

            // Scope switcher button to Whole Bali
            if let onSwitchScope {
                Button(action: onSwitchScope) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe.asia.australia.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("BALI")
                            .font(.system(size: 10, weight: .black, design: .serif))
                            .tracking(1.0)
                    }
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(HisploraMapStyle.parchmentWarm.color)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.18), radius: 3, y: 1.5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch to Whole Bali Map")
            } else {
                // Trace count badge fallback
                ZStack {
                    Circle()
                        .fill(HisploraMapStyle.parchmentWarm.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.18), radius: 3, y: 1.5)

                    Text("\(model.discoveredCount)")
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .foregroundStyle(HisploraMapStyle.markerCompleted.color)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(model.discoveredCount) traces discovered")
            }
        }
    }
}

// MARK: - Preview

#Preview("Denpasar Heritage Walking Map") {
    HisploraInteractiveMapScreen(
        model: HisploraMapViewModel(
            userLocation: Coordinate(lat: -8.6585, lon: 115.2075),
            userHeading: 42.0
        ),
        onBack: {},
        onBeginTrace: { trace in
            print("Begin trace: \(trace.title)")
        }
    )
}
