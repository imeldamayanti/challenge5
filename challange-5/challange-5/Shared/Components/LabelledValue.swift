import DesignSystem
import SwiftUI

struct LabelledValue: View {
    @Environment(\.kultaraPalette) private var palette
    let label: String
    let value: String
    var emphasised: Bool = false

    var body: some View {
        // `ViewThatFits` keeps one line when it fits and stacks when Dynamic Type makes it too
        // wide, rather than truncating either side.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: KultaraMetrics.sm) {
                labelText
                Spacer(minLength: KultaraMetrics.sm)
                valueText
            }
            VStack(alignment: .leading, spacing: 2) {
                labelText
                valueText
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var labelText: some View {
        Text(label)
            .kultaraFont(.metadata)
            .foregroundStyle(palette.inkMuted.color)
    }

    private var valueText: some View {
        Text(value)
            .kultaraFont(.metadata)
            .foregroundStyle(emphasised ? palette.seal.color : palette.ink.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
