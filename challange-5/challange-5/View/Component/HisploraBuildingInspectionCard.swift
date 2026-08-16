import ContentKit
import DesignSystem
import SwiftUI

/// Vintage parchment bottom sheet displayed when a user taps any heritage building on the map.
struct HisploraBuildingInspectionCard: View {

    let building: GeoLibreBuilding
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            // Header: Category Pill & Close Button
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: building.class.iconName)
                        .font(.system(size: 11, weight: .bold))
                    Text(building.class.displayName.uppercased())
                        .font(.system(size: 10, weight: .black, design: .serif))
                        .tracking(1.0)
                }
                .foregroundStyle(HisploraMapStyle.markerActive.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HisploraMapStyle.parchmentSunken.color)
                .clipShape(Capsule())

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HisploraMapStyle.inkTextMuted.color)
                        .frame(width: 28, height: 28)
                        .background(HisploraMapStyle.parchmentSunken.color)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close building details")
            }

            // Title & Architectural Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(building.name)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(HisploraMapStyle.inkText.color)

                HStack(spacing: 6) {
                    Text(building.architecturalStyle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HisploraMapStyle.inkTextMuted.color)

                    Text("·")
                        .foregroundStyle(HisploraMapStyle.inkTextMuted.color)

                    Text("\(Int(building.heightM))m Height (\(building.levels) Lv)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(HisploraMapStyle.goldStamp.color)
                }
            }

            // Historical Note
            if let note = building.historyNote {
                Text(note)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(HisploraMapStyle.inkText.color.opacity(0.85))
                    .lineSpacing(2)
            }
        }
        .padding(KultaraMetrics.lg)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: KultaraMetrics.md)
                    .fill(HisploraMapStyle.parchmentWarm.color)

                RoundedRectangle(cornerRadius: KultaraMetrics.md)
                    .stroke(HisploraMapStyle.roadCasing.color.opacity(0.6), lineWidth: 1.4)
            }
            .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.22), radius: 8, y: 4)
        )
        .padding(.horizontal, KultaraMetrics.lg)
    }
}
