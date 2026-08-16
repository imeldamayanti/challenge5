import ContentKit
import DesignSystem
import SwiftUI

// MARK: - Custom Explorer "YOU" Location Marker

/// The Hisplora explorer compass user location marker.
///
/// Implements the custom vintage cartographic explorer symbol:
/// ```text
///         ✦
///       ╱   ╲
///      │ YOU │
///       ╲   ╱
///         ●
/// ```
struct HisploraUserLocationMarker: View {

    let heading: Double?
    let accuracyM: Double?

    @State private var isPulsing = false

    init(heading: Double? = nil, accuracyM: Double? = nil) {
        self.heading = heading
        self.accuracyM = accuracyM
    }

    var body: some View {
        ZStack {
            // 1. Subtle breathing radar pulse for GPS accuracy
            Circle()
                .stroke(HisploraMapStyle.markerActive.color.opacity(isPulsing ? 0.0 : 0.4), lineWidth: 1.5)
                .frame(width: isPulsing ? 64 : 32, height: isPulsing ? 64 : 32)
                .animation(
                    .easeOut(duration: 2.2).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // 2. Heading direction needle (if available)
            if let heading {
                VStack(spacing: 0) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(HisploraMapStyle.markerActive.color)
                        .offset(y: -24)
                    Spacer()
                }
                .frame(width: 32, height: 48)
                .rotationEffect(.degrees(heading))
            }

            // 3. The Explorer Cartographic Diamond
            ZStack {
                // Diamond parchment background
                DiamondShape()
                    .fill(HisploraMapStyle.parchmentWarm.color)
                    .frame(width: 34, height: 34)
                    .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.25), radius: 3, x: 0, y: 1.5)

                // Diamond outer ink rim
                DiamondShape()
                    .stroke(HisploraMapStyle.roadCasing.color, lineWidth: 1.8)
                    .frame(width: 34, height: 34)

                // Diamond inner dashed boundary
                DiamondShape()
                    .stroke(HisploraMapStyle.roadCasing.color.opacity(0.5), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
                    .frame(width: 28, height: 28)

                // "YOU" Inscription
                Text("YOU")
                    .font(.system(size: 8.5, weight: .black, design: .serif))
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .tracking(0.5)

                // Top Star (✦)
                VStack {
                    Text("✦")
                        .font(.system(size: 7))
                        .foregroundStyle(HisploraMapStyle.markerActive.color)
                        .offset(y: -20)
                    Spacer()
                }
                .frame(height: 34)

                // Bottom Anchor Dot (●)
                VStack {
                    Spacer()
                    Circle()
                        .fill(HisploraMapStyle.roadCasing.color)
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 19)
                }
                .frame(height: 34)
            }
            .frame(width: 44, height: 44) // 44pt touch target
        }
        .onAppear {
            isPulsing = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your location: exploring on parchment map")
    }
}

// MARK: - Diamond Shape

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Quest Marker View

/// Illustrated heritage quest marker for the vintage map.
struct HisploraQuestMarkerView: View {

    let location: HisploraQuestLocation
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var activePulse = false

    init(
        location: HisploraQuestLocation,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void
    ) {
        self.location = location
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                switch location.state {
                case .uncompleted:
                    uncompletedMarker
                case .active:
                    activeMarker
                case .completed:
                    completedStampMarker
                }
            }
            .frame(width: 44, height: 44) // Meets 44pt Apple accessibility requirement
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Uncompleted State (Hand-drawn heritage glyph)

    private var uncompletedMarker: some View {
        ZStack {
            Circle()
                .fill(HisploraMapStyle.parchmentWarm.color)
                .frame(width: 24, height: 24)
                .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.2), radius: 2, y: 1)

            Circle()
                .stroke(HisploraMapStyle.roadCasing.color, lineWidth: 1.4)
                .frame(width: 24, height: 24)

            Circle()
                .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), style: StrokeStyle(lineWidth: 0.6, dash: [2, 1.5]))
                .frame(width: 19, height: 19)

            Text("\(location.traceNumber)")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundStyle(HisploraMapStyle.roadCasing.color)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Active State (Pulsing Amber/Red Beacon)

    private var activeMarker: some View {
        ZStack {
            // Pulse wave
            Circle()
                .stroke(HisploraMapStyle.markerActive.color.opacity(activePulse ? 0.0 : 0.5), lineWidth: 2)
                .frame(width: activePulse ? 52 : 30, height: activePulse ? 52 : 30)
                .animation(
                    .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                    value: activePulse
                )

            // Outer ring
            Circle()
                .fill(HisploraMapStyle.parchmentWarm.color)
                .frame(width: 32, height: 32)
                .shadow(color: HisploraMapStyle.markerActive.color.opacity(0.35), radius: 4, y: 2)

            Circle()
                .stroke(HisploraMapStyle.markerActive.color, lineWidth: 2.2)
                .frame(width: 32, height: 32)

            // Inner heritage symbol & number
            VStack(spacing: -1) {
                Text("✦")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(HisploraMapStyle.markerActive.color)
                Text("\(location.traceNumber)")
                    .font(.system(size: 12, weight: .black, design: .serif))
                    .foregroundStyle(HisploraMapStyle.markerActive.color)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.05)
        .onAppear {
            activePulse = true
        }
    }

    // MARK: - Completed State (Wax / Ink Stamp Effect)

    private var completedStampMarker: some View {
        ZStack {
            // Stamped double ring
            Circle()
                .fill(HisploraMapStyle.parchmentGround.color)
                .frame(width: 26, height: 26)

            Circle()
                .stroke(HisploraMapStyle.markerCompleted.color.opacity(0.85), lineWidth: 1.8)
                .frame(width: 26, height: 26)

            Circle()
                .stroke(HisploraMapStyle.markerCompleted.color.opacity(0.5), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
                .frame(width: 21, height: 21)

            // Stamp check / seal glyph
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(HisploraMapStyle.markerCompleted.color)
        }
        .rotationEffect(.degrees(-6)) // Vintage crooked stamp effect
        .scaleEffect(isSelected ? 1.15 : 1.0)
    }

    private var accessibilityDescription: String {
        switch location.state {
        case .uncompleted:
            "Trace \(location.traceNumber): \(location.title), unvisited"
        case .active:
            "Active Trace \(location.traceNumber): \(location.title), in progress"
        case .completed:
            "Discovered Trace \(location.traceNumber): \(location.title), completed"
        }
    }
}
