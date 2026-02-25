import ScreenSaver
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – ScreenSaverView bridge
// ─────────────────────────────────────────────────────────────────────────────

@objc(CountingSheepSaver)
final class CountingSheepSaver: ScreenSaverView {

    private var host: NSHostingView<SheepScene>?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        boot()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); boot() }

    private func boot() {
        wantsLayer = true
        animationTimeInterval = 1 / 60.0
        let hv = NSHostingView(rootView: SheepScene())
        hv.frame = bounds
        hv.autoresizingMask = [.width, .height]
        addSubview(hv)
        host = hv
    }

    override func animateOneFrame() {}
    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Constants
// ─────────────────────────────────────────────────────────────────────────────

private let CYCLE     = 4.5   // seconds per sheep crossing
private let FLIP_PROB = 0.05

private let starData: [(Double,Double,Double,Double,Double)] = [
    (8,12,1.25,2.1,0),    (15,28,0.75,3.2,0.4), (22,8,1,2.8,0.8),   (31,18,0.75,4.1,0.2),
    (40,35,1.25,2.3,1.1), (48,10,0.75,3.7,0.5), (57,22,1,2.6,1.4),  (64,40,0.5,3.4,0.9),
    (73,14,1.25,2.9,0.3), (80,30,1,4.2,1.7),    (88,7,0.75,3.1,0.6),(93,24,1,2.4,1.2),
    (12,55,0.75,3.8,0.7), (25,48,1,2.7,1.5),    (37,60,0.5,4.0,0.1),(52,52,1.25,3.3,1.8),
    (66,58,0.75,2.2,0.9), (78,45,1,3.6,0.4),    (85,62,0.5,4.3,1.3),(95,50,1,2.5,0.8),
    (5,42,0.75,3.9,1.6),  (18,68,1,2.8,0.2),    (44,70,0.75,3.5,1),(70,72,0.5,4.1,1.9),
    (90,68,1,2.3,0.5),
]

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Top-level scene (drives animation state)
// ─────────────────────────────────────────────────────────────────────────────

struct SheepScene: View {
    @State private var origin  = Date()
    @State private var jumpH: CGFloat = 80
    @State private var doFlip  = false
    @State private var count   = 0

    var body: some View {
        TimelineView(.animation) { tl in
            let elapsed  = tl.date.timeIntervalSince(origin)
            let cycleIdx = Int(elapsed / CYCLE)
            let progress = (elapsed / CYCLE).truncatingRemainder(dividingBy: 1)
            SceneView(progress: progress, elapsed: elapsed,
                      jumpH: jumpH, doFlip: doFlip, count: count)
                .onChange(of: cycleIdx) { _, _ in
                    count  += 1
                    jumpH   = .random(in: 55...120)
                    doFlip  = .random(in: 0...1) < FLIP_PROB
                }
        }
        .ignoresSafeArea()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Scene view (Canvas + text overlays)
// ─────────────────────────────────────────────────────────────────────────────

struct SceneView: View {
    let progress: Double
    let elapsed:  Double
    let jumpH:    CGFloat
    let doFlip:   Bool
    let count:    Int

    var body: some View {
        GeometryReader { geo in
            let sz      = geo.size
            let scale   = max(1, sz.height / 500)
            let groundY = sz.height * 0.78

            ZStack {
                Canvas { ctx, s in
                    drawSky(ctx, s)
                    drawStars(ctx, s)
                    drawMoon(ctx, s, scale: scale)
                    drawGround(ctx, s, groundY: groundY)
                    drawFence(ctx, s, groundY: groundY, scale: scale)
                    drawSheep(ctx, s, groundY: groundY, scale: scale)
                }
                .ignoresSafeArea()

                // Clock — centred
                let fs = min(96.0, max(36.0, sz.width * 0.065))
                VStack(spacing: 6) {
                    Text(hhmm())
                        .font(.system(size: fs, weight: .ultraLight))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(dateStr())
                        .font(.system(size: max(11, fs * 0.19)))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(2)
                        .textCase(.uppercase)
                }

                // Counter — above fence
                VStack {
                    Spacer()
                    Text("\(count) sheep")
                        .font(.system(size: max(11, sz.width * 0.013)))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(1)
                        .padding(.bottom, sz.height * 0.22 + 72 * scale)
                }
            }
            .background(Color(red: 0.039, green: 0.039, blue: 0.118))
        }
    }

    // ── Sky ──────────────────────────────────────────────────────────────────

    private func drawSky(_ ctx: GraphicsContext, _ sz: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red:0.027, green:0.027, blue:0.102), location:0),
                .init(color: Color(red:0.051, green:0.051, blue:0.180), location:0.6),
                .init(color: Color(red:0.067, green:0.102, blue:0.067), location:1),
            ]),
            startPoint: CGPoint(x: sz.width/2, y: 0),
            endPoint:   CGPoint(x: sz.width/2, y: sz.height)
        ))
    }

    // ── Stars ─────────────────────────────────────────────────────────────────

    private func drawStars(_ ctx: GraphicsContext, _ sz: CGSize) {
        let skyH = sz.height * 0.72
        for (xPct, yPct, r, period, phase) in starData {
            let a = 0.5 + 0.5 * sin((elapsed + phase) / period * .pi * 2)
            let opacity = 0.2 + 0.8 * a
            let cx = sz.width * xPct / 100
            let cy = skyH    * yPct / 100
            ctx.fill(Path(ellipseIn: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2)),
                     with: .color(.white.opacity(opacity)))
        }
    }

    // ── Moon ──────────────────────────────────────────────────────────────────

    private func drawMoon(_ ctx: GraphicsContext, _ sz: CGSize, scale: CGFloat) {
        let r  = 28 * scale
        // Disc top-left
        let dx = sz.width  * 0.92 - 2 * r
        let dy = sz.height * 0.08
        ctx.fill(Path(ellipseIn: CGRect(x: dx, y: dy, width: r*2, height: r*2)),
                 with: .color(Color(red:0.992, green:0.965, blue:0.847)))
        // Bite — sky-coloured circle offset up-right
        let br = r * 0.786
        ctx.fill(Path(ellipseIn: CGRect(x: dx + r*0.64, y: dy - r*0.21, width: br*2, height: br*2)),
                 with: .color(Color(red:0.051, green:0.051, blue:0.180)))
    }

    // ── Ground ────────────────────────────────────────────────────────────────

    private func drawGround(_ ctx: GraphicsContext, _ sz: CGSize, groundY: CGFloat) {
        ctx.fill(Path(CGRect(x:0, y:groundY, width:sz.width, height:sz.height-groundY)),
                 with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red:0.102, green:0.200, blue:0.094), location:0),
                        .init(color: Color(red:0.071, green:0.145, blue:0.063), location:1),
                    ]),
                    startPoint: CGPoint(x:0, y:groundY),
                    endPoint:   CGPoint(x:0, y:sz.height)
                 ))
        // Top edge strip
        ctx.fill(Path(CGRect(x:0, y:groundY-4, width:sz.width, height:8)),
                 with: .color(Color(red:0.165, green:0.290, blue:0.157)))
    }

    // ── Fence ─────────────────────────────────────────────────────────────────

    private func drawFence(_ ctx: GraphicsContext, _ sz: CGSize, groundY: CGFloat, scale: CGFloat) {
        let postW: CGFloat = 10 * scale
        let postH: CGFloat = 56 * scale
        let railH: CGFloat =  9 * scale
        let gap:   CGFloat = 54 * scale
        let cx = sz.width * 0.5
        let brown = Color(red:0.627, green:0.408, blue:0.227)
        let tan   = Color(red:0.753, green:0.502, blue:0.251)

        for dx in [-gap/2, gap/2] {
            ctx.fill(Path(roundedRect: CGRect(x: cx+dx-postW/2, y: groundY-postH,
                                              width: postW, height: postH), cornerRadius: 3),
                     with: .color(brown))
        }
        let railX = cx - gap/2 + postW/2
        let railW = gap - postW
        ctx.fill(Path(roundedRect: CGRect(x:railX, y:groundY-postH*0.643, width:railW, height:railH), cornerRadius:3),
                 with: .color(tan))
        ctx.fill(Path(roundedRect: CGRect(x:railX, y:groundY-postH*0.321, width:railW, height:railH), cornerRadius:3),
                 with: .color(tan))
    }

    // ── Sheep ─────────────────────────────────────────────────────────────────

    private func drawSheep(_ ctx: GraphicsContext, _ sz: CGSize, groundY: CGFloat, scale: CGFloat) {
        let sw = 54 * scale
        let sh = 40 * scale

        let xPos  = sheepX(width: sz.width)
        let yOff  = sheepYOffset() * scale
        let alpha = sheepOpacity()
        let deg   = sheepRotation()
        guard alpha > 0.001 else { return }

        let ox = xPos
        let oy = groundY - sh + yOff   // top-left of sheep bounding box

        let dark = Color(red:0.227, green:0.188, blue:0.157)
        var c = ctx
        c.opacity = alpha

        // Rotate around sheep centre
        let cxS = ox + sw/2, cyS = oy + sh/2
        c.translateBy(x: cxS, y: cyS)
        c.rotate(by: .degrees(deg))
        c.translateBy(x: -cxS, y: -cyS)

        // Wool body
        c.fill(Path(ellipseIn: CGRect(x:ox+6*scale, y:oy+2*scale, width:38*scale, height:26*scale)),
               with: .color(Color(red:0.941, green:0.941, blue:0.941)))
        // Bumps
        c.fill(Path(ellipseIn: CGRect(x:ox+12*scale, y:oy-4*scale, width:18*scale, height:16*scale)),
               with: .color(Color(red:0.910, green:0.910, blue:0.910)))
        c.fill(Path(ellipseIn: CGRect(x:ox+24*scale, y:oy-2*scale, width:14*scale, height:12*scale)),
               with: .color(Color(red:0.910, green:0.910, blue:0.910)))
        // Head
        c.fill(Path(ellipseIn: CGRect(x:ox+36*scale, y:oy+4*scale, width:18*scale, height:16*scale)),
               with: .color(dark))
        // Ear
        c.fill(Path(ellipseIn: CGRect(x:ox+40*scale, y:oy-1*scale, width:7*scale, height:9*scale)),
               with: .color(dark))
        // Eye
        c.fill(Path(ellipseIn: CGRect(x:ox+47*scale, y:oy+8*scale, width:4*scale, height:4*scale)),
               with: .color(.white))
        // Legs (walking animation — 0.5 s period)
        let legW = 6 * scale
        let legH = 14 * scale
        let legY = oy + sh - legH
        let walkT = (elapsed.truncatingRemainder(dividingBy: 0.5)) / 0.5
        let legXs: [CGFloat] = [ox+10*scale, ox+21*scale, ox+32*scale, ox+43*scale]
        for (i, lx) in legXs.enumerated() {
            let phase: Double = (i % 2 == 0) ? 0 : .pi
            let angle = 12.0 * sin(walkT * .pi * 2 + phase)
            let lcx = lx + legW/2,  lcy = legY + legH/2
            var lc = c
            lc.translateBy(x: lcx, y: lcy)
            lc.rotate(by: .degrees(angle))
            lc.translateBy(x: -lcx, y: -lcy)
            lc.fill(Path(roundedRect: CGRect(x:lx, y:legY, width:legW, height:legH), cornerRadius:2*scale),
                    with: .color(dark))
        }
    }

    // ── Animation math ────────────────────────────────────────────────────────

    private func sheepX(width: CGFloat) -> CGFloat {
        let W = width
        switch progress {
        case ..<0.30: return lerp(-60, 0.40*W, progress / 0.30)
        case ..<0.58: return lerp(0.40*W, 0.60*W, (progress-0.30) / 0.28)
        case ..<0.88: return lerp(0.60*W, W+60,   (progress-0.58) / 0.30)
        default:      return -60
        }
    }

    private func sheepYOffset() -> CGFloat {
        switch progress {
        case ..<0.28: return 0
        case ..<0.31: return CGFloat((progress-0.28)/0.03) * 6     // crouch
        case ..<0.57:                                               // parabolic arc
            let t = (progress - 0.31) / (0.57 - 0.31)
            return -jumpH * CGFloat(4 * t * (1 - t))
        case ..<0.60: return -CGFloat((progress-0.57)/0.03) * 14   // bounce down
        case ..<0.63: return -14 + CGFloat((progress-0.60)/0.03)*14 // settle
        default:      return 0
        }
    }

    private func sheepOpacity() -> Double {
        (progress >= 0.885 && progress < 0.995) ? 0 : 1
    }

    private func sheepRotation() -> Double {
        guard doFlip, progress >= 0.31, progress < 0.63 else { return 0 }
        return -360 * (progress - 0.31) / (0.63 - 0.31)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(max(0, min(1, t)))
    }

    private func hhmm() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: Date())
    }
    private func dateStr() -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE  d MMM"; return f.string(from: Date())
    }
}
