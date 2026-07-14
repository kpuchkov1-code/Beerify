//
//  BeerMeterView.swift
//  Beerify
//
//  Animated beer mug that fills with your estimated BAC. Redesigned to look
//  like a proper beer stein — chunky proportions, filled D-ring handle, a
//  visible rim opening, thick foam head, and a contact shadow so it sits on
//  the surface instead of floating.
//

import SwiftUI

// Design coordinates — deliberately mug-shaped (roughly 1:1.3 body).
private let ART_WIDTH: CGFloat = 210
private let ART_HEIGHT: CGFloat = 220

private let GLASS_LEFT: CGFloat = 22
private let GLASS_RIGHT: CGFloat = 138
private let GLASS_TOP: CGFloat = 30
private let GLASS_BOTTOM: CGFloat = 194
private let GLASS_CORNER: CGFloat = 28
private let CENTER_X: CGFloat = (GLASS_LEFT + GLASS_RIGHT) / 2   // = 80

private let LIQUID_TOP: CGFloat = 38
private let LIQUID_BOTTOM: CGFloat = 191
private let LIQUID_HEIGHT: CGFloat = LIQUID_BOTTOM - LIQUID_TOP - 6

private let GAUGE_MAX: Double = 0.14

private let STATUS_LABELS: [ZoneStatus: String] = [
    .sober: "Sober", .warming: "Warming up", .inZone: "In your zone!",
    .over: "Over your zone", .wayOver: "Too far. Stop",
]
private let STATUS_EMOJI: [ZoneStatus: String] = [
    .sober: "🧊", .warming: "🔥", .inZone: "🎯", .over: "🫗", .wayOver: "🛑",
]

private func levelY(for bac: Double) -> CGFloat {
    let frac = min(bac / GAUGE_MAX, 1)
    return LIQUID_BOTTOM - CGFloat(frac) * LIQUID_HEIGHT
}

private func statusColor(_ status: ZoneStatus) -> Color {
    switch status {
    case .sober: return Theme.inkSoft
    case .warming: return Theme.accentDeep
    case .inZone: return Theme.success
    case .over: return Theme.warning
    case .wayOver: return Theme.danger
    }
}

// MARK: - Public view

struct BeerMeterView: View {
    let bac: Double
    let incoming: Double
    let target: Target
    let status: ZoneStatus

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { geo in
                let scale = min(geo.size.width / ART_WIDTH, geo.size.height / ART_HEIGHT)
                ZStack {
                    // Ambient halo behind the mug tinted by current zone
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [statusColor(status).opacity(0.35), statusColor(status).opacity(0)],
                                center: .center, startRadius: 10, endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 22)
                        .scaleEffect(status == .inZone ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                                   value: status == .inZone)

                    MugArt(bac: bac, incoming: incoming, target: target, status: status)
                        .frame(width: ART_WIDTH, height: ART_HEIGHT)
                        .scaleEffect(scale)
                        .frame(width: ART_WIDTH * scale, height: ART_HEIGHT * scale)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 280)
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: status)

            info
        }
    }

    private var info: some View {
        VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(BAC.format(bac))
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: bac)
                Text("est. BAC %")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }

            HStack(spacing: 6) {
                Text(STATUS_EMOJI[status] ?? "")
                Text(STATUS_LABELS[status] ?? "")
            }
            .font(.callout.weight(.bold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(statusColor(status).opacity(0.14)))
            .overlay(Capsule().stroke(statusColor(status).opacity(0.5), lineWidth: 1))
            .shadow(color: statusColor(status).opacity(0.25), radius: 8, y: 3)
            .id(status)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.45, dampingFraction: 0.68), value: status)

            if incoming - bac > 0.003 {
                HStack(spacing: 6) {
                    Circle().fill(Theme.accent.opacity(0.85)).frame(width: 8, height: 8)
                    Text("more still kicking in")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Mug art

private struct MugArt: View {
    let bac: Double
    let incoming: Double
    let target: Target
    let status: ZoneStatus

    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                // Soft contact shadow beneath the mug
                Ellipse()
                    .fill(Color.black.opacity(0.24))
                    .frame(width: 138, height: 14)
                    .blur(radius: 6)
                    .offset(x: 4)
                    .position(x: CENTER_X + 4, y: GLASS_BOTTOM + 12)

                // === Chunky filled handle rendered behind the mug body ===
                // Outer dark silhouette
                Handle().stroke(Color(white: 0.28),
                                style: StrokeStyle(lineWidth: 28, lineCap: .round))
                // Glass fill of the handle (gradient across its width)
                Handle().stroke(
                    LinearGradient(
                        colors: [
                            Color(white: 0.68),
                            Color(white: 0.94),
                            Color(white: 0.82),
                            Color(white: 0.56),
                        ],
                        startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 23, lineCap: .round))
                // Inner bright highlight strip (light catching the inner curve)
                Handle().stroke(Color.white.opacity(0.90),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .offset(x: -5)
                // Outer edge shadow
                Handle().stroke(Color.black.opacity(0.22),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .offset(x: 7)

                // === Glass body base ===
                MugBody()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.96, blue: 0.99),
                            Color(red: 0.86, green: 0.90, blue: 0.94),
                            Color(red: 0.94, green: 0.96, blue: 0.99),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing))

                // Everything liquid-side clipped to the mug interior
                ZStack {
                    // Interior depth gradient: darker at top (looking into
                    // an empty mug, the back wall shows as a soft shadow),
                    // warmer toward the middle where beer sits.
                    Rectangle().fill(LinearGradient(
                        colors: [
                            Color(red: 0.32, green: 0.22, blue: 0.10).opacity(0.35),
                            Color(red: 0.75, green: 0.55, blue: 0.25).opacity(0.18),
                            Color(red: 1.00, green: 0.90, blue: 0.65).opacity(0.20),
                        ],
                        startPoint: .top, endPoint: .bottom))

                    // Subtle inner wall shading — glass has thickness, so the
                    // left and right edges catch a bit more shadow.
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.black.opacity(0.18), Color.clear],
                            startPoint: .leading, endPoint: .trailing)
                            .frame(width: 12)
                        Spacer()
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.20)],
                            startPoint: .leading, endPoint: .trailing)
                            .frame(width: 14)
                    }

                    IncomingBand(bac: bac, incoming: incoming)
                    ZoneBand(target: target, status: status)
                    LiquidLayer(bac: bac, phase: phase)
                    Shine()
                }
                .clipShape(MugBody())

                // === Rim depth cue — inner curve that dips down at center,
                // reading as the near lip of the opening (3D hint). ===
                Path { p in
                    p.move(to: CGPoint(x: GLASS_LEFT + 4, y: GLASS_TOP + 5))
                    p.addQuadCurve(
                        to: CGPoint(x: GLASS_RIGHT - 4, y: GLASS_TOP + 5),
                        control: CGPoint(x: CENTER_X, y: GLASS_TOP + 18))
                }
                .stroke(Color(white: 0.20).opacity(0.75), lineWidth: 2.2)

                // Bright rim highlight just below the top edge — a shine that
                // catches light along the near lip.
                Path { p in
                    p.move(to: CGPoint(x: GLASS_LEFT + 10, y: GLASS_TOP + 2))
                    p.addQuadCurve(
                        to: CGPoint(x: GLASS_RIGHT - 10, y: GLASS_TOP + 2),
                        control: CGPoint(x: CENTER_X, y: GLASS_TOP + 5))
                }
                .stroke(Color.white.opacity(0.80), lineWidth: 1.6)

                ZonePill(target: target, status: status)

                // Crisp outline on top
                MugBody().stroke(Color(white: 0.26), lineWidth: 2.6)

                if bac < 0.001 && incoming < 0.001 {
                    Text("🌵")
                        .font(.system(size: 36))
                        .position(x: CENTER_X, y: 168)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Shapes

private struct MugBody: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Straight top with rounded bottom — classic mug silhouette.
        p.move(to: CGPoint(x: GLASS_LEFT, y: GLASS_TOP))
        p.addLine(to: CGPoint(x: GLASS_RIGHT, y: GLASS_TOP))
        p.addLine(to: CGPoint(x: GLASS_RIGHT, y: GLASS_BOTTOM - GLASS_CORNER))
        p.addArc(
            center: CGPoint(x: GLASS_RIGHT - GLASS_CORNER, y: GLASS_BOTTOM - GLASS_CORNER),
            radius: GLASS_CORNER,
            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: GLASS_LEFT + GLASS_CORNER, y: GLASS_BOTTOM))
        p.addArc(
            center: CGPoint(x: GLASS_LEFT + GLASS_CORNER, y: GLASS_BOTTOM - GLASS_CORNER),
            radius: GLASS_CORNER,
            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Handle centerline: a cubic curve arcing outward from the right side of
/// the mug body. Stroked thick to become a chunky D-ring.
private struct Handle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: GLASS_RIGHT - 2, y: 82))
        p.addCurve(
            to: CGPoint(x: GLASS_RIGHT - 2, y: 152),
            control1: CGPoint(x: GLASS_RIGHT + 62, y: 78),
            control2: CGPoint(x: GLASS_RIGHT + 62, y: 156))
        return p
    }
}

// MARK: - Liquid

private struct LiquidLayer: View {
    let bac: Double
    let phase: Double

    var body: some View {
        let surface = levelY(for: bac)
        let hasBeer = bac > 0.001

        ZStack {
            // Deep amber body — richer beer color with proper depth
            WaveShape(phase: phase * 0.9, amplitude: 3.5, wavelength: 48, baseline: surface)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.78, blue: 0.30),
                        Color(red: 0.98, green: 0.58, blue: 0.08),
                        Color(red: 0.78, green: 0.36, blue: 0.02),
                        Color(red: 0.55, green: 0.24, blue: 0.02),
                    ],
                    startPoint: .top, endPoint: .bottom))

            // Bright overlay wave, phase-offset for a lively surface
            WaveShape(phase: phase * 1.35 + 1.2, amplitude: 4, wavelength: 62, baseline: surface + 2)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.85, blue: 0.40).opacity(0.85),
                        Color(red: 1.0, green: 0.62, blue: 0.12).opacity(0.55),
                    ],
                    startPoint: .top, endPoint: .bottom))

            // Thin shimmer band at the very top of the liquid
            WaveShape(phase: phase * 2.1 + 0.8, amplitude: 1.6, wavelength: 36,
                      baseline: surface + 0.5, thickness: 2.0)
                .fill(Color.white.opacity(0.5))
                .blendMode(.screen)

            // Foam head — a thick, dense white band above the surface
            WaveShape(phase: phase * 0.7 + 0.5, amplitude: 4, wavelength: 54,
                      baseline: surface - 9, thickness: 14)
                .fill(LinearGradient(
                    colors: [
                        Color.white,
                        Color(red: 0.99, green: 0.97, blue: 0.90),
                        Color(white: 0.90),
                    ],
                    startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.black.opacity(0.10), radius: 1.5, y: 1)

            // Foam bubbles for texture
            FoamSpeckle(surface: surface, phase: phase)

            // Rising bubbles inside the beer
            Bubbles(surface: surface, phase: phase)
        }
        .opacity(hasBeer ? 1 : 0)
        .animation(.easeInOut(duration: 0.55), value: bac)
    }
}

/// Filled area from a sinusoidal top down to the bottom of the interior.
private struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var wavelength: CGFloat
    var baseline: CGFloat
    var thickness: CGFloat? = nil

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let left = GLASS_LEFT
        let right = GLASS_RIGHT
        let step: CGFloat = 2
        var x = left
        p.move(to: CGPoint(x: x, y: y(at: x)))
        while x <= right {
            x += step
            p.addLine(to: CGPoint(x: x, y: y(at: x)))
        }
        if let thickness {
            var xr = right
            while xr >= left {
                p.addLine(to: CGPoint(x: xr, y: y(at: xr) + thickness))
                xr -= step
            }
        } else {
            p.addLine(to: CGPoint(x: right, y: LIQUID_BOTTOM + 6))
            p.addLine(to: CGPoint(x: left, y: LIQUID_BOTTOM + 6))
        }
        p.closeSubpath()
        return p
    }

    private func y(at x: CGFloat) -> CGFloat {
        let k = (2 * .pi) / wavelength
        // Blend two sines so the surface isn't uniform.
        let s1 = sin(Double(x) * Double(k) + phase)
        let s2 = sin(Double(x) * Double(k) * 1.7 + phase * 1.3) * 0.35
        return baseline + CGFloat(s1 + s2) * amplitude
    }
}

private struct Bubbles: View {
    let surface: CGFloat
    let phase: Double

    private struct Spec {
        let cx: CGFloat
        let r: CGFloat
        let depth: CGFloat
        let speed: Double
        let offset: Double
        let wobbleAmp: CGFloat
        let wobbleFreq: Double
    }

    // Distributed across the wider interior (x=22 to x=138).
    private static let specs: [Spec] = [
        .init(cx: 34, r: 3.4, depth: 135, speed: 0.85, offset: 0.0, wobbleAmp: 2.2, wobbleFreq: 1.6),
        .init(cx: 46, r: 2.0, depth: 95,  speed: 1.45, offset: 1.4, wobbleAmp: 1.4, wobbleFreq: 2.3),
        .init(cx: 58, r: 3.1, depth: 120, speed: 0.80, offset: 2.6, wobbleAmp: 1.9, wobbleFreq: 1.5),
        .init(cx: 70, r: 2.3, depth: 145, speed: 1.05, offset: 0.7, wobbleAmp: 2.0, wobbleFreq: 1.9),
        .init(cx: 82, r: 3.2, depth: 110, speed: 1.20, offset: 2.1, wobbleAmp: 1.4, wobbleFreq: 2.1),
        .init(cx: 94, r: 1.8, depth: 85,  speed: 1.55, offset: 1.9, wobbleAmp: 1.0, wobbleFreq: 2.7),
        .init(cx: 106, r: 2.7, depth: 125, speed: 0.95, offset: 0.4, wobbleAmp: 2.0, wobbleFreq: 1.7),
        .init(cx: 120, r: 2.0, depth: 92,  speed: 1.35, offset: 2.9, wobbleAmp: 1.5, wobbleFreq: 2.4),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<Self.specs.count, id: \.self) { i in
                let s = Self.specs[i]
                let cycle: Double = 3.5
                let t = (phase * s.speed + s.offset).truncatingRemainder(dividingBy: cycle)
                let progress = t / cycle
                let y = LIQUID_BOTTOM - CGFloat(progress) * s.depth
                let wobble = CGFloat(sin(phase * s.wobbleFreq + s.offset)) * s.wobbleAmp
                let cx = s.cx + wobble
                if y > surface + s.r {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.85 * (1 - progress)),
                                    Color.white.opacity(0.15 * (1 - progress)),
                                ],
                                center: .init(x: 0.35, y: 0.35),
                                startRadius: 0, endRadius: s.r
                            )
                        )
                        .frame(width: s.r * 2, height: s.r * 2)
                        .position(x: cx, y: y)
                }
            }
        }
    }
}

private struct FoamSpeckle: View {
    let surface: CGFloat
    let phase: Double

    // Foam texture dots — top layer and slightly deeper layer.
    private static let dots: [(x: CGFloat, dy: CGFloat, r: CGFloat)] = [
        (30, 0.5, 2.6), (40, -1.5, 1.8), (52, 0.0, 3.0), (64, -2.0, 1.9),
        (76, 0.5, 2.7), (88, -1.5, 1.7), (100, 0.0, 2.6), (112, -1.5, 2.0),
        (128, 0.5, 2.2),
        (36, -3.5, 1.5), (60, -4.5, 1.4), (82, -4.0, 1.6),
        (104, -3.5, 1.5), (122, -3.5, 1.4),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<Self.dots.count, id: \.self) { i in
                let d = Self.dots[i]
                let bob = CGFloat(sin(phase * 1.6 + Double(i) * 0.7)) * 0.9
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: d.r * 2, height: d.r * 2)
                    .position(x: d.x, y: surface - 8 + d.dy + bob)
            }
        }
    }
}

// MARK: - Zone band

private struct ZoneBand: View {
    let target: Target
    let status: ZoneStatus

    var body: some View {
        let top = levelY(for: target.maxBac)
        let bottom = levelY(for: target.minBac)
        let isHit = status == .inZone
        let baseTint: Color = isHit ? Theme.success : Theme.success.opacity(0.9)

        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    colors: [baseTint.opacity(0.35), baseTint.opacity(0.18), baseTint.opacity(0.35)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: GLASS_RIGHT - GLASS_LEFT, height: bottom - top)
                .position(x: CENTER_X, y: (top + bottom) / 2)

            Path { p in
                p.move(to: CGPoint(x: GLASS_LEFT, y: top))
                p.addLine(to: CGPoint(x: GLASS_RIGHT, y: top))
            }.stroke(baseTint.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            Path { p in
                p.move(to: CGPoint(x: GLASS_LEFT, y: bottom))
                p.addLine(to: CGPoint(x: GLASS_RIGHT, y: bottom))
            }.stroke(baseTint.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        }
        .animation(.easeInOut(duration: 0.4), value: status)
    }
}

private struct ZonePill: View {
    let target: Target
    let status: ZoneStatus

    var body: some View {
        let y = (levelY(for: target.maxBac) + levelY(for: target.minBac)) / 2
        let color: Color = status == .inZone ? Theme.success : Theme.ink.opacity(0.85)
        // Position the pill on the left inside edge so it doesn't fight
        // with the foam or beer wave at the surface.
        Text("\(target.emoji) zone")
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
            .shadow(color: color.opacity(0.5), radius: 5, y: 2)
            .rotationEffect(.degrees(-4))
            .position(x: GLASS_LEFT + 36, y: y)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: status)
    }
}

// MARK: - Incoming ghost band

private struct IncomingBand: View {
    let bac: Double
    let incoming: Double

    var body: some View {
        let surface = levelY(for: bac)
        let ghost = levelY(for: max(incoming, bac))
        if surface - ghost > 2 {
            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Theme.accent.opacity(0.10), Theme.accent.opacity(0.32)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: GLASS_RIGHT - GLASS_LEFT, height: surface - ghost)
                    .position(x: CENTER_X, y: (ghost + surface) / 2)
                Path { p in
                    p.move(to: CGPoint(x: GLASS_LEFT, y: ghost))
                    p.addLine(to: CGPoint(x: GLASS_RIGHT, y: ghost))
                }.stroke(Theme.accent.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            }
        }
    }
}

// MARK: - Shine

private struct Shine: View {
    var body: some View {
        ZStack {
            // Big frosted vertical shine near the left side of the glass
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.85), Color.white.opacity(0.30)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 10, height: 150)
                .position(x: GLASS_LEFT + 14, y: GLASS_TOP + 88)
                .blendMode(.screen)
            // Thinner secondary shine
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.35))
                .frame(width: 4, height: 150)
                .position(x: GLASS_LEFT + 28, y: GLASS_TOP + 88)
                .blendMode(.screen)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        BeerMeterView(
            bac: 0.05, incoming: 0.07,
            target: TargetsCatalog.target(.tipsy),
            status: .inZone
        )
    }
    .padding()
    .background(BeerifyBackground())
}
