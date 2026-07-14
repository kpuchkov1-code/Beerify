//
//  PubMapView.swift
//  Beerify
//
//  Map of nearby pubs with Pub Crawl route planning and Pub Golf game mode.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Location Manager

@Observable
final class PubLocationManager: NSObject, CLLocationManagerDelegate {
    var userLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            userLocation = loc
            manager.stopUpdatingLocation()
        }
    }
}

// MARK: - Pub Model

enum VenueType: String, CaseIterable {
    case pub = "Pub"
    case bar = "Bar"
    case club = "Club"

    var icon: String {
        switch self {
        case .pub: return "mug.fill"
        case .bar: return "wineglass.fill"
        case .club: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .pub: return Theme.accent
        case .bar: return Theme.info
        case .club: return Color(red: 0.6, green: 0.2, blue: 0.8)
        }
    }
}

struct Pub: Identifiable, Hashable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String?
    let venueType: VenueType
    let mapItem: MKMapItem?

    static func == (lhs: Pub, rhs: Pub) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Pub Golf Hole

struct PubGolfHole: Identifiable {
    let id = UUID()
    var pub: Pub
    var drink: String
    var par: Int
    var strokes: Int?
}

// MARK: - Route Leg (real directions or fallback straight line)

enum RouteLeg {
    case directions(MKRoute)
    case straightLine(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)

    var distance: Double {
        switch self {
        case .directions(let route): return route.distance
        case .straightLine(let a, let b):
            return CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        }
    }

    var expectedTravelTime: Double {
        switch self {
        case .directions(let route): return route.expectedTravelTime
        case .straightLine(let a, let b):
            // Rough walking estimate: 5 km/h
            let meters = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            return meters / 1.39 // 5 km/h in m/s
        }
    }
}

// MARK: - Main View

enum PubTab: String, CaseIterable {
    case map = "Map"
    case crawl = "Pub Crawl"
    case golf = "Pub Golf"
}

struct PubMapView: View {
    @State private var locationManager = PubLocationManager()
    @State private var pubs: [Pub] = []
    @State private var selectedTab: PubTab = .map
    @State private var crawlRoute: [Pub] = []
    @State private var golfHoles: [PubGolfHole] = []
    @State private var isSearching = false
    @State private var walkingRoutes: [RouteLeg] = []
    @State private var isCalculatingRoute = false
    private static let londonCenter = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                           latitudinalMeters: 5000, longitudinalMeters: 5000)
    ))
    @State private var searchCenter: CLLocationCoordinate2D = londonCenter
    @State private var hasInitialLocation = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Pubs")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            tabBar
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            switch selectedTab {
            case .map:
                pubMapSection
            case .crawl:
                pubCrawlSection
            case .golf:
                pubGolfSection
            }
        }
        .background(BeerifyBackground())
        .task {
            locationManager.requestPermission()
            // Wait briefly for user location, fall back to London
            for _ in 0..<20 {
                if locationManager.userLocation != nil { break }
                try? await Task.sleep(for: .milliseconds(150))
            }
            if let loc = locationManager.userLocation {
                searchCenter = loc.coordinate
            }
            hasInitialLocation = true
            await searchAllVenues()
        }
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(PubTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(selectedTab == tab ? .bold : .medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16).fill(
                            selectedTab == tab ? Theme.accent.opacity(0.25) : Theme.surface.opacity(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                            selectedTab == tab ? Theme.accent : Theme.hairline, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
            }
            Spacer()
        }
    }

    // MARK: Map Section

    private var pubMapSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .top) {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        ForEach(pubs) { pub in
                            Marker(pub.name, systemImage: pub.venueType.icon, coordinate: pub.coordinate)
                                .tint(pub.venueType.color)
                        }
                        // Walking route polylines
                        ForEach(Array(walkingRoutes.enumerated()), id: \.offset) { _, leg in
                            switch leg {
                            case .directions(let route):
                                MapPolyline(route)
                                    .stroke(Theme.accentDeep, lineWidth: 4)
                            case .straightLine(let a, let b):
                                MapPolyline(coordinates: [a, b])
                                    .stroke(Theme.accentDeep.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                            }
                        }
                        // Numbered stop annotations
                        ForEach(Array(activeRoute.enumerated()), id: \.element.id) { i, pub in
                            Annotation("", coordinate: pub.coordinate) {
                                ZStack {
                                    Circle().fill(Theme.accentDeep).frame(width: 26, height: 26)
                                    Circle().stroke(.white, lineWidth: 2).frame(width: 26, height: 26)
                                    Text("\(i + 1)").font(.caption2.weight(.heavy)).foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        searchCenter = context.region.center
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                }

                // "Search this area" button
                Button {
                    Task { await searchAllVenues() }
                } label: {
                    HStack(spacing: 6) {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(isSearching ? "Searching..." : "Search this area")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.accentDeep))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(BeerifyPressStyle())
                .padding(.top, 12)
                .disabled(isSearching)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            // Legend
            HStack(spacing: 16) {
                ForEach(VenueType.allCases, id: \.self) { type in
                    let count = pubs.filter { $0.venueType == type }.count
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .foregroundStyle(type.color)
                            .font(.caption)
                        Text("\(count) \(type.rawValue)\(count == 1 ? "" : "s")")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: Pub Crawl Section

    private var pubCrawlSection: some View {
        VStack(spacing: 0) {
            // Pinned route map at top
            routePreviewMap(stops: crawlRoute)
                .padding(.horizontal, 20)

            // Stats + clear bar
            if !crawlRoute.isEmpty {
                HStack(spacing: 10) {
                    if isCalculatingRoute {
                        ProgressView().controlSize(.small)
                        Text("Calculating...")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                    } else if !walkingRoutes.isEmpty {
                        let totalMeters = walkingRoutes.reduce(0.0) { $0 + $1.distance }
                        let totalMinutes = walkingRoutes.reduce(0.0) { $0 + $1.expectedTravelTime } / 60
                        Label(String(format: "%.1f km", totalMeters / 1000), systemImage: "figure.walk")
                        Label(String(format: "%.0f min", totalMinutes), systemImage: "clock")
                    }
                    Text("\(crawlRoute.count) stops")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.accentDeep)
                    Spacer()
                    Button {
                        crawlRoute.removeAll()
                        walkingRoutes = []
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundStyle(Theme.danger)
                            .padding(8)
                            .background(Circle().fill(Theme.danger.opacity(0.12)))
                    }
                    .buttonStyle(BeerifyPressStyle())
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 20).padding(.vertical, 6)
            }

            // Scrollable list
            ScrollView {
                LazyVStack(spacing: 6) {
                    // Route stops
                    if !crawlRoute.isEmpty {
                        ForEach(Array(crawlRoute.enumerated()), id: \.element.id) { i, pub in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(Theme.accentDeep).frame(width: 26, height: 26)
                                    Text("\(i + 1)").font(.caption2.weight(.heavy)).foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pub.name).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                                    if i < walkingRoutes.count - 1 {
                                        Text(String(format: "%.0f min walk to next", walkingRoutes[i].expectedTravelTime / 60))
                                            .font(.caption2).foregroundStyle(Theme.inkMuted)
                                    } else if i == crawlRoute.count - 1 && walkingRoutes.count == crawlRoute.count {
                                        Text(String(format: "%.0f min back to start", walkingRoutes.last!.expectedTravelTime / 60))
                                            .font(.caption2).foregroundStyle(Theme.inkMuted)
                                    }
                                }
                                Spacer()
                                if i > 0 {
                                    Button {
                                        crawlRoute.swapAt(i, i - 1)
                                        Task { await recalculateWalkingRoutes(for: crawlRoute) }
                                    } label: {
                                        Image(systemName: "chevron.up")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(Theme.inkMuted)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(Theme.surface))
                                    }
                                }
                                if i < crawlRoute.count - 1 {
                                    Button {
                                        crawlRoute.swapAt(i, i + 1)
                                        Task { await recalculateWalkingRoutes(for: crawlRoute) }
                                    } label: {
                                        Image(systemName: "chevron.down")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(Theme.inkMuted)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(Theme.surface))
                                    }
                                }
                                Button {
                                    crawlRoute.removeAll { $0.id == pub.id }
                                    optimiseRoute()
                                    Task { await recalculateWalkingRoutes(for: crawlRoute) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.inkMuted)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.95)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accentDeep.opacity(0.3), lineWidth: 1))
                        }

                        Divider().overlay(Theme.hairline).padding(.vertical, 4)
                    }

                    // Available pubs
                    ForEach(pubs) { pub in
                        let inRoute = crawlRoute.contains(pub)
                        Button {
                            if inRoute {
                                crawlRoute.removeAll { $0.id == pub.id }
                            } else {
                                crawlRoute.append(pub)
                            }
                            optimiseRoute()
                            Task { await recalculateWalkingRoutes(for: crawlRoute) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: inRoute ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(inRoute ? Theme.success : Theme.accent)
                                    .font(.body)
                                Image(systemName: pub.venueType.icon)
                                    .foregroundStyle(pub.venueType.color)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pub.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    if let addr = pub.address {
                                        Text(addr).font(.caption2).foregroundStyle(Theme.inkSoft)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            inRoute ? Theme.success.opacity(0.08) : Theme.surface.opacity(0.95)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                            inRoute ? Theme.success.opacity(0.3) : Theme.hairline, lineWidth: 1))
                        .buttonStyle(BeerifyPressStyle())
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
            }
        }
    }

    // MARK: Pub Golf Section

    private var pubGolfSection: some View {
        VStack(spacing: 0) {
            // Pinned route map
            routePreviewMap(stops: golfHoles.map(\.pub))
                .padding(.horizontal, 20)

            if !golfHoles.isEmpty && !walkingRoutes.isEmpty {
                HStack(spacing: 12) {
                    let totalMeters = walkingRoutes.reduce(0.0) { $0 + $1.distance }
                    let totalMinutes = walkingRoutes.reduce(0.0) { $0 + $1.expectedTravelTime } / 60
                    Label(String(format: "%.1f km", totalMeters / 1000), systemImage: "figure.walk")
                    Label(String(format: "%.0f min", totalMinutes), systemImage: "clock")
                    Spacer()
                    Text("\(golfHoles.count) holes")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.accentDeep)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 20).padding(.vertical, 6)
            }

            // Action buttons
            if !golfHoles.isEmpty {
                HStack(spacing: 8) {
                    if !crawlRoute.isEmpty && golfHoles.isEmpty {
                        Button {
                            golfHoles = crawlRoute.enumerated().map { i, pub in
                                PubGolfHole(pub: pub, drink: defaultDrink(for: i), par: defaultPar(for: i))
                            }
                            Task { await recalculateWalkingRoutes(for: golfHoles.map(\.pub)) }
                        } label: {
                            Label("Use Crawl Route", systemImage: "figure.walk")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(Theme.accentDeep))
                        }
                        .buttonStyle(BeerifyPressStyle())
                    }
                    Button {
                        golfHoles.removeAll()
                        walkingRoutes = []
                    } label: {
                        Label("Reset", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(Theme.danger.opacity(0.12)))
                    }
                    .buttonStyle(BeerifyPressStyle())
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.bottom, 4)
            }

            Divider().overlay(Theme.hairline).padding(.horizontal, 20)

            if golfHoles.isEmpty {
                // Pub selection list
                List {
                    if !crawlRoute.isEmpty {
                        Section {
                            Button {
                                golfHoles = crawlRoute.enumerated().map { i, pub in
                                    PubGolfHole(pub: pub, drink: defaultDrink(for: i), par: defaultPar(for: i))
                                }
                                Task { await recalculateWalkingRoutes(for: golfHoles.map(\.pub)) }
                            } label: {
                                Label("Use Pub Crawl Route (\(crawlRoute.count) stops)", systemImage: "figure.walk")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.accentDeep)
                            }
                            .listRowBackground(Theme.accent.opacity(0.1))
                        }
                    }

                    Section {
                        Text("Tap pubs to add holes. Each gets a drink and par.")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                            .listRowBackground(Color.clear)

                        ForEach(pubs) { pub in
                            let alreadyAdded = golfHoles.contains { $0.pub == pub }
                            Button {
                                if !alreadyAdded {
                                    let i = golfHoles.count
                                    golfHoles.append(PubGolfHole(pub: pub, drink: defaultDrink(for: i), par: defaultPar(for: i)))
                                    Task { await recalculateWalkingRoutes(for: golfHoles.map(\.pub)) }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(alreadyAdded ? Theme.success : Theme.accent)
                                    Image(systemName: pub.venueType.icon)
                                        .foregroundStyle(pub.venueType.color).font(.caption)
                                    Text(pub.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    Spacer()
                                }
                            }
                            .listRowBackground(alreadyAdded ? Theme.success.opacity(0.08) : Theme.surface.opacity(0.95))
                        }
                    } header: {
                        Text("Nearby Venues")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .textCase(nil)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                // Active game scorecard
                ScrollView {
                    VStack(spacing: 10) {
                        pubGolfScorecard
                    }
                    .padding(20)
                }
            }
        }
    }

    private var pubGolfScorecard: some View {
        VStack(spacing: 10) {
            ForEach(Array(golfHoles.enumerated()), id: \.element.id) { i, hole in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Hole \(i + 1)")
                            .font(.caption.weight(.bold)).foregroundStyle(Theme.accentDeep)
                        Spacer()
                        if let strokes = hole.strokes {
                            let diff = strokes - hole.par
                            Text(scoreLabel(diff))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(diff <= 0 ? Theme.success : Theme.danger)
                        }
                    }
                    Text(hole.pub.name)
                        .font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                    HStack {
                        Label(hole.drink, systemImage: "wineglass")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                        Spacer()
                        Text("Par \(hole.par)")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                    }

                    // Score input
                    HStack {
                        Text("Sips taken:")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                if let s = golfHoles[i].strokes, s > 1 {
                                    golfHoles[i].strokes = s - 1
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Theme.inkMuted)
                            }
                            Text("\(hole.strokes ?? 0)")
                                .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                                .frame(minWidth: 30)
                            Button {
                                golfHoles[i].strokes = (golfHoles[i].strokes ?? 0) + 1
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.95)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
            }

            // Total score
            let totalStrokes = golfHoles.compactMap(\.strokes).reduce(0, +)
            let totalPar = golfHoles.reduce(0) { $0 + $1.par }
            let completed = golfHoles.allSatisfy { $0.strokes != nil }

            HStack {
                VStack(alignment: .leading) {
                    Text("Total Score").font(.headline).foregroundStyle(Theme.ink)
                    if completed {
                        let diff = totalStrokes - totalPar
                        Text(diff == 0 ? "Even par!" : diff < 0 ? "\(diff) — Under par!" : "+\(diff) — Over par")
                            .font(.caption).foregroundStyle(diff <= 0 ? Theme.success : Theme.warning)
                    }
                }
                Spacer()
                Text("\(totalStrokes) / \(totalPar)")
                    .font(.title2.weight(.heavy)).foregroundStyle(Theme.accentDeep)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent, lineWidth: 1))
        }
    }

    // MARK: Search

    private func searchAllVenues() async {
        isSearching = true
        defer { isSearching = false }

        let region = MKCoordinateRegion(
            center: searchCenter,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )

        async let pubResults = searchVenues(query: "pub", type: .pub, in: region)
        async let barResults = searchVenues(query: "bar cocktail", type: .bar, in: region)
        async let clubResults = searchVenues(query: "nightclub club", type: .club, in: region)

        let allResults = await pubResults + barResults + clubResults
        // Deduplicate by id
        var seen = Set<String>()
        pubs = allResults.filter { seen.insert($0.id).inserted }
    }

    private func searchVenues(query: String, type: VenueType, in region: MKCoordinateRegion) async -> [Pub] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = region

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                let addr = item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
                return Pub(
                    id: item.identifier?.rawValue ?? UUID().uuidString,
                    name: name,
                    coordinate: item.location.coordinate,
                    address: addr,
                    venueType: type,
                    mapItem: item
                )
            }
        } catch {
            return []
        }
    }

    // MARK: Route Preview Map

    @ViewBuilder
    private func routePreviewMap(stops: [Pub]) -> some View {
        if stops.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.6))
                VStack(spacing: 6) {
                    Image(systemName: "map").font(.title2).foregroundStyle(Theme.inkMuted)
                    Text("Add pubs to see your route")
                        .font(.caption).foregroundStyle(Theme.inkMuted)
                }
            }
            .frame(height: 180)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
        } else {
            Map(position: .constant(mapPositionForStops(stops))) {
                ForEach(Array(walkingRoutes.enumerated()), id: \.offset) { _, leg in
                    switch leg {
                    case .directions(let route):
                        MapPolyline(route)
                            .stroke(Theme.accentDeep, lineWidth: 4)
                    case .straightLine(let a, let b):
                        MapPolyline(coordinates: [a, b])
                            .stroke(Theme.accentDeep.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    }
                }
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, pub in
                    Annotation("", coordinate: pub.coordinate) {
                        ZStack {
                            Circle().fill(Theme.accentDeep).frame(width: 24, height: 24)
                            Circle().stroke(.white, lineWidth: 2).frame(width: 24, height: 24)
                            Text("\(i + 1)").font(.caption2.weight(.heavy)).foregroundStyle(.white)
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
            .allowsHitTesting(false)
        }
    }

    private func mapPositionForStops(_ stops: [Pub]) -> MapCameraPosition {
        guard !stops.isEmpty else { return .automatic }
        let lats = stops.map(\.coordinate.latitude)
        let lons = stops.map(\.coordinate.longitude)
        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLon = (lons.min()! + lons.max()!) / 2
        let spanLat = max((lats.max()! - lats.min()!) * 1.6, 0.006)
        let spanLon = max((lons.max()! - lons.min()!) * 1.6, 0.006)
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        ))
    }

    // MARK: Route Calculation

    /// The active list of pubs for routing — crawl route or golf holes
    private var activeRoute: [Pub] {
        if !golfHoles.isEmpty { return golfHoles.map(\.pub) }
        return crawlRoute
    }

    private func recalculateWalkingRoutes(for stops: [Pub]) async {
        guard stops.count >= 2 else {
            walkingRoutes = []
            return
        }
        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        // Build pairs: each consecutive pair + loop back to first
        var pairs: [(from: Pub, to: Pub)] = []
        for i in 0..<(stops.count - 1) {
            pairs.append((stops[i], stops[i + 1]))
        }
        // Close the loop
        pairs.append((stops.last!, stops.first!))

        // Fetch directions for each leg with throttling and fallback
        var legs: [RouteLeg] = []
        for pair in pairs {
            let leg = await fetchDirectionsLeg(from: pair.from, to: pair.to)
            legs.append(leg)
            // Small delay between requests to avoid rate limiting
            try? await Task.sleep(for: .milliseconds(120))
        }
        walkingRoutes = legs
    }

    private func fetchDirectionsLeg(from: Pub, to: Pub, retries: Int = 2) async -> RouteLeg {
        let request = MKDirections.Request()
        request.source = from.mapItem ?? MKMapItem(location: CLLocation(latitude: from.coordinate.latitude, longitude: from.coordinate.longitude), address: nil)
        request.destination = to.mapItem ?? MKMapItem(location: CLLocation(latitude: to.coordinate.latitude, longitude: to.coordinate.longitude), address: nil)
        request.transportType = .walking

        for attempt in 0...retries {
            if attempt > 0 {
                // Exponential backoff
                try? await Task.sleep(for: .milliseconds(300 * attempt))
            }
            let directions = MKDirections(request: request)
            do {
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    return .directions(route)
                }
            } catch {
                continue
            }
        }
        // All retries failed — fall back to straight line
        return .straightLine(from: from.coordinate, to: to.coordinate)
    }

    // MARK: Route Optimisation

    private func optimiseRoute() {
        guard crawlRoute.count >= 2 else { return }
        let start = locationManager.userLocation?.coordinate ?? searchCenter

        if crawlRoute.count <= 14 {
            // Exact solution via Held-Karp dynamic programming.
            // Finds the provably shortest route. O(n² × 2^n), fast for ≤14 stops.
            crawlRoute = heldKarp(pubs: crawlRoute, start: start)
        } else {
            // For larger sets: nearest-neighbour seeded from multiple starts,
            // then 2-opt + or-opt refinement.
            crawlRoute = heuristicOptimise(pubs: crawlRoute, start: start)
        }
    }

    /// Exact TSP solver using Held-Karp (dynamic programming with bitmask).
    /// Guarantees the optimal visiting order from a fixed start point.
    private func heldKarp(pubs: [Pub], start: CLLocationCoordinate2D) -> [Pub] {
        let n = pubs.count
        // Precompute distance matrix: index 0 = start, 1..n = pubs
        var dist = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n + 1)
        for i in 0..<n {
            dist[0][i + 1] = distanceBetween(start, pubs[i].coordinate)
            dist[i + 1][0] = dist[0][i + 1]
            for j in 0..<n {
                if i != j {
                    dist[i + 1][j + 1] = distanceBetween(pubs[i].coordinate, pubs[j].coordinate)
                }
            }
        }

        let fullMask = (1 << n) - 1
        // dp[mask][i] = min distance to visit pubs in mask, ending at pub i (0-indexed)
        var dp = [[Double]](repeating: [Double](repeating: Double.infinity, count: n), count: 1 << n)
        var parent = [[Int]](repeating: [Int](repeating: -1, count: n), count: 1 << n)

        // Base case: go from start directly to each pub
        for i in 0..<n {
            dp[1 << i][i] = dist[0][i + 1]
        }

        // Fill DP table
        for mask in 1...fullMask {
            for last in 0..<n where mask & (1 << last) != 0 {
                guard dp[mask][last] < Double.infinity else { continue }
                for next in 0..<n where mask & (1 << next) == 0 {
                    let newMask = mask | (1 << next)
                    let newDist = dp[mask][last] + dist[last + 1][next + 1]
                    if newDist < dp[newMask][next] {
                        dp[newMask][next] = newDist
                        parent[newMask][next] = last
                    }
                }
            }
        }

        // Find the best ending pub for a circular route (include return to first pub)
        var bestEnd = 0
        var bestTotal = Double.infinity
        for i in 0..<n {
            // Cost = path to i + return from i back to first pub visited
            // We'll find the first pub in reconstruction, but for circular TSP
            // we add cost to return to start (the user's location)
            let total = dp[fullMask][i] + dist[i + 1][0]
            if total < bestTotal {
                bestTotal = total
                bestEnd = i
            }
        }

        // Reconstruct path
        var path: [Int] = []
        var mask = fullMask
        var cur = bestEnd
        while cur != -1 {
            path.append(cur)
            let prev = parent[mask][cur]
            mask ^= (1 << cur)
            cur = prev
        }
        path.reverse()

        return path.map { pubs[$0] }
    }

    /// Heuristic for larger routes: best of multiple nearest-neighbour starts + 2-opt + or-opt.
    private func heuristicOptimise(pubs: [Pub], start: CLLocationCoordinate2D) -> [Pub] {
        var bestRoute: [Pub] = pubs
        var bestDist = routeDistance(pubs, from: start)

        // Try nearest-neighbour from each pub as a starting bias
        for seed in 0..<min(pubs.count, 8) {
            var remaining = pubs
            var ordered: [Pub] = []

            // Force the seed pub first
            ordered.append(remaining.remove(at: seed))
            var current = ordered[0].coordinate

            // Nearest-neighbour for the rest
            while !remaining.isEmpty {
                let nearest = remaining.enumerated().min(by: {
                    distanceBetween(current, $0.element.coordinate) < distanceBetween(current, $1.element.coordinate)
                })!
                ordered.append(nearest.element)
                current = nearest.element.coordinate
                remaining.remove(at: nearest.offset)
            }

            // Pick the one with shortest distance from actual start
            // (we seeded from a pub, but the real route starts from user location)
            ordered = twoOpt(ordered, start: start)
            ordered = orOpt(ordered, start: start)

            let dist = routeDistance(ordered, from: start)
            if dist < bestDist {
                bestDist = dist
                bestRoute = ordered
            }
        }

        return bestRoute
    }

    /// 2-opt: reverse segments to uncross edges.
    private func twoOpt(_ route: [Pub], start: CLLocationCoordinate2D) -> [Pub] {
        var ordered = route
        guard ordered.count >= 4 else { return ordered }
        var improved = true
        while improved {
            improved = false
            for i in 0..<(ordered.count - 2) {
                for j in (i + 2)..<ordered.count {
                    let a = i == 0 ? start : ordered[i - 1].coordinate
                    let oldCost = distanceBetween(a, ordered[i].coordinate)
                        + (j + 1 < ordered.count ? distanceBetween(ordered[j].coordinate, ordered[j + 1].coordinate) : 0)
                    let newCost = distanceBetween(a, ordered[j].coordinate)
                        + (j + 1 < ordered.count ? distanceBetween(ordered[i].coordinate, ordered[j + 1].coordinate) : 0)
                    if newCost < oldCost - 1e-6 {
                        ordered[i...j].reverse()
                        improved = true
                    }
                }
            }
        }
        return ordered
    }

    /// Or-opt: relocate single stops or pairs to a better position.
    private func orOpt(_ route: [Pub], start: CLLocationCoordinate2D) -> [Pub] {
        var ordered = route
        guard ordered.count >= 3 else { return ordered }
        var improved = true
        while improved {
            improved = false
            for segLen in 1...min(3, ordered.count - 1) {
                for i in 0..<(ordered.count - segLen + 1) {
                    let segment = Array(ordered[i..<(i + segLen)])
                    var without = ordered
                    without.removeSubrange(i..<(i + segLen))

                    let oldDist = routeDistance(ordered, from: start)

                    for insertAt in 0...without.count {
                        var candidate = without
                        candidate.insert(contentsOf: segment, at: insertAt)
                        let newDist = routeDistance(candidate, from: start)
                        if newDist < oldDist - 1e-6 {
                            ordered = candidate
                            improved = true
                            break
                        }
                    }
                    if improved { break }
                }
                if improved { break }
            }
        }
        return ordered
    }

    private func routeDistance(_ route: [Pub], from start: CLLocationCoordinate2D) -> Double {
        guard let first = route.first, let last = route.last else { return 0 }
        var total = distanceBetween(start, first.coordinate)
        for i in 0..<(route.count - 1) {
            total += distanceBetween(route[i].coordinate, route[i + 1].coordinate)
        }
        // Circular: return from last stop back to first
        total += distanceBetween(last.coordinate, first.coordinate)
        return total
    }

    private func distanceBetween(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    // MARK: Pub Golf Helpers

    private static let drinks = ["Pint of lager", "Gin & tonic", "Shot of tequila", "Glass of wine", "Rum & coke", "Whiskey sour", "Cider", "Vodka soda", "Cocktail", "Stout"]
    private static let pars =   [5, 4, 2, 4, 3, 3, 5, 3, 4, 5]

    private func defaultDrink(for index: Int) -> String {
        Self.drinks[index % Self.drinks.count]
    }

    private func defaultPar(for index: Int) -> Int {
        Self.pars[index % Self.pars.count]
    }

    private func scoreLabel(_ diff: Int) -> String {
        switch diff {
        case ..<(-1): return "\(diff) Eagle!"
        case -1: return "-1 Birdie!"
        case 0: return "Par"
        case 1: return "+1 Bogey"
        default: return "+\(diff) Over"
        }
    }
}
