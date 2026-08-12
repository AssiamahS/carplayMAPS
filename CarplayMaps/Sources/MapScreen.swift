import SwiftUI
import MapKit
import CoreLocation

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
                searchBar
                if !model.results.isEmpty && searchFocused {
                    resultsList
                }
                Spacer()
                if let route = model.route {
                    etaCard(route)
                }
            }
            .padding()
        }
        .onAppear { model.requestLocation() }
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
                .onSubmit { model.search(query) }
            if model.route != nil || model.destination != nil {
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
            ForEach(model.results, id: \.self) { item in
                Button {
                    searchFocused = false
                    model.route(to: item)
                    query = item.name ?? query
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Unknown")
                            .font(.subheadline.bold())
                        if let locality = item.placemark.title {
                            Text(locality)
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

    private func etaCard(_ route: MKRoute) -> some View {
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
                Image(systemName: "list.bullet")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var stepsSheet: some View {
        NavigationStack {
            List {
                if let route = model.route {
                    ForEach(Array(route.steps.enumerated()), id: \.offset) { _, step in
                        if !step.instructions.isEmpty {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "arrow.turn.up.right")
                                    .foregroundStyle(.blue)
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
        let mins = Int(t / 60)
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

@Observable
@MainActor
final class RouteModel {
    var results: [MKMapItem] = []
    var destination: MKMapItem?
    var route: MKRoute?

    private let manager = CLLocationManager()

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func search(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let loc = manager.location {
            request.region = MKCoordinateRegion(center: loc.coordinate,
                                                latitudinalMeters: 40_000, longitudinalMeters: 40_000)
        }
        Task {
            let response = try? await MKLocalSearch(request: request).start()
            self.results = Array((response?.mapItems ?? []).prefix(6))
        }
    }

    func route(to item: MKMapItem) {
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

    func clear() {
        results = []
        destination = nil
        route = nil
    }
}
