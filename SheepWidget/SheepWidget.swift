import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SheepEntry: TimelineEntry {
    let date: Date
    let sheepCount: Int
}

struct SheepProvider: TimelineProvider {
    func placeholder(in context: Context) -> SheepEntry {
        SheepEntry(date: .now, sheepCount: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (SheepEntry) -> Void) {
        completion(SheepEntry(date: .now, sheepCount: 1))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SheepEntry>) -> Void) {
        // Refresh once per minute to update the sheep count; animation is driven by PhaseAnimator
        var entries: [SheepEntry] = []
        let now = Date.now
        for offset in 0..<60 {
            entries.append(SheepEntry(
                date: now.addingTimeInterval(Double(offset) * 60),
                sheepCount: offset + 1
            ))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Animation phases

enum SheepPhase: CaseIterable {
    case offscreenLeft   // sheep enters from left
    case approaching     // walking toward fence
    case launching       // crouch/prepare
    case apex            // top of jump arc
    case landing         // touch down on right
    case walkingAway     // strolling right
    case offscreenRight  // exits right
}

// MARK: - Sheep drawing

struct SheepShape: View {
    let flipped: Bool

    var body: some View {
        // Simple sheep built from SwiftUI shapes
        ZStack {
            // Body (fluffy wool ellipse)
            Ellipse()
                .fill(.white)
                .frame(width: 36, height: 26)
                .overlay(
                    Ellipse()
                        .fill(.white.opacity(0.6))
                        .frame(width: 28, height: 20)
                        .offset(y: -2)
                )

            // Head
            Circle()
                .fill(Color(white: 0.25))
                .frame(width: 14, height: 14)
                .offset(x: flipped ? -20 : 20, y: -6)

            // Ear
            Ellipse()
                .fill(Color(white: 0.25))
                .frame(width: 6, height: 9)
                .offset(x: flipped ? -24 : 24, y: -12)

            // Eye
            Circle()
                .fill(.white)
                .frame(width: 3, height: 3)
                .offset(x: flipped ? -22 : 22, y: -8)

            // Legs (4 little rectangles)
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.25))
                        .frame(width: 5, height: 12)
                }
            }
            .offset(y: 16)
        }
    }
}

// MARK: - Fence

struct FenceView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Two fence posts with a rail
            ZStack(alignment: .bottom) {
                // Rail (horizontal bar)
                Rectangle()
                    .fill(Color(red: 0.6, green: 0.4, blue: 0.2))
                    .frame(width: 44, height: 6)
                    .offset(y: -22)

                // Left post
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.55, green: 0.35, blue: 0.15))
                    .frame(width: 8, height: 50)
                    .offset(x: -18)

                // Right post
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.55, green: 0.35, blue: 0.15))
                    .frame(width: 8, height: 50)
                    .offset(x: 18)
            }
        }
    }
}

// MARK: - Night sky background

struct NightSkyView: View {
    var body: some View {
        ZStack {
            // Sky gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.18),
                    Color(red: 0.08, green: 0.08, blue: 0.28),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Stars
            ForEach(starPositions, id: \.0) { (x, y, size) in
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: size, height: size)
                    .position(x: x, y: y)
            }

            // Moon
            Circle()
                .fill(Color(red: 1.0, green: 0.97, blue: 0.85))
                .frame(width: 38, height: 38)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.07, green: 0.07, blue: 0.22))
                        .frame(width: 32, height: 32)
                        .offset(x: 10, y: -6)
                )
                .position(x: 270, y: 42)

            // Ground
            Rectangle()
                .fill(Color(red: 0.13, green: 0.22, blue: 0.13))
                .frame(height: 30)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var starPositions: [(CGFloat, CGFloat, CGFloat)] {
        [
            (20, 18, 2), (55, 10, 1.5), (90, 22, 2.5), (130, 8, 1.5),
            (160, 28, 2), (200, 14, 1), (230, 20, 2.5), (48, 35, 1.5),
            (110, 40, 1), (175, 38, 2), (245, 32, 1.5), (75, 55, 1),
            (140, 50, 2), (210, 48, 1.5), (260, 55, 2), (30, 60, 1),
        ]
    }
}

// MARK: - Main scene

struct SheepScene: View {
    let sheepCount: Int

    // Geometry constants
    private let fenceX: CGFloat = 152   // horizontal centre of fence
    private let groundY: CGFloat = 116  // y where sheep stands on ground
    private let jumpPeakY: CGFloat = 52 // y at top of arc

    var body: some View {
        ZStack {
            NightSkyView()

            // Fence, centred
            FenceView()
                .position(x: fenceX, y: groundY + 2)

            // Animated sheep
            PhaseAnimator(SheepPhase.allCases) { phase in
                SheepShape(flipped: phase == .offscreenLeft || phase == .approaching || phase == .launching)
                    .scaleEffect(scale(for: phase))
                    .rotationEffect(rotation(for: phase))
                    .position(x: sheepX(for: phase), y: sheepY(for: phase))
            } animation: { phase in
                switch phase {
                case .offscreenLeft:  .linear(duration: 0.1)
                case .approaching:    .easeInOut(duration: 1.0)
                case .launching:      .easeIn(duration: 0.25)
                case .apex:           .easeOut(duration: 0.35)
                case .landing:        .spring(duration: 0.3, bounce: 0.35)
                case .walkingAway:    .easeInOut(duration: 1.0)
                case .offscreenRight: .linear(duration: 0.1)
                }
            }

            // Sheep counter
            HStack(spacing: 4) {
                Text("\(sheepCount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text("sheep")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.7))
            .position(x: fenceX, y: 148)
        }
    }

    private func sheepX(for phase: SheepPhase) -> CGFloat {
        switch phase {
        case .offscreenLeft:  return -30
        case .approaching:    return fenceX - 55
        case .launching:      return fenceX - 38
        case .apex:           return fenceX
        case .landing:        return fenceX + 38
        case .walkingAway:    return fenceX + 80
        case .offscreenRight: return 340
        }
    }

    private func sheepY(for phase: SheepPhase) -> CGFloat {
        switch phase {
        case .offscreenLeft:  return groundY
        case .approaching:    return groundY
        case .launching:      return groundY + 4   // slight crouch
        case .apex:           return jumpPeakY
        case .landing:        return groundY + 2
        case .walkingAway:    return groundY
        case .offscreenRight: return groundY
        }
    }

    private func rotation(for phase: SheepPhase) -> Angle {
        switch phase {
        case .launching:      return .degrees(-12)
        case .apex:           return .degrees(-8)
        case .landing:        return .degrees(8)
        default:              return .degrees(0)
        }
    }

    private func scale(for phase: SheepPhase) -> CGFloat {
        switch phase {
        case .launching: return 0.9
        case .apex:      return 1.05
        default:         return 1.0
        }
    }
}

// MARK: - Widget view

struct SheepWidgetView: View {
    let entry: SheepEntry

    var body: some View {
        SheepScene(sheepCount: entry.sheepCount)
            .ignoresSafeArea()
    }
}

// MARK: - Widget configuration

struct SheepWidgetBundle: WidgetBundle {
    var body: some Widget {
        SheepWidgetMain()
    }
}

struct SheepWidgetMain: Widget {
    let kind = "SheepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SheepProvider()) { entry in
            SheepWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Counting Sheep")
        .description("Watch sheep jump over the fence as you drift off.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
