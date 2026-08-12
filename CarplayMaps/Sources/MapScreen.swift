import SwiftUI
import MapKit
import CoreLocation
import AVFoundation
import ActivityKit

/// Guidance activity handle crossing into detached tasks; ActivityKit is safe for this use.
final class GuidanceActivityBox: @unchecked Sendable {
    var activity: Activity<GuidanceAttributes>?
}

struct MapScreen: View {
    @State private var model = RouteModel()
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var query = ""
    @State private var showSteps = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            map
            VStack(spacing: 10) {
                if model.isGuiding {
                    guidanceBanner
                } else {
                    searchBar
                    if !model.results.isEmpty && searchFocused {
                        resultsList
                    }
                }
                Spacer()
                if let route = model.route {
                    bottomCard(route)
                }
            }
            .padding()
        }
        .onAppear { model.requestLocation() }
        .onChange(of: query) {
            model.autocomplete(query)
        }
        .onChange(of: model.isGuiding) {
            camera = model.isGuiding
                ? .userLocation(followsHeading: true, fallback: .automatic)
                : .userLocation(fallback: .automatic)
        }
        .sheet(isPresented: $showSteps) {
            stepsSheet
        }
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            if let dest = model.destination {
                Marker(dest.name ?? "Destination", coordinate: dest.placemark.coordinate)
                    .tint(.red)
            }
            if let route = model.route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 6)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea()
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Where to?", text: $query)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .onSubmit { model.searchAndRoute(query) }
            if model.route != nil || model.destination != nil || !query.isEmpty {
                Button {
                    query = ""
                    model.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .glassEffect()
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.results) { result in
                Button {
                    searchFocused = false
                    query = result.title
                    model.route(toCompletion: result)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .font(.subheadline.bold())
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private var guidanceBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.turn.up.right")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.currentInstruction)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(model.distanceToNextManeuver)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.green.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
    }

    private func bottomCard(_ route: MKRoute) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(etaText(route.expectedTravelTime))
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                Text("\(distanceText(route.distance)) · arrive \(arrivalText(route.expectedTravelTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showSteps = true
            } label: {
                Image(systemName: "list.bullet").font(.title3)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
            Button {
                if model.isGuiding {
                    model.stopGuidance()
                } else {
                    model.startGuidance()
                }
            } label: {
                Label(model.isGuiding ? "End" : "Go",
                      systemImage: model.isGuiding ? "xmark" : "location.north.line.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isGuiding ? .red : .green)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var stepsSheet: some View {
        NavigationStack {
            List {
                if let route = model.route {
                    ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                        if !step.instructions.isEmpty {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "arrow.turn.up.right")
                                    .foregroundStyle(index == model.stepIndex ? .green : .blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.instructions).font(.subheadline)
                                    Text(distanceText(step.distance))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func etaText(_ t: TimeInterval) -> String {
        let mins = max(1, Int(t / 60))
        return mins >= 60 ? "\(mins / 60) hr \(mins % 60) min" : "\(mins) min"
    }

    private func distanceText(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        return miles < 0.2 ? "\(Int(meters * 3.28084)) ft" : String(format: "%.1f mi", miles)
    }

    private func arrivalText(_ t: TimeInterval) -> String {
        Date.now.addingTimeInterval(t).formatted(date: .omitted, time: .shortened)
    }
}

struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
}

@Observable
@MainActor
final class RouteModel {
    var results: [SearchResult] = []
    var destination: MKMapItem?
    var route: MKRoute?
    var isGuiding = false
    var stepIndex = 0
    var currentInstruction = ""
    var distanceToNextManeuver = ""

    private let manager = CLLocationManager()
    private let speech = AVSpeechSynthesizer()
    private var searchTask: Task<Void, Never>?
    private var guidanceTask: Task<Void, Never>?
    private let activityBox = GuidanceActivityBox()

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    // MARK: search — live as you type (debounced), no focus-out needed

    func autocomplete(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            if let loc = manager.location {
                request.region = MKCoordinateRegion(center: loc.coordinate,
                                                    latitudinalMeters: 60_000, longitudinalMeters: 60_000)
            }
            let response = try? await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            self.lastItems = response?.mapItems ?? []
            self.results = self.lastItems.prefix(6).map {
                SearchResult(title: $0.name ?? "Unknown", subtitle: $0.placemark.title ?? "")
            }
        }
    }

    private var lastItems: [MKMapItem] = []

    func searchAndRoute(_ text: String) {
        if let first = lastItems.first {
            routeTo(first)
        } else {
            autocomplete(text)
        }
    }

    func route(toCompletion result: SearchResult) {
        if let index = results.firstIndex(of: result), index < lastItems.count {
            routeTo(lastItems[index])
        }
    }

    private func routeTo(_ item: MKMapItem) {
        destination = item
        results = []
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = item
        request.transportType = .automobile
        Task {
            let response = try? await MKDirections(request: request).calculate()
            self.route = response?.routes.first
        }
    }

    // MARK: guidance — follow-me camera, auto-advancing steps, voice

    func startGuidance() {
        guard let route else { return }
        isGuiding = true
        stepIndex = firstRealStep(route)
        announceCurrentStep()
        guidanceTask = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                    guard !Task.isCancelled, self.isGuiding else { break }
                    guard let location = update.location else { continue }
                    self.tick(location)
                }
            } catch {
                // location stream ended; guidance banner stays on last instruction
            }
        }
    }

    func stopGuidance() {
        isGuiding = false
        guidanceTask?.cancel()
        speech.stopSpeaking(at: .immediate)
        let box = activityBox
        Task.detached {
            if let running = box.activity {
                box.activity = nil
                await running.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func updateGuidanceActivity() {
        guard isGuiding else { return }
        let eta = route.map { arrivalShort($0.expectedTravelTime) } ?? ""
        let state = GuidanceAttributes.ContentState(
            instruction: currentInstruction,
            distance: distanceToNextManeuver,
            eta: eta)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
        let attributes = GuidanceAttributes(destination: destination?.name ?? "Destination")
        let box = activityBox
        Task.detached {
            if let activity = box.activity {
                await activity.update(content)
            } else {
                box.activity = try? Activity.request(attributes: attributes, content: content)
            }
        }
    }

    private func arrivalShort(_ t: TimeInterval) -> String {
        Date.now.addingTimeInterval(t).formatted(date: .omitted, time: .shortened)
    }

    private func firstRealStep(_ route: MKRoute) -> Int {
        route.steps.firstIndex { !$0.instructions.isEmpty } ?? 0
    }

    private func tick(_ location: CLLocation) {
        guard let route, stepIndex < route.steps.count else { return }
        let step = route.steps[stepIndex]
        let end = maneuverPoint(of: step)
        let distance = location.distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        let label = distance < 322
            ? "\(Int(distance * 3.28084 / 10) * 10) ft"
            : String(format: "%.1f mi", distance / 1609.34)
        if label != distanceToNextManeuver {
            distanceToNextManeuver = label
            updateGuidanceActivity()
        }
        if distance < 30 {
            advanceStep()
        }
    }

    private func advanceStep() {
        guard let route else { return }
        var next = stepIndex + 1
        while next < route.steps.count && route.steps[next].instructions.isEmpty {
            next += 1
        }
        if next >= route.steps.count {
            currentInstruction = "You've arrived"
            distanceToNextManeuver = ""
            speak("You have arrived")
            stopGuidance()
            return
        }
        stepIndex = next
        announceCurrentStep()
    }

    private func announceCurrentStep() {
        guard let route, stepIndex < route.steps.count else { return }
        currentInstruction = route.steps[stepIndex].instructions
        speak(currentInstruction)
        updateGuidanceActivity()
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        speech.speak(AVSpeechUtterance(string: text))
    }

    private func maneuverPoint(of step: MKRoute.Step) -> CLLocationCoordinate2D {
        let polyline = step.polyline
        guard polyline.pointCount > 0 else { return CLLocationCoordinate2D() }
        return polyline.points()[polyline.pointCount - 1].coordinate
    }

    func clear() {
        stopGuidance()
        results = []
        lastItems = []
        destination = nil
        route = nil
        stepIndex = 0
        currentInstruction = ""
        distanceToNextManeuver = ""
    }
}
