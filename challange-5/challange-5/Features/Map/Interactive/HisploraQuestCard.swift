import ContentKit
import DesignSystem
import SwiftUI

/// Parchment-style bottom information card shown when selecting a heritage quest location / trace.
struct HisploraQuestCard: View {

    let location: HisploraQuestLocation
    let onBeginTrace: (HisploraQuestLocation) -> Void
    let onDismiss: () -> Void

    init(
        location: HisploraQuestLocation,
        onBeginTrace: @escaping (HisploraQuestLocation) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.location = location
        self.onBeginTrace = onBeginTrace
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            // Header Row: Title & Close
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.title)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(HisploraMapStyle.inkText.color)
                        .textCase(.uppercase)
                        .tracking(1.0)

                    HStack(spacing: 6) {
                        Text("TRACE \(String(format: "%02d", location.traceNumber))")
                            .font(.system(size: 11, weight: .black, design: .serif))
                            .foregroundStyle(HisploraMapStyle.markerActive.color)
                            .tracking(1.2)

                        Text("·")
                            .foregroundStyle(HisploraMapStyle.inkTextMuted.color)

                        Text(location.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(HisploraMapStyle.inkTextMuted.color)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HisploraMapStyle.inkTextMuted.color)
                        .frame(width: 30, height: 30)
                        .background(HisploraMapStyle.parchmentSunken.color)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close trace details")
            }

            // Summary description
            if !location.summary.isEmpty {
                Text(location.summary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HisploraMapStyle.inkText.color.opacity(0.85))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Bottom action row
            HStack {
                // Distance badge
                if let distance = location.distanceText {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 12))
                        Text(distance)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(HisploraMapStyle.inkTextMuted.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(HisploraMapStyle.parchmentSunken.color)
                    .clipShape(Capsule())
                }

                Spacer()

                // "Begin Trace →" Button
                Button {
                    onBeginTrace(location)
                } label: {
                    HStack(spacing: 6) {
                        Text(location.state == .completed ? "Revisit Trace" : "Begin Trace")
                            .font(.system(size: 13, weight: .bold, design: .serif))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(HisploraMapStyle.parchmentWarm.color)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(HisploraMapStyle.roadCasing.color)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(HisploraMapStyle.goldStamp.color.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(KultaraMetrics.lg)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(HisploraMapStyle.parchmentWarm.color)
                RoundedRectangle(cornerRadius: 16)
                    .stroke(HisploraMapStyle.roadCasing.color, lineWidth: 1.5)
                RoundedRectangle(cornerRadius: 14)
                    .stroke(HisploraMapStyle.roadCasing.color.opacity(0.3), style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
                    .padding(3)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
        )
        .padding(.horizontal, KultaraMetrics.md)
    }
}
