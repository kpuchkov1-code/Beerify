//
//  PubMapView.swift
//  Beerify
//
//  Map of nearby pubs with Pub Crawl route planning and Pub Golf game mode.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Seeded RNG (for deterministic bingo cards in rooms)

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

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
    case bingo = "Bingo"
}

struct PubMapView: View {
    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store
    @State private var locationManager = PubLocationManager()
    @State private var pubs: [Pub] = []
    @State private var selectedTab: PubTab = .map
    @State private var crawlRoute: [Pub] = []
    @State private var golfHoles: [PubGolfHole] = []
    @State private var isSearching = false
    @State private var walkingRoutes: [RouteLeg] = []
    @State private var isCalculatingRoute = false
    @State private var golfGameActive = false
    // Bingo state
    @State private var bingoCard: [BingoSquare] = []
    @State private var bingoSeed: Int = 0
    @State private var showBingoCelebration: Bool = false
    @State private var bingoLines: Set<Int> = []  // indices of completed lines (0-4 rows, 5-9 cols, 10-11 diags)
    @State private var fullHouse: Bool = false
    private static let londonCenter = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                           latitudinalMeters: 5000, longitudinalMeters: 5000)
    ))
    @State private var searchCenter: CLLocationCoordinate2D = londonCenter
    @State private var hasInitialLocation = false

    var body: some View {
        ZStack {
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
            case .bingo:
                pubBingoSection
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

        // Full-screen bingo celebration
        if showBingoCelebration {
            bingoCelebrationOverlay
        }
        } // ZStack
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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

            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                HStack(spacing: 8) {
                    Image(systemName: "location.slash.fill").foregroundStyle(Theme.warning)
                    Text("Location access is off - showing a default area. Enable location in Settings to find pubs near you.")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.warning.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.warning.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 20)
            }

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
                VStack(spacing: 6) {
                    // Route stops - drag to reorder
                    if !crawlRoute.isEmpty {
                        routeStopsList

                        Divider().overlay(Theme.hairline).padding(.vertical, 4)
                    }

                    // Available pubs (excluding those already in the route)
                    let available = pubs.filter { pub in !crawlRoute.contains(where: { $0.id == pub.id }) }
                    ForEach(available) { pub in
                        Button {
                            crawlRoute.append(pub)
                            optimiseRoute()
                            Task { await recalculateWalkingRoutes(for: crawlRoute) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Theme.accent)
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
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.95)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                        .buttonStyle(BeerifyPressStyle())
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
            }
        }
    }

    // MARK: Route Stops List (drag to reorder)

    private var routeStopsList: some View {
        ForEach(Array(crawlRoute.enumerated()), id: \.element.id) { i, pub in
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Theme.inkMuted)
                    .font(.caption)
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
                Button {
                    crawlRoute.removeAll { $0.id == pub.id }
                    Task { await recalculateWalkingRoutes(for: crawlRoute) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.95)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accentDeep.opacity(0.3), lineWidth: 1))
            .draggable(pub.id) {
                // Drag preview
                Text(pub.name)
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentDeep.opacity(0.9)))
                    .foregroundStyle(.white)
            }
            .dropDestination(for: String.self) { items, _ in
                guard let draggedId = items.first,
                      let fromIndex = crawlRoute.firstIndex(where: { $0.id == draggedId }),
                      let toIndex = crawlRoute.firstIndex(where: { $0.id == pub.id }),
                      fromIndex != toIndex else { return false }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    crawlRoute.move(fromOffsets: IndexSet(integer: fromIndex),
                                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                }
                Task { await recalculateWalkingRoutes(for: crawlRoute) }
                return true
            }
        }
    }

    // MARK: Pub Golf Section

    private var inRoom: Bool {
        store.data.room != nil && roomService.isActive
    }

    private var hasSharedGame: Bool {
        roomService.pubGolfGame != nil
    }

    private var pubGolfSection: some View {
        VStack(spacing: 0) {
            let showingGame = golfGameActive || hasSharedGame

            // How to play - shown before the game starts
            if !showingGame {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How to play").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("Each pub is a hole. Each hole has a drink and a par (target number of sips to finish it). Drink up, count your sips, and log them. Fewer sips = better score. Lowest total wins!")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.info.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.info.opacity(0.4), lineWidth: 1))
                .padding(.horizontal, 20).padding(.bottom, 8)
            }

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

            // Action buttons when holes are selected but game not started
            if !golfHoles.isEmpty && !golfGameActive && !hasSharedGame {
                HStack(spacing: 8) {
                    // Start game button
                    Button {
                        golfGameActive = true
                        if inRoom {
                            let sharedHoles = golfHoles.map { hole in
                                SharedPubGolfHole(
                                    id: hole.id.uuidString,
                                    pubName: hole.pub.name,
                                    latitude: hole.pub.coordinate.latitude,
                                    longitude: hole.pub.coordinate.longitude,
                                    drink: hole.drink,
                                    par: hole.par
                                )
                            }
                            roomService.pubGolfStart(holes: sharedHoles)
                        }
                    } label: {
                        Label(inRoom ? "Start Game (share with room)" : "Start Game", systemImage: "flag.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(Theme.success))
                    }
                    .buttonStyle(BeerifyPressStyle())

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

            // End game button when active
            if golfGameActive || hasSharedGame {
                HStack(spacing: 8) {
                    Button {
                        golfGameActive = false
                        golfHoles.removeAll()
                        walkingRoutes = []
                        if inRoom { roomService.pubGolfEnd() }
                    } label: {
                        Label("End Game", systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(Theme.danger.opacity(0.12)))
                    }
                    .buttonStyle(BeerifyPressStyle())
                    Spacer()
                    if inRoom {
                        let memberCount = roomService.pubGolfGame?.progress.count ?? 0
                        Label("\(memberCount) playing", systemImage: "person.2.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accentDeep)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 4)
            }

            Divider().overlay(Theme.hairline).padding(.horizontal, 20)

            if showingGame {
                // Active game scorecard
                ScrollView {
                    VStack(spacing: 10) {
                        pubGolfScorecard
                    }
                    .padding(20)
                }
            } else {
                // Pub selection list - always visible until game starts.
                // Selected holes show as checked so you can keep adding more.
                List {
                    // Selected holes summary
                    if !golfHoles.isEmpty {
                        Section {
                            ForEach(Array(golfHoles.enumerated()), id: \.element.id) { i, hole in
                                HStack(spacing: 8) {
                                    Text("\(i + 1)")
                                        .font(.caption.weight(.heavy)).foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Theme.accentDeep))
                                    Image(systemName: hole.pub.venueType.icon)
                                        .foregroundStyle(hole.pub.venueType.color).font(.caption)
                                    Text(hole.pub.name)
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text(hole.drink).font(.caption2).foregroundStyle(Theme.inkSoft)
                                    Text("Par \(hole.par)")
                                        .font(.caption.weight(.bold)).foregroundStyle(Theme.accentDeep)
                                    Button {
                                        golfHoles.remove(at: i)
                                        Task { await optimiseAndRouteGolfHoles() }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Theme.inkMuted)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .listRowBackground(Theme.success.opacity(0.08))
                            }
                        } header: {
                            Text("Your Course (\(golfHoles.count) hole\(golfHoles.count == 1 ? "" : "s"))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accentDeep)
                                .textCase(nil)
                        }
                    }

                    if !crawlRoute.isEmpty && golfHoles.isEmpty {
                        Section {
                            Button {
                                golfHoles = crawlRoute.enumerated().map { i, pub in
                                    PubGolfHole(pub: pub, drink: defaultDrink(for: i), par: defaultPar(for: i))
                                }
                                Task { await optimiseAndRouteGolfHoles() }
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
                                if alreadyAdded {
                                    golfHoles.removeAll { $0.pub == pub }
                                } else {
                                    let i = golfHoles.count
                                    golfHoles.append(PubGolfHole(pub: pub, drink: defaultDrink(for: i), par: defaultPar(for: i)))
                                }
                                Task { await optimiseAndRouteGolfHoles() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(alreadyAdded ? Theme.success : Theme.accent)
                                    Image(systemName: pub.venueType.icon)
                                        .foregroundStyle(pub.venueType.color).font(.caption)
                                    Text(pub.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    Spacer()
                                    if alreadyAdded, let idx = golfHoles.firstIndex(where: { $0.pub == pub }) {
                                        Text("Hole \(idx + 1)")
                                            .font(.caption2.weight(.bold)).foregroundStyle(Theme.accentDeep)
                                    }
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
            }
        }
        .onChange(of: roomService.pubGolfGame) { _, newGame in
            // When a shared game arrives from the room and we don't have local holes,
            // populate them so we see the course.
            if let game = newGame, golfHoles.isEmpty {
                golfHoles = game.holes.map { hole in
                    let coord = CLLocationCoordinate2D(latitude: hole.latitude, longitude: hole.longitude)
                    let pub = Pub(id: hole.id, name: hole.pubName, coordinate: coord,
                                  address: nil, venueType: .pub, mapItem: nil)
                    return PubGolfHole(pub: pub, drink: hole.drink, par: hole.par)
                }
                golfGameActive = true
                Task { await optimiseAndRouteGolfHoles() }
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
                                    broadcastGolfScore(holeIndex: i)
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
                                broadcastGolfScore(holeIndex: i)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }

                    // Show room members' scores for this hole
                    if let game = roomService.pubGolfGame, game.progress.count > 1 {
                        let holeId = hole.id.uuidString
                        let myId = store.data.room?.memberId
                        let others = game.progress.values.filter { $0.memberId != myId }
                        if !others.isEmpty {
                            Divider().overlay(Theme.hairline)
                            ForEach(others.sorted(by: { $0.memberName < $1.memberName }), id: \.memberId) { prog in
                                HStack(spacing: 6) {
                                    Text(Avatars.avatar(for: prog.memberId)).font(.caption)
                                    Text(prog.memberName).font(.caption2.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                                    Spacer()
                                    if let score = prog.scores[holeId] {
                                        Text("\(score) sips").font(.caption2.weight(.bold)).foregroundStyle(Theme.ink)
                                        let diff = score - hole.par
                                        Text(scoreLabel(diff))
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(diff <= 0 ? Theme.success : Theme.danger)
                                    } else if prog.currentHoleIndex == i {
                                        Text("drinking...").font(.caption2).foregroundStyle(Theme.accent)
                                    } else if prog.currentHoleIndex > i {
                                        Text("--").font(.caption2).foregroundStyle(Theme.inkMuted)
                                    } else {
                                        Text("waiting").font(.caption2).foregroundStyle(Theme.inkMuted)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.95)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
            }

            // Room leaderboard
            if let game = roomService.pubGolfGame, game.progress.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leaderboard").font(.headline).foregroundStyle(Theme.ink)
                    let sorted = game.progress.values.sorted { a, b in
                        let aTotal = a.scores.values.reduce(0, +)
                        let bTotal = b.scores.values.reduce(0, +)
                        return aTotal < bTotal
                    }
                    ForEach(Array(sorted.enumerated()), id: \.element.memberId) { rank, prog in
                        let total = prog.scores.values.reduce(0, +)
                        let holesPlayed = prog.scores.count
                        HStack {
                            Text("\(rank + 1).").font(.caption.weight(.bold)).foregroundStyle(Theme.accentDeep)
                                .frame(width: 20, alignment: .leading)
                            Text(Avatars.avatar(for: prog.memberId)).font(.caption)
                            Text(prog.memberName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(holesPlayed)/\(golfHoles.count) holes")
                                .font(.caption2).foregroundStyle(Theme.inkSoft)
                            Text("\(total) sips")
                                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.accentDeep)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
            }

            // Total score
            let totalStrokes = golfHoles.compactMap(\.strokes).reduce(0, +)
            let totalPar = golfHoles.reduce(0) { $0 + $1.par }
            let completed = golfHoles.allSatisfy { $0.strokes != nil }

            HStack {
                VStack(alignment: .leading) {
                    Text("Your Score").font(.headline).foregroundStyle(Theme.ink)
                    if completed {
                        let diff = totalStrokes - totalPar
                        Text(diff == 0 ? "Even par!" : diff < 0 ? "\(diff) - Under par!" : "+\(diff) - Over par")
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

    // MARK: - Pub Bingo

    struct BingoSquare: Identifiable {
        let id: Int           // 0-24 position on the grid
        let challenge: String
        var completed: Bool
    }

    static let bingoChallenges: [SpicyPrompt] = [
        // Level 1 - wholesome pub vibes
        .init(text: "Order a drink you've never tried", level: 1),
        .init(text: "Take a photo of everyone's drinks", level: 1),
        .init(text: "Cheers with someone outside your group", level: 1),
        .init(text: "Compliment the bartender", level: 1),
        .init(text: "Spot a dog in or near the pub", level: 1),
        .init(text: "Learn the bartender's name", level: 1),
        .init(text: "Spot something vintage on the wall", level: 1),
        .init(text: "Find a pub quiz flyer or chalkboard", level: 1),
        .init(text: "Someone in the group spills a drink", level: 1),
        .init(text: "Group selfie at the bar", level: 1),
        .init(text: "Order food at the bar", level: 1),
        .init(text: "Sit in the beer garden", level: 1),
        .init(text: "Find a board game in the pub", level: 1),
        .init(text: "Spot a TV showing sports", level: 1),
        .init(text: "Everyone orders a different drink", level: 1),
        .init(text: "Find a jukebox or music selector", level: 1),
        .init(text: "Try a drink from the tap", level: 1),
        // Level 2 - social / interactive
        .init(text: "Ask the bartender for their recommendation and order it", level: 2),
        .init(text: "Swap drinks with someone in the group", level: 2),
        .init(text: "Order the weirdest thing on the menu", level: 2),
        .init(text: "Ask someone outside your group to take a photo of you all", level: 2),
        .init(text: "Challenge someone in the group to a thumb war", level: 2),
        .init(text: "Find someone wearing the same colour as you", level: 2),
        .init(text: "Spot someone on a date", level: 2),
        .init(text: "Say cheers in a language nobody in the group speaks", level: 2),
        .init(text: "Drink a full glass of water between rounds", level: 2),
        .init(text: "Swap seats with someone in the group", level: 2),
        .init(text: "Try a cocktail nobody has heard of", level: 2),
        .init(text: "Find the most expensive drink on the menu", level: 2),
        .init(text: "Someone tells a story that makes the whole group laugh", level: 2),
        .init(text: "Take a photo with something weird in the pub", level: 2),
        .init(text: "Someone in the group does a toast", level: 2),
        // Level 3 - more adventurous
        .init(text: "Make a new friend at the pub (genuine convo, not forced)", level: 3),
        .init(text: "Arm wrestle someone in the group", level: 3),
        .init(text: "Do karaoke or sing along to a song out loud", level: 3),
        .init(text: "Have a dance even if there's no dance floor", level: 3),
        .init(text: "Ask the bartender to surprise you with a drink", level: 3),
        .init(text: "Someone in the group tells a secret they've never told", level: 3),
        .init(text: "Get a round in for the squad", level: 3),
        .init(text: "Find out a fun fact about the pub you're in", level: 3),
        .init(text: "Everyone does a shot at the same time", level: 3),
        .init(text: "Tell the bartender a joke", level: 3),
        .init(text: "Someone in the group impersonates another group member", level: 3),
        .init(text: "Play a pub game (darts, pool, cards, anything)", level: 3),
        .init(text: "Someone changes their drink order last second", level: 3),
        .init(text: "Send a selfie from the pub to someone who couldn't make it", level: 3),
        .init(text: "Find out what the bartender's favourite drink is", level: 3),
        // Level 4 - bold moves (fun, not annoying)
        .init(text: "Wingman for a friend (help start a genuine convo)", level: 4),
        .init(text: "Two people in the group swap an item of clothing", level: 4),
        .init(text: "Everyone shares their most embarrassing story", level: 4),
        .init(text: "Order a drink in a fake accent", level: 4),
        .init(text: "Someone in the group does their best dance move", level: 4),
        .init(text: "Convince the bartender to make an off-menu creation", level: 4),
        .init(text: "Someone gives a heartfelt toast about a friend in the group", level: 4),
        .init(text: "Play a round of your spiciest game from the app", level: 4),
        .init(text: "Everyone guesses the price of a random cocktail before checking", level: 4),
        .init(text: "Do a blind taste test (someone orders for you, you guess what it is)", level: 4),
        .init(text: "Someone admits who they fancy", level: 4),
        .init(text: "Share your most unpopular opinion with the group", level: 4),
        .init(text: "Video-call someone who isn't there and show them the vibe", level: 4),
        .init(text: "Rate every pub you've been to tonight out of 10", level: 4),
        .init(text: "Someone reveals the last lie they told", level: 4),
        // Level 5 - send it (still fun, not dangerous)
        .init(text: "Whole group learns and performs a TikTok dance", level: 5),
        .init(text: "Someone does a dramatic reading of their last text conversation", level: 5),
        .init(text: "Everyone shares one thing they've never told the group", level: 5),
        .init(text: "Convince the bartender to let you pour your own pint", level: 5),
        .init(text: "Make someone in the group cry laughing", level: 5),
        .init(text: "Go to the next pub and order the exact same drink as your last one", level: 5),
        .init(text: "Everyone picks a different accent and orders in it", level: 5),
        .init(text: "Do a group conga line through the pub", level: 5),
        .init(text: "Someone freestyle raps about the night so far", level: 5),
        .init(text: "Play 'guess the song' - hum it, squad guesses", level: 5),
        .init(text: "Everyone writes a one-line review of the pub on a napkin", level: 5),
        .init(text: "Someone tells the group something they've been wanting to say all night", level: 5),
        .init(text: "Entire group takes a photo recreating a famous album cover", level: 5),
        .init(text: "Start a genuine deep chat with someone in the group you usually don't", level: 5),
        .init(text: "Share your screen time report with the group", level: 5),
    ]

    private func generateBingoCard() {
        let spiciness = store.data.preferences.spiciness
        let pool = Self.bingoChallenges.filter { $0.level <= spiciness }.map(\.text)
        // Deterministic shuffle when in a room so everyone gets the same card.
        // Uses room code + a generation counter as the seed.
        let seed: UInt64
        if let code = store.data.room?.code {
            let codeHash = code.unicodeScalars.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1.value) }
            seed = codeHash &+ UInt64(bingoSeed)
        } else {
            seed = UInt64(arc4random())
        }
        var rng = SeededRNG(seed: seed)
        let shuffled = pool.shuffled(using: &rng)
        let selected = Array(shuffled.prefix(25))
        var card: [BingoSquare] = []
        for i in 0..<25 {
            let text = i < selected.count ? selected[i] : "Wildcard: make one up!"
            card.append(BingoSquare(id: i, challenge: text, completed: false))
        }
        bingoCard = card
        bingoSeed += 1
        bingoLines = []
        fullHouse = false
        showBingoCelebration = false
    }

    private func toggleSquare(_ index: Int) {
        bingoCard[index].completed.toggle()
        checkBingo()
    }

    private func checkBingo() {
        var newLines: Set<Int> = []
        // Rows (line indices 0-4)
        for row in 0..<5 {
            let start = row * 5
            if (start..<start+5).allSatisfy({ bingoCard[$0].completed }) {
                newLines.insert(row)
            }
        }
        // Columns (line indices 5-9)
        for col in 0..<5 {
            if stride(from: col, to: 25, by: 5).allSatisfy({ bingoCard[$0].completed }) {
                newLines.insert(5 + col)
            }
        }
        // Diagonal top-left to bottom-right (line index 10)
        if stride(from: 0, to: 25, by: 6).allSatisfy({ bingoCard[$0].completed }) {
            newLines.insert(10)
        }
        // Diagonal top-right to bottom-left (line index 11)
        if stride(from: 4, through: 20, by: 4).allSatisfy({ bingoCard[$0].completed }) {
            newLines.insert(11)
        }
        // Detect new bingo
        let newBingos = newLines.subtracting(bingoLines)
        bingoLines = newLines

        // Full house
        let isFullHouse = bingoCard.allSatisfy(\.completed)
        if isFullHouse { fullHouse = true }

        if !newBingos.isEmpty || (isFullHouse && !showBingoCelebration) {
            withAnimation(.easeOut(duration: 0.35)) {
                showBingoCelebration = true
            }
        }
    }

    private func lineContains(square index: Int) -> Bool {
        let row = index / 5
        let col = index % 5
        if bingoLines.contains(row) { return true }        // row
        if bingoLines.contains(5 + col) { return true }    // column
        if row == col && bingoLines.contains(10) { return true }  // main diagonal
        if row + col == 4 && bingoLines.contains(11) { return true }  // anti diagonal
        return false
    }

    // MARK: Bingo Card UI

    private var pubBingoSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                if bingoCard.isEmpty {
                    bingoSetupView
                } else {
                    bingoGameView
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
    }

    private var bingoSetupView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // How to play
            VStack(alignment: .leading, spacing: 6) {
                Text("Pub Bingo").font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
                Text("A 5x5 card of pub challenges. Tap a square when you complete it. Get five in a row \u{2014} horizontal, vertical, or diagonal \u{2014} and shout BINGO! Complete the full card for a legendary night.")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Spiciness reminder
            let level = store.data.preferences.spiciness
            let emoji = ["", "🍼", "🙂", "😏", "🌶", "🔥"][min(5, max(1, level))]
            HStack(spacing: 8) {
                Text(emoji).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spiciness: \(level)/5").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("Challenges adapt to your spiciness level from Settings.")
                        .font(.caption2).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.3), lineWidth: 1))

            // Room info
            if inRoom {
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill").foregroundStyle(Theme.accentDeep).font(.caption)
                    Text("Everyone in the room gets the same card. Race to bingo!")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentDeep.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accentDeep.opacity(0.25), lineWidth: 1))
            }

            Button {
                generateBingoCard()
            } label: {
                Label("Deal a new card", systemImage: "rectangle.grid.3x2.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
    }

    private var bingoGameView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pub Bingo").font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
                    let completed = bingoCard.filter(\.completed).count
                    Text("\(completed)/25 completed \u{00B7} \(bingoLines.count) line\(bingoLines.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Button {
                    generateBingoCard()
                } label: {
                    Label("New card", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accentDeep.opacity(0.12)))
                }
                .buttonStyle(BeerifyPressStyle())
            }

            // BINGO header letters
            HStack(spacing: 0) {
                ForEach(["B", "I", "N", "G", "O"], id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.accentDeep)
                        .frame(maxWidth: .infinity)
                }
            }

            // 5x5 grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<25, id: \.self) { i in
                    bingoSquareView(index: i)
                }
            }

            // Progress bar
            let progress = Double(bingoCard.filter(\.completed).count) / 25.0
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.surface)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fullHouse ? Theme.success : (bingoLines.isEmpty ? Theme.accent : Theme.accentDeep))
                            .frame(width: geo.size.width * progress, height: 8)
                            .animation(.spring(response: 0.4), value: progress)
                    }
                }
                .frame(height: 8)
                HStack {
                    Text(fullHouse ? "FULL HOUSE!" : bingoLines.isEmpty ? "Get five in a row..." : "BINGO! Keep going for full house!")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(fullHouse ? Theme.success : (bingoLines.isEmpty ? Theme.inkSoft : Theme.accentDeep))
                    Spacer()
                }
            }
            .padding(.top, 4)
        }
    }

    private func bingoSquareView(index: Int) -> some View {
        let square = bingoCard[index]
        let isInBingoLine = lineContains(square: index)

        return Button {
            toggleSquare(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isInBingoLine ? Theme.success : (square.completed ? Theme.accentDeep : Theme.surface.opacity(0.95)))
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isInBingoLine ? Theme.success.opacity(0.8) : (square.completed ? Theme.accentDeep.opacity(0.6) : Theme.hairline),
                            lineWidth: isInBingoLine ? 2 : 1)
                Text(square.challenge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(square.completed ? .white : Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .padding(3)
                if square.completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(BeerifyPressStyle())
        .animation(.easeInOut(duration: 0.2), value: square.completed)
        .animation(.easeInOut(duration: 0.3), value: isInBingoLine)
    }

    // MARK: Bingo Celebration (confetti overlay)

    private var bingoCelebrationOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showBingoCelebration = false
                    }
                }

            // Confetti particles
            BingoConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Content card
            VStack(spacing: 20) {
                Text(fullHouse ? "🏆" : "🎉")
                    .font(.system(size: 72))

                Text(fullHouse ? "FULL HOUSE!" : "BINGO!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Text(fullHouse
                     ? "Every single square. Legendary."
                     : "Five in a row! Keep going for full house.")
                    .font(.callout)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)

                Button {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showBingoCelebration = false
                    }
                } label: {
                    Text(fullHouse ? "Take a bow" : "Keep playing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(fullHouse ? Theme.success : Theme.accent)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.horizontal, 32)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    // MARK: Route Calculation

    /// The active list of pubs for routing - crawl route or golf holes
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
        // All retries failed - fall back to straight line
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

    /// Reorder golf holes for the shortest walking route, preserving
    /// each hole's drink and par assignment, then recalculate directions.
    private func optimiseAndRouteGolfHoles() async {
        guard golfHoles.count >= 2 else {
            walkingRoutes = []
            return
        }
        if golfHoles.count >= 3 {
            let start = locationManager.userLocation?.coordinate ?? searchCenter
            let pubOrder: [Pub]
            if golfHoles.count <= 14 {
                pubOrder = heldKarp(pubs: golfHoles.map(\.pub), start: start)
            } else {
                pubOrder = heuristicOptimise(pubs: golfHoles.map(\.pub), start: start)
            }
            var holesByPub: [String: PubGolfHole] = [:]
            for hole in golfHoles { holesByPub[hole.pub.id] = hole }
            golfHoles = pubOrder.compactMap { holesByPub[$0.id] }
        }
        await recalculateWalkingRoutes(for: golfHoles.map(\.pub))
    }

    /// Broadcast the current sip count for a hole to room peers.
    private func broadcastGolfScore(holeIndex: Int) {
        guard inRoom, let strokes = golfHoles[holeIndex].strokes else { return }
        let holeId = golfHoles[holeIndex].id.uuidString
        // Find the furthest hole with a score to report current position
        let currentIdx = golfHoles.lastIndex(where: { $0.strokes != nil }) ?? holeIndex
        roomService.pubGolfUpdateScore(holeId: holeId, strokes: strokes, currentHoleIndex: currentIdx)
    }
}

// MARK: - Confetti

private struct ConfettiPiece: View {
    let color: Color
    let startX: CGFloat   // 0...1 fraction of screen width
    let delay: Double
    let duration: Double
    let spinSpeed: Double
    let size: CGFloat
    let shape: Int        // 0 = rectangle, 1 = circle, 2 = triangle-ish

    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            confettiShape
                .frame(width: size, height: size * 0.6)
                .foregroundStyle(color)
                .rotationEffect(.degrees(fallen ? spinSpeed * 360 : 0))
                .position(
                    x: startX * w + (fallen ? CGFloat.random(in: -30...30) : 0),
                    y: fallen ? h + 40 : -20
                )
                .animation(
                    .easeIn(duration: duration).delay(delay),
                    value: fallen
                )
                .onAppear { fallen = true }
        }
    }

    @ViewBuilder
    private var confettiShape: some View {
        switch shape % 3 {
        case 0: Rectangle()
        case 1: Circle()
        default: Ellipse()
        }
    }
}

private struct BingoConfettiView: View {
    private static let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .mint, .cyan, .indigo
    ]

    private let pieces: [ConfettiPieceData] = (0..<50).map { i in
        ConfettiPieceData(
            color: colors[i % colors.count],
            startX: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...0.8),
            duration: Double.random(in: 1.5...3.5),
            spinSpeed: Double.random(in: 1...4),
            size: CGFloat.random(in: 8...14),
            shape: Int.random(in: 0...2)
        )
    }

    struct ConfettiPieceData: Identifiable {
        let id = UUID()
        let color: Color
        let startX: CGFloat
        let delay: Double
        let duration: Double
        let spinSpeed: Double
        let size: CGFloat
        let shape: Int
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                ConfettiPiece(
                    color: p.color,
                    startX: p.startX,
                    delay: p.delay,
                    duration: p.duration,
                    spinSpeed: p.spinSpeed,
                    size: p.size,
                    shape: p.shape
                )
            }
        }
    }
}
