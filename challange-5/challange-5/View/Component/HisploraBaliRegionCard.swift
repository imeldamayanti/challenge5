import ContentKit
import DesignSystem
import SwiftUI

/// Parchment bottom information sheet displaying details about a selected landmark or regency on the Whole Bali map.
struct HisploraBaliRegionCard: View {

    let landmark: HisploraBaliLandmark
    let onFocus: (HisploraBaliLandmark) -> Void
    let onOpenQuest: ((HisploraBaliLandmark) -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            // Header Row: Category Badge, Regency, Close
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: KultaraMetrics.xs) {
                        Image(systemName: landmark.category.iconName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(HisploraMapStyle.markerActive.color)

                        Text("\(landmark.category.rawValue.uppercased()) • \(landmark.regency.uppercased())")
                            .font(.system(size: 10.5, weight: .black, design: .serif))
                            .foregroundStyle(HisploraMapStyle.markerActive.color)
                            .tracking(0.6)
                    }

                    Text(landmark.name)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(HisploraMapStyle.inkText.color)
                }

                Spacer()

                Button(action: onDismiss) {
                    ZStack {
                        Circle()
                            .fill(HisploraMapStyle.roadFill.color)
                            .frame(width: 28, height: 28)

                        Circle()
                            .stroke(HisploraMapStyle.roadCasing.color.opacity(0.35), lineWidth: 1)
                            .frame(width: 28, height: 28)

                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(HisploraMapStyle.inkText.color)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss details")
            }

            // Summary description
            Text(landmark.summary)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundStyle(HisploraMapStyle.inkText.color.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Metadata Badges (Distance, Elevation)
            HStack(spacing: KultaraMetrics.md) {
                if let distText = landmark.formattedDistance {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 11))
                        Text(distText)
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(HisploraMapStyle.parchmentGround.color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                if let elev = landmark.elevationM {
                    HStack(spacing: 4) {
                        Image(systemName: "mountain.2")
                            .font(.system(size: 11))
                        Text("\(Int(elev)) m altitude")
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(HisploraMapStyle.parchmentGround.color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer()
            }

            // Action Buttons
            HStack(spacing: KultaraMetrics.md) {
                Button {
                    onFocus(landmark)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder")
                        Text("Zoom to Area")
                    }
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(HisploraMapStyle.parchmentGround.color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if landmark.hasWalkingQuest {
                    Button {
                        onOpenQuest?(landmark)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Open Quest")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(HisploraMapStyle.parchmentWarm.color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(HisploraMapStyle.markerActive.color)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: HisploraMapStyle.markerActive.color.opacity(0.3), radius: 3, y: 1.5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(KultaraMetrics.lg)
        .background(HisploraMapStyle.parchmentWarm.color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HisploraMapStyle.roadCasing.color, lineWidth: 1.5)
        )
        .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.25), radius: 8, y: 3)
        .padding(.horizontal, KultaraMetrics.lg)
    }
}
