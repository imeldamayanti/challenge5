import ContentKit
import DesignSystem
import SwiftUI

/// Reusable full-island interactive vintage Balinese heritage map component for Hisplora.
///
/// Provides smooth pan/pinch navigation across the entire island of Bali, live GPS positioning,
/// category filtering (Pura, Puri, Nature, Villages), landmark discovery, and parchment details.
struct HisploraBaliMapView: View {

    // MARK: - Inputs

    let userLocation: Coordinate?
    let userHeading: Double?
    let landmarks: [HisploraBaliLandmark]
    let selectedCategory: HisploraBaliLandmarkCategory
    let onSelectLandmark: ((HisploraBaliLandmark) -> Void)?
    let onOpenQuest: ((HisploraBaliLandmark) -> Void)?

    // MARK: - State

    @State private var zoom: CGFloat = 1.0
    @GestureState private var pinch: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @GestureState private var drag: CGSize = .zero

    @State private var selectedLandmark: HisploraBaliLandmark?
    @State private var isSettling = false
    @State private var settleToken = UUID()

    private static let minimumZoom: CGFloat = 0.70
    private static let maximumZoom: CGFloat = 6.5

    init(
        userLocation: Coordinate? = nil,
        userHeading: Double? = nil,
        landmarks: [HisploraBaliLandmark] = HisploraBaliGeoData.landmarks,
        selectedCategory: HisploraBaliLandmarkCategory = .all,
        onSelectLandmark: ((HisploraBaliLandmark) -> Void)? = nil,
        onOpenQuest: ((HisploraBaliLandmark) -> Void)? = nil
    ) {
        self.userLocation = userLocation
        self.userHeading = userHeading
        self.landmarks = landmarks
        self.selectedCategory = selectedCategory
        self.onSelectLandmark = onSelectLandmark
        self.onOpenQuest = onOpenQuest
    }

    private var currentScale: CGFloat {
        min(max(zoom * pinch, Self.minimumZoom), Self.maximumZoom)
    }

    var body: some View {
        GeometryReader { proxy in
            let viewport = proxy.size
            let effectivePan = CGSize(
                width: pan.width + drag.width,
                height: pan.height + drag.height
            )

            let projection = HisploraBaliMapProjection(
                center: HisploraBaliGeoData.islandCenter,
                zoom: currentScale,
                panOffset: effectivePan,
                viewportSize: viewport
            )

            ZStack(alignment: .topLeading) {
                // 1. Vector Map Canvas (Parchment ocean, coastlines, peaks, lakes, highways, compass)
                canvasView(projection: projection, viewport: viewport)

                // 2. Paper Grain Speckle Overlay
                grainOverlayView(viewport: viewport)

                // 3. Cultural Heritage Landmark Markers
                landmarkMarkersView(projection: projection)

                // 4. Live Explorer User Location Marker
                userMarkerView(projection: projection)

                // 5. Controls Overlay (Re-center / Full Island Button)
                controlsOverlayView(projection: projection)

                // 6. Selected Landmark Bottom Information Card
                selectedCardOverlay(projection: projection)
            }
            .frame(width: viewport.width, height: viewport.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(SimultaneousGesture(panGesture(projection: projection), zoomGesture(projection: projection)))
            .onTapGesture(count: 2) { toggleDoubleTapZoom(projection: projection) }
        }
        .ignoresSafeArea(edges: .all)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func canvasView(projection: HisploraBaliMapProjection, viewport: CGSize) -> some View {
        HisploraBaliMapCanvas(
            projection: projection,
            selectedLandmarkCoordinate: selectedLandmark?.coordinate,
            userCoordinate: userLocation
        )
        .frame(width: viewport.width, height: viewport.height)
    }

    @ViewBuilder
    private func grainOverlayView(viewport: CGSize) -> some View {
        // `KultaraGround` rather than the old `KultaraPaperTexture`: the museum grain was replaced
        // by `275:2179`'s printed sheet on 2026-08-19. Tiled and multiplied at low opacity it still
        // reads as grain here — the sheet is 98.6% #FDF2DE, so multiplying by it warms the
        // parchment slightly and the 1.43% speckle lands as a faint dot.
        if let grain = KultaraGround.image {
            grain
                .resizable(resizingMode: .tile)
                .opacity(KultaraGround.opacity * 0.4)
                .blendMode(.multiply)
                .allowsHitTesting(false)
                .frame(width: viewport.width, height: viewport.height)
        }
    }

    @ViewBuilder
    private func landmarkMarkersView(projection: HisploraBaliMapProjection) -> some View {
        let filtered = filteredLandmarks
        ForEach(filtered) { landmark in
            let point = projection.project(landmark.coordinate)
            let isSelected = selectedLandmark?.id == landmark.id

            landmarkPin(landmark: landmark, isSelected: isSelected)
                .position(x: point.x, y: point.y)
                .onTapGesture {
                    guard !isManipulating else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedLandmark = landmark
                    }
                    onSelectLandmark?(landmark)
                }
        }
    }

    private var filteredLandmarks: [HisploraBaliLandmark] {
        if selectedCategory == .all {
            return landmarks
        } else {
            return landmarks.filter { $0.category == selectedCategory }
        }
    }

    private func landmarkPin(landmark: HisploraBaliLandmark, isSelected: Bool) -> some View {
        ZStack {
            // Pin Shadow
            Circle()
                .fill(HisploraMapStyle.roadCasing.color.opacity(0.25))
                .frame(width: isSelected ? 32 : 24, height: isSelected ? 32 : 24)
                .offset(y: 2)

            // Pin Background
            Circle()
                .fill(isSelected ? HisploraMapStyle.markerActive.color : HisploraMapStyle.parchmentWarm.color)
                .frame(width: isSelected ? 30 : 22, height: isSelected ? 30 : 22)

            // Pin Border
            Circle()
                .stroke(HisploraMapStyle.roadCasing.color, lineWidth: isSelected ? 1.6 : 1.2)
                .frame(width: isSelected ? 30 : 22, height: isSelected ? 30 : 22)

            // Icon Glyph
            Image(systemName: landmark.category.iconName)
                .font(.system(size: isSelected ? 13 : 9.5, weight: .bold))
                .foregroundStyle(isSelected ? HisploraMapStyle.parchmentWarm.color : HisploraMapStyle.inkText.color)

            // Title Label (visible when selected or on higher zoom)
            if isSelected || currentScale > 2.0 {
                Text(landmark.name)
                    .font(.system(size: 8.5, weight: .bold, design: .serif))
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(HisploraMapStyle.parchmentWarm.color.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 0.8)
                    )
                    .offset(y: isSelected ? -24 : -18)
            }
        }
        .frame(width: 44, height: 44) // 44pt touch target
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(landmark.name), \(landmark.category.rawValue)")
    }

    @ViewBuilder
    private func userMarkerView(projection: HisploraBaliMapProjection) -> some View {
        if let user = userLocation {
            let pt = projection.project(user)
            HisploraUserLocationMarker(heading: userHeading)
                .position(x: pt.x, y: pt.y)
                .animation(.easeInOut(duration: 0.35), value: user)
        }
    }

    @ViewBuilder
    private func controlsOverlayView(projection: HisploraBaliMapProjection) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    // Zoom In Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            zoom = min(zoom * 1.4, Self.maximumZoom)
                        }
                    } label: {
                        controlCircle(icon: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Zoom in")

                    // Zoom Out Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            zoom = max(zoom / 1.4, Self.minimumZoom)
                        }
                    } label: {
                        controlCircle(icon: "minus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Zoom out")

                    // Full Island View Button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            zoom = 1.0
                            pan = .zero
                        }
                    } label: {
                        controlCircle(icon: "map")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View whole island")

                    // Re-center on User Button
                    if let user = userLocation {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                zoom = 2.5
                                centerOnCoordinate(user, projection: projection)
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(HisploraMapStyle.parchmentWarm.color)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.18), radius: 3, y: 1.5)

                                Circle()
                                    .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1.2)
                                    .frame(width: 40, height: 40)

                                Image(systemName: "location.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(HisploraMapStyle.markerActive.color)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Re-center on my location")
                    }
                }
                .padding(.trailing, KultaraMetrics.lg)
                .padding(.bottom, selectedLandmark != nil ? 220 : 36)
            }
        }
    }

    @ViewBuilder
    private func controlCircle(icon: String) -> some View {
        ZStack {
            Circle()
                .fill(HisploraMapStyle.parchmentWarm.color)
                .frame(width: 40, height: 40)
                .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.18), radius: 3, y: 1.5)

            Circle()
                .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1.2)
                .frame(width: 40, height: 40)

            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(HisploraMapStyle.inkText.color)
        }
    }

    @ViewBuilder
    private func selectedCardOverlay(projection: HisploraBaliMapProjection) -> some View {
        if let selected = selectedLandmark {
            VStack {
                Spacer()
                HisploraBaliRegionCard(
                    landmark: selected,
                    onFocus: { landmark in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            zoom = 3.0
                            centerOnCoordinate(landmark.coordinate, projection: projection)
                        }
                    },
                    onOpenQuest: { landmark in
                        onOpenQuest?(landmark)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedLandmark = nil
                        }
                    }
                )
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Navigation & Gestures

    private var isManipulating: Bool {
        isSettling || drag != .zero || pinch != 1.0
    }

    private func settleAfterGesture() {
        let token = UUID()
        settleToken = token
        isSettling = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard settleToken == token else { return }
            isSettling = false
        }
    }

    private func panGesture(projection: HisploraBaliMapProjection) -> some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let proposed = CGSize(
                    width: pan.width + value.translation.width,
                    height: pan.height + value.translation.height
                )
                pan = projection.clampedPan(proposed)
                settleAfterGesture()
            }
    }

    private func zoomGesture(projection: HisploraBaliMapProjection) -> some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let target = min(max(zoom * value.magnification, Self.minimumZoom), Self.maximumZoom)
                zoom = target
                if target <= 0.85 {
                    pan = .zero
                } else {
                    pan = projection.clampedPan(pan)
                }
                settleAfterGesture()
            }
    }

    private func toggleDoubleTapZoom(projection: HisploraBaliMapProjection) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if zoom > 1.3 {
                zoom = 1.0
                pan = .zero
            } else {
                zoom = 2.4
            }
        }
    }

    private func centerOnCoordinate(_ target: Coordinate, projection: HisploraBaliMapProjection) {
        let center = HisploraBaliGeoData.islandCenter
        let deltaLon = CGFloat(target.lon - center.lon)
        let deltaLat = CGFloat(target.lat - center.lat)

        let targetPanX = -deltaLon * projection.pointsPerDegreeLon
        let targetPanY = deltaLat * projection.pointsPerDegreeLat

        pan = projection.clampedPan(CGSize(width: targetPanX, height: targetPanY))
    }
}

// MARK: - Preview

#Preview("Whole Bali Map Component") {
    HisploraBaliMapView(
        userLocation: Coordinate(lat: -8.6565, lon: 115.2125),
        userHeading: 35.0,
        landmarks: HisploraBaliGeoData.landmarks,
        selectedCategory: .all,
        onSelectLandmark: { landmark in
            print("Selected: \(landmark.name)")
        },
        onOpenQuest: { landmark in
            print("Open quest: \(landmark.name)")
        }
    )
}
