import ContentKit
import DesignSystem
import SwiftUI

/// Camera mode for the Hisplora map.
enum HisploraCameraMode: Sendable, Equatable {
    case free
    case followUser
    case focused(Coordinate)
}

/// The reusable custom vintage Balinese heritage map component for Hisplora.
///
/// Combines mathematical coordinate projection, high-performance canvas vector rendering,
/// live GPS positioning, custom explorer markers, interactive quest pins, and parchment overlays.
struct HisploraMapView: View {

    // MARK: - Inputs

    let userLocation: Coordinate?
    let userHeading: Double?
    let questLocations: [HisploraQuestLocation]
    let activeQuest: HisploraQuestLocation?
    let completedQuests: Set<String>
    let route: [Coordinate]?
    let onSelectQuest: ((HisploraQuestLocation) -> Void)?
    let onBeginTrace: ((HisploraQuestLocation) -> Void)?

    // MARK: - State

    @State private var zoom: CGFloat = 1.0
    @GestureState private var pinch: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @GestureState private var drag: CGSize = .zero

    @State private var selectedQuest: HisploraQuestLocation?
    @State private var selectedBuilding: GeoLibreBuilding?
    @State private var buildingOptions = GeoLibreBuildingOptions()
    @State private var showLayerCustomizerSheet = false

    @State private var cameraMode: HisploraCameraMode = .free
    @State private var isSettling = false
    @State private var settleToken = UUID()
    @State private var hasInitialized = false

    private static let minimumZoom: CGFloat = 0.75
    private static let maximumZoom: CGFloat = 6.5

    init(
        userLocation: Coordinate? = nil,
        userHeading: Double? = nil,
        questLocations: [HisploraQuestLocation] = HisploraQuestLocation.badungTraces,
        activeQuest: HisploraQuestLocation? = nil,
        completedQuests: Set<String> = [],
        route: [Coordinate]? = nil,
        buildingOptions: GeoLibreBuildingOptions = GeoLibreBuildingOptions(),
        onSelectQuest: ((HisploraQuestLocation) -> Void)? = nil,
        onBeginTrace: ((HisploraQuestLocation) -> Void)? = nil
    ) {
        self.userLocation = userLocation
        self.userHeading = userHeading
        self.questLocations = questLocations
        self.activeQuest = activeQuest
        self.completedQuests = completedQuests
        self.route = route
        _buildingOptions = State(initialValue: buildingOptions)
        self.onSelectQuest = onSelectQuest
        self.onBeginTrace = onBeginTrace
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

            let projection = HisploraMapProjection(
                center: HisploraDenpasarDistrict.centerCoordinate,
                zoom: currentScale,
                panOffset: effectivePan,
                viewportSize: viewport
            )

            ZStack(alignment: .topLeading) {
                mapCanvasView(projection: projection, viewport: viewport)
                grainOverlayView(viewport: viewport)
                questMarkersView(projection: projection)
                userMarkerView(projection: projection)
                controlsOverlayView(projection: projection)
                selectedCardView
            }
            .frame(width: viewport.width, height: viewport.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleCanvasTap(at: value.location, projection: projection)
                    }
            )
            .gesture(SimultaneousGesture(panGesture(projection: projection), zoomGesture(projection: projection)))
            .onTapGesture(count: 2) { toggleDoubleTapZoom(projection: projection) }
            .sheet(isPresented: $showLayerCustomizerSheet) {
                layerCustomizerSheet
            }
            .onAppear {
                if !hasInitialized {
                    hasInitialized = true
                    centerOnInitialContent(projection: projection)
                }
            }
            .onChange(of: userLocation) { _, newLocation in
                if cameraMode == .followUser, let newLocation {
                    panToCoordinate(newLocation, projection: projection)
                }
            }
        }
        .ignoresSafeArea(edges: .all)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func mapCanvasView(projection: HisploraMapProjection, viewport: CGSize) -> some View {
        HisploraMapCanvas(
            projection: projection,
            route: route,
            activeQuestCoordinate: activeQuest?.coordinate,
            userCoordinate: userLocation,
            buildingOptions: buildingOptions,
            selectedBuildingID: selectedBuilding?.id
        )
        .frame(width: viewport.width, height: viewport.height)
    }

    @ViewBuilder
    private func grainOverlayView(viewport: CGSize) -> some View {
        if let grain = KultaraPaperTexture.grain {
            grain
                .resizable(resizingMode: .tile)
                .opacity(KultaraPaperTexture.grainOpacity * 0.4)
                .blendMode(.multiply)
                .allowsHitTesting(false)
                .frame(width: viewport.width, height: viewport.height)
        }
    }

    @ViewBuilder
    private func questMarkersView(projection: HisploraMapProjection) -> some View {
        ForEach(questLocations) { quest in
            let resolved = resolvedLocation(for: quest)
            let point = projection.project(resolved.coordinate)

            HisploraQuestMarkerView(
                location: resolved,
                isSelected: selectedQuest?.id == resolved.id
            ) {
                handleQuestSelection(resolved)
            }
            .position(x: point.x, y: point.y)
        }
    }

    private func resolvedLocation(for quest: HisploraQuestLocation) -> HisploraQuestLocation {
        let isCompleted = completedQuests.contains(quest.id) || quest.state == .completed
        let isCurrentActive = (activeQuest?.id == quest.id) || quest.state == .active
        var resolved = quest
        resolved.state = isCompleted ? .completed : (isCurrentActive ? .active : .uncompleted)
        return resolved
    }

    private func handleQuestSelection(_ resolvedQuest: HisploraQuestLocation) {
        guard !isManipulating else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedQuest = resolvedQuest
        }
        onSelectQuest?(resolvedQuest)
    }

    @ViewBuilder
    private func userMarkerView(projection: HisploraMapProjection) -> some View {
        if let user = userLocation {
            let userPoint = projection.project(user)
            HisploraUserLocationMarker(heading: userHeading)
                .position(x: userPoint.x, y: userPoint.y)
                .animation(.easeInOut(duration: 0.35), value: user)
        }
    }

    @ViewBuilder
    private func controlsOverlayView(projection: HisploraMapProjection) -> some View {
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

                    // Layer Customizer Button
                    Button {
                        showLayerCustomizerSheet = true
                    } label: {
                        controlCircle(icon: "square.3.layers.3d")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Customise map layers and buildings")

                    // Re-center Button
                    recenterButton(projection: projection)
                }
                .padding(.trailing, KultaraMetrics.lg)
                .padding(.bottom, (selectedQuest != nil || selectedBuilding != nil) ? 180 : 32)
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
    private var selectedCardView: some View {
        if let selected = selectedQuest {
            VStack {
                Spacer()
                HisploraQuestCard(
                    location: selected,
                    onBeginTrace: { location in
                        onBeginTrace?(location)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedQuest = nil
                        }
                    }
                )
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        } else if let building = selectedBuilding {
            VStack {
                Spacer()
                HisploraBuildingInspectionCard(
                    building: building,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedBuilding = nil
                        }
                    }
                )
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Layer Customizer Sheet (GeoLibre Style Controls)

    @ViewBuilder
    private var layerCustomizerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                    // 1. Building Display Style
                    VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                        Text("BUILDING RENDER MODE")
                            .font(.system(size: 11, weight: .black, design: .serif))
                            .foregroundStyle(HisploraMapStyle.markerActive.color)
                            .tracking(1.0)

                        Picker("Render Mode", selection: $buildingOptions.renderMode) {
                            ForEach(GeoLibreBuildingOptions.RenderMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(HisploraMapStyle.parchmentWarm.color)
                    .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.md))

                    // 2. Toggles
                    VStack(spacing: KultaraMetrics.md) {
                        Toggle("Enable Buildings Layer", isOn: $buildingOptions.isEnabled)
                        Toggle("Show Building Names (Zoomed)", isOn: $buildingOptions.showBuildingLabels)
                        Toggle("Show Cadastral Parcels", isOn: $buildingOptions.showParcels)
                    }
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(HisploraMapStyle.inkText.color)
                    .tint(HisploraMapStyle.markerActive.color)
                    .padding()
                    .background(HisploraMapStyle.parchmentWarm.color)
                    .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.md))

                    // 3. Building Category Filters
                    VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                        Text("VISIBLE BUILDING CATEGORIES")
                            .font(.system(size: 11, weight: .black, design: .serif))
                            .foregroundStyle(HisploraMapStyle.markerActive.color)
                            .tracking(1.0)

                        ForEach(GeoLibreBuilding.BuildingClass.allCases) { bClass in
                            let isIncluded = buildingOptions.visibleClasses.contains(bClass)
                            Button {
                                if isIncluded {
                                    buildingOptions.visibleClasses.remove(bClass)
                                } else {
                                    buildingOptions.visibleClasses.insert(bClass)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: bClass.iconName)
                                        .frame(width: 22)
                                        .foregroundStyle(HisploraMapStyle.markerActive.color)
                                    Text(bClass.displayName)
                                        .font(.system(size: 13, weight: .medium, design: .serif))
                                        .foregroundStyle(HisploraMapStyle.inkText.color)
                                    Spacer()
                                    if isIncluded {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(HisploraMapStyle.markerActive.color)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(HisploraMapStyle.parchmentWarm.color)
                    .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.md))
                }
                .padding()
            }
            .background(HisploraMapStyle.parchmentGround.color)
            .navigationTitle("Map Customizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showLayerCustomizerSheet = false
                    }
                    .foregroundStyle(HisploraMapStyle.markerActive.color)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Canvas Tap Handling

    private func handleCanvasTap(at point: CGPoint, projection: HisploraMapProjection) {
        guard buildingOptions.isEnabled else { return }

        // Ray casting hit-testing across buildings
        for building in HisploraDenpasarDistrict.buildings {
            guard buildingOptions.visibleClasses.contains(building.class) else { continue }
            let groundPts = building.coordinates.map { projection.project($0) }
            let heightPixels = projection.metersToPoints(building.heightM)
            let roofPts = GeoLibreBuildingMath.computeRoofPoints(groundPoints: groundPts, heightPixels: heightPixels)

            let hitGround = GeoLibreBuildingMath.contains(point: point, in: groundPts)
            let hitRoof = GeoLibreBuildingMath.contains(point: point, in: roofPts)

            if hitGround || hitRoof {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedQuest = nil
                    selectedBuilding = building
                }
                return
            }
        }

        // Tap empty ground dismisses building selection
        if selectedBuilding != nil {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBuilding = nil
            }
        }
    }

    // MARK: - Re-center Control Button

    private func recenterButton(projection: HisploraMapProjection) -> some View {
        Button {
            handleRecenter(projection: projection)
        } label: {
            ZStack {
                Circle()
                    .fill(HisploraMapStyle.parchmentWarm.color)
                    .frame(width: 40, height: 40)
                    .shadow(color: HisploraMapStyle.roadCasing.color.opacity(0.18), radius: 3, y: 1.5)

                Circle()
                    .stroke(HisploraMapStyle.roadCasing.color.opacity(0.4), lineWidth: 1.2)
                    .frame(width: 40, height: 40)

                Image(systemName: userLocation != nil ? "location.fill" : "map.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(cameraMode == .followUser ? HisploraMapStyle.markerActive.color : HisploraMapStyle.roadCasing.color)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Re-center on user location")
    }

    private func handleRecenter(projection: HisploraMapProjection) {
        if let user = userLocation {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                cameraMode = .followUser
                panToCoordinate(user, projection: projection)
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                pan = .zero
                zoom = 1.0
                cameraMode = .free
            }
        }
    }

    // MARK: - Gestures & Manipulation

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

    private func panGesture(projection: HisploraMapProjection) -> some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                cameraMode = .free
                let proposed = CGSize(
                    width: pan.width + value.translation.width,
                    height: pan.height + value.translation.height
                )
                pan = projection.clampedPan(proposed)
                settleAfterGesture()
            }
    }

    private func zoomGesture(projection: HisploraMapProjection) -> some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let target = min(max(zoom * value.magnification, Self.minimumZoom), Self.maximumZoom)
                zoom = target
                if target <= 0.8 {
                    pan = .zero
                } else {
                    pan = projection.clampedPan(pan)
                }
                settleAfterGesture()
            }
    }

    private func toggleDoubleTapZoom(projection: HisploraMapProjection) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if zoom > 1.2 {
                zoom = 1.0
                pan = .zero
            } else {
                zoom = 2.2
            }
        }
    }

    private func centerOnInitialContent(projection: HisploraMapProjection) {
        if let user = userLocation {
            panToCoordinate(user, projection: projection)
        } else if let active = activeQuest {
            panToCoordinate(active.coordinate, projection: projection)
        }
    }

    private func panToCoordinate(_ target: Coordinate, projection: HisploraMapProjection) {
        let center = HisploraDenpasarDistrict.centerCoordinate
        let deltaLon = CGFloat(target.lon - center.lon)
        let deltaLat = CGFloat(target.lat - center.lat)

        let targetPanX = -deltaLon * projection.pointsPerDegreeLon
        let targetPanY = deltaLat * projection.pointsPerDegreeLat

        pan = projection.clampedPan(CGSize(width: targetPanX, height: targetPanY))
    }
}

// MARK: - Previews

#Preview("Hisplora Map Component") {
    HisploraMapView(
        userLocation: Coordinate(lat: -8.6585, lon: 115.2075),
        userHeading: 42.0,
        questLocations: HisploraQuestLocation.badungTraces,
        activeQuest: HisploraQuestLocation.badungTraces[1],
        completedQuests: ["trace-01"],
        route: [
            Coordinate(lat: -8.6595, lon: 115.2077),
            Coordinate(lat: -8.6580, lon: 115.2075),
            Coordinate(lat: -8.6570, lon: 115.2085),
            Coordinate(lat: -8.6565, lon: 115.2095),
            Coordinate(lat: -8.6552, lon: 115.2112),
            Coordinate(lat: -8.6540, lon: 115.2115)
        ],
        onSelectQuest: { trace in
            print("Selected quest: \(trace.title)")
        },
        onBeginTrace: { trace in
            print("Begin trace: \(trace.title)")
        }
    )
}

#Preview("GeoLibre 2.5D Buildings Customizer") {
    HisploraMapView(
        userLocation: Coordinate(lat: -8.6593, lon: 115.2074),
        questLocations: HisploraQuestLocation.badungTraces,
        buildingOptions: GeoLibreBuildingOptions(renderMode: .isometric25D, showBuildingLabels: true, showParcels: true)
    )
}
