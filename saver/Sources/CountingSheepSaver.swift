import ScreenSaver
import AppKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Constants
// ─────────────────────────────────────────────────────────────────────────────

private let CYCLE     = 4.5
private let FLIP_PROB = 0.05

// (x%, y%, radius_px, period_s, phase_s)  — same as the web version
private let starData: [(Double,Double,Double,Double,Double)] = [
    (8,12,1.25,2.1,0),   (15,28,0.75,3.2,0.4), (22,8,1,2.8,0.8),   (31,18,0.75,4.1,0.2),
    (40,35,1.25,2.3,1.1),(48,10,0.75,3.7,0.5), (57,22,1,2.6,1.4),  (64,40,0.5,3.4,0.9),
    (73,14,1.25,2.9,0.3),(80,30,1,4.2,1.7),    (88,7,0.75,3.1,0.6),(93,24,1,2.4,1.2),
    (12,55,0.75,3.8,0.7),(25,48,1,2.7,1.5),    (37,60,0.5,4.0,0.1),(52,52,1.25,3.3,1.8),
    (66,58,0.75,2.2,0.9),(78,45,1,3.6,0.4),    (85,62,0.5,4.3,1.3),(95,50,1,2.5,0.8),
    (5,42,0.75,3.9,1.6), (18,68,1,2.8,0.2),    (44,70,0.75,3.5,1), (70,72,0.5,4.1,1.9),
    (90,68,1,2.3,0.5),
]

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – ScreenSaverView
// ─────────────────────────────────────────────────────────────────────────────

@objc(CountingSheepSaver)
final class CountingSheepSaver: ScreenSaverView {

    private var startTime:      TimeInterval = 0
    private var jumpH:          CGFloat      = 80
    private var doFlip                       = false
    private var sheepCount:     Int          = 0
    private var lastCycleIdx:   Int          = -1
    private var lastCountedIdx: Int          = -1

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
        startTime = CACurrentMediaTime()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); startTime = CACurrentMediaTime() }

    override func animateOneFrame() { display() }
    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }

    // ── Main draw ─────────────────────────────────────────────────────────────

    override func draw(_ dirtyRect: NSRect) {
        let elapsed   = CACurrentMediaTime() - startTime
        let cycleIdx  = Int(elapsed / CYCLE)
        let progress  = (elapsed / CYCLE).truncatingRemainder(dividingBy: 1.0)

        if cycleIdx != lastCycleIdx {
            lastCycleIdx = cycleIdx
            jumpH  = .random(in: 55...120)
            doFlip = .random(in: 0...1) < FLIP_PROB
        }
        // Increment counter when sheep is at the apex (clears the fence)
        if progress > 0.44 && cycleIdx != lastCountedIdx {
            lastCountedIdx = cycleIdx
            sheepCount    += 1
        }

        let b       = bounds
        let scale   = max(1, b.height / 500)
        // AppKit: y=0 is bottom. "floor" is where sheep/fence stand.
        let floorY  = b.height * 0.20

        drawSky(b)
        drawStars(b, elapsed: elapsed)
        drawMoon(b, scale: scale)
        drawGround(b, floorY: floorY)
        drawFence(b, floorY: floorY, scale: scale)
        drawSheep(b, floorY: floorY, scale: scale, progress: progress, elapsed: elapsed)
        drawHUD(b, scale: scale, floorY: floorY)
    }

    // ── Sky ───────────────────────────────────────────────────────────────────

    private func drawSky(_ b: NSRect) {
        NSGradient(colors: [
            NSColor(red:0.027, green:0.027, blue:0.102, alpha:1),
            NSColor(red:0.051, green:0.051, blue:0.180, alpha:1),
            NSColor(red:0.067, green:0.102, blue:0.067, alpha:1),
        ])?.draw(in: b, angle: 270)
    }

    // ── Stars ─────────────────────────────────────────────────────────────────

    private func drawStars(_ b: NSRect, elapsed: Double) {
        // Stars live in the sky (top ~78% of screen); in AppKit y counts from bottom
        let skyH = b.height * 0.78
        for (xPct, yPct, r, period, phase) in starData {
            let opacity = 0.2 + 0.8 * (0.5 + 0.5 * sin((elapsed + phase) / period * .pi * 2))
            NSColor.white.withAlphaComponent(opacity).setFill()
            // y% from top → AppKit: b.height - skyH*yPct/100 ... but stars from top of screen
            let cx = b.width  * xPct / 100
            let cy = b.height - b.height * yPct / 100   // convert % from top → AppKit y
            NSBezierPath(ovalIn: NSRect(x: cx-r, y: cy-r, width: r*2, height: r*2)).fill()
        }
    }

    // ── Moon ──────────────────────────────────────────────────────────────────

    private func drawMoon(_ b: NSRect, scale: CGFloat) {
        let r  = 28 * scale
        // CSS: top:8%, right:8% → disc top-left in AppKit:
        let dx = b.width  * 0.92 - 2*r        // left edge of disc
        let dy = b.height * 0.92 - 2*r        // bottom edge of disc (AppKit: y from bottom, top:8% → bottom:92%-height)
        // Moon disc
        NSColor(red:0.992, green:0.965, blue:0.847, alpha:1).setFill()
        NSBezierPath(ovalIn: NSRect(x: dx, y: dy, width: r*2, height: r*2)).fill()
        // Bite — sky-coloured circle offset to create crescent
        let br  = r * 0.786
        let bx  = dx + r * 0.64
        let by  = dy + r * 0.21
        NSColor(red:0.051, green:0.051, blue:0.180, alpha:1).setFill()
        NSBezierPath(ovalIn: NSRect(x: bx, y: by, width: br*2, height: br*2)).fill()
    }

    // ── Ground ────────────────────────────────────────────────────────────────

    private func drawGround(_ b: NSRect, floorY: CGFloat) {
        let groundH = b.height * 0.22
        let groundRect = NSRect(x: 0, y: 0, width: b.width, height: groundH)
        NSGradient(colors: [
            NSColor(red:0.071, green:0.145, blue:0.063, alpha:1),   // bottom (dark)
            NSColor(red:0.102, green:0.200, blue:0.094, alpha:1),   // top (lighter)
        ])?.draw(in: groundRect, angle: 90)   // 90° = bottom→top
        // Edge strip
        NSColor(red:0.165, green:0.290, blue:0.157, alpha:1).setFill()
        NSRect(x: 0, y: groundH - 4, width: b.width, height: 8).fill()
    }

    // ── Fence ─────────────────────────────────────────────────────────────────

    private func drawFence(_ b: NSRect, floorY: CGFloat, scale: CGFloat) {
        let postW: CGFloat = 10 * scale
        let postH: CGFloat = 56 * scale
        let railH: CGFloat =  9 * scale
        let gap:   CGFloat = 54 * scale   // centre-to-centre of posts
        let cx = b.width * 0.50
        let brown = NSColor(red:0.627, green:0.408, blue:0.227, alpha:1)
        let tan   = NSColor(red:0.753, green:0.502, blue:0.251, alpha:1)

        for dx in [-gap/2, gap/2] {
            brown.setFill()
            let post = NSBezierPath(roundedRect: NSRect(x: cx+dx-postW/2, y: floorY,
                                                        width: postW, height: postH),
                                    xRadius: 3, yRadius: 3)
            post.fill()
        }
        tan.setFill()
        let railX = cx - gap/2 + postW/2
        let railW = gap - postW
        NSBezierPath(roundedRect: NSRect(x: railX, y: floorY + 18*scale, width: railW, height: railH),
                     xRadius: 3, yRadius: 3).fill()
        NSBezierPath(roundedRect: NSRect(x: railX, y: floorY + 36*scale, width: railW, height: railH),
                     xRadius: 3, yRadius: 3).fill()
    }

    // ── Sheep ─────────────────────────────────────────────────────────────────

    private func drawSheep(_ b: NSRect, floorY: CGFloat, scale: CGFloat,
                            progress: Double, elapsed: Double) {
        let sw = 54 * scale
        let sh = 40 * scale

        let xPos  = sheepX(width: b.width, scale: scale, progress: progress)
        let yOff  = sheepYAppKit(progress: progress) * scale   // positive = up in AppKit
        let alpha = sheepOpacity(progress: progress)
        let deg   = sheepRotDeg(progress: progress)
        guard alpha > 0.001 else { return }

        // Bottom-left of sheep bounding box (AppKit: y from bottom)
        let ox = xPos
        let oy = floorY + yOff     // sheep bottom-left y

        let dark = NSColor(red:0.227, green:0.188, blue:0.157, alpha:1)

        NSGraphicsContext.current?.saveGraphicsState()
        if alpha < 1 { NSColor.white.withAlphaComponent(alpha) } // hint only; use CGAlpha below

        // Rotation around sheep centre
        if deg != 0 {
            let t = NSAffineTransform()
            t.translateX(by: ox + sw/2, yBy: oy + sh/2)
            t.rotate(byDegrees: deg)
            t.translateX(by: -(ox + sw/2), yBy: -(oy + sh/2))
            t.concat()
        }

        // We need alpha blending — set alpha on context
        NSGraphicsContext.current?.cgContext.setAlpha(alpha)

        // Wool body
        NSColor(red:0.941, green:0.941, blue:0.941, alpha:1).setFill()
        NSBezierPath(ovalIn: NSRect(x:ox+6*scale, y:oy+14*scale, width:38*scale, height:26*scale)).fill()
        // Bumps (wool top)
        NSColor(red:0.910, green:0.910, blue:0.910, alpha:1).setFill()
        NSBezierPath(ovalIn: NSRect(x:ox+12*scale, y:oy+30*scale, width:18*scale, height:16*scale)).fill()
        NSBezierPath(ovalIn: NSRect(x:ox+24*scale, y:oy+28*scale, width:14*scale, height:12*scale)).fill()
        // Head (right side of sheep)
        dark.setFill()
        NSBezierPath(ovalIn: NSRect(x:ox+36*scale, y:oy+20*scale, width:18*scale, height:16*scale)).fill()
        // Ear
        NSBezierPath(ovalIn: NSRect(x:ox+40*scale, y:oy+31*scale, width:7*scale, height:9*scale)).fill()
        // Eye
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x:ox+47*scale, y:oy+24*scale, width:4*scale, height:4*scale)).fill()
        // Legs
        let legW = 6 * scale, legH = 14 * scale
        let legXs: [CGFloat] = [ox+10*scale, ox+21*scale, ox+32*scale, ox+43*scale]
        let isAirborne = progress > 0.31 && progress < 0.60
        let walkT = elapsed.truncatingRemainder(dividingBy: 0.5) / 0.5
        dark.setFill()
        for (i, lx) in legXs.enumerated() {
            let phase: Double = (i % 2 == 0) ? 0 : .pi
            let angle = isAirborne ? 0.0 : 12.0 * sin(walkT * .pi * 2 + phase)
            let lcx = lx + legW/2, lcy = oy + legH     // pivot at hip (top of leg)
            let lt = NSAffineTransform()
            lt.translateX(by: lcx, yBy: lcy)
            lt.rotate(byDegrees: angle)
            lt.translateX(by: -lcx, yBy: -lcy)
            NSGraphicsContext.current?.saveGraphicsState()
            lt.concat()
            NSBezierPath(roundedRect: NSRect(x:lx, y:oy, width:legW, height:legH),
                         xRadius: 2*scale, yRadius: 2*scale).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    // ── HUD (clock + counter) ─────────────────────────────────────────────────

    private func drawHUD(_ b: NSRect, scale: CGFloat, floorY: CGFloat) {
        let clockSize = min(96, max(36, b.width * 0.065))
        let dateSize  = max(11, clockSize * 0.19)

        let timeStr  = hhmm()
        let dateStr  = dateString()
        let countStr = "\(sheepCount) sheep"

        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font:            NSFont.monospacedDigitSystemFont(ofSize: clockSize, weight: .ultraLight),
            .foregroundColor: NSColor.white,
        ]
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font:            NSFont.systemFont(ofSize: dateSize, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.45),
        ]
        let counterAttrs: [NSAttributedString.Key: Any] = [
            .font:            NSFont.systemFont(ofSize: max(11, b.width * 0.013)),
            .foregroundColor: NSColor.white.withAlphaComponent(0.45),
        ]

        let timeAS  = NSAttributedString(string: timeStr,  attributes: timeAttrs)
        let dateAS  = NSAttributedString(string: dateStr.uppercased(), attributes: dateAttrs)
        let countAS = NSAttributedString(string: countStr, attributes: counterAttrs)

        let tSz = timeAS.size(), dSz = dateAS.size(), cSz = countAS.size()
        let gap: CGFloat = 6
        let totalH = tSz.height + gap + dSz.height

        // Clock — vertically centred
        let timeY = b.midY + totalH/2 - tSz.height
        let dateY = timeY - gap - dSz.height
        timeAS.draw(at:  NSPoint(x: b.midX - tSz.width/2, y: timeY))
        dateAS.draw(at:  NSPoint(x: b.midX - dSz.width/2, y: dateY))

        // Counter — above fence
        let counterY = floorY + 72 * scale
        countAS.draw(at: NSPoint(x: b.midX - cSz.width/2, y: counterY))
    }

    // ── Animation math ────────────────────────────────────────────────────────

    private func sheepX(width: CGFloat, scale: CGFloat, progress: Double) -> CGFloat {
        let offL = -(60 + 54 * scale)   // fully off-screen left
        let offR = width + 60
        switch progress {
        case ..<0.30: return lerp(offL, 0.40*width, progress / 0.30)
        case ..<0.58: return lerp(0.40*width, 0.60*width, (progress-0.30)/0.28)
        case ..<0.88: return lerp(0.60*width, offR,        (progress-0.58)/0.30)
        default:      return offL
        }
    }

    // Returns AppKit Y offset (positive = up = visually up)
    private func sheepYAppKit(progress: Double) -> CGFloat {
        switch progress {
        case ..<0.28: return 0
        case ..<0.31: return -CGFloat((progress-0.28)/0.03) * 6   // crouch down
        case ..<0.57:                                               // parabolic arc
            let t = (progress - 0.31) / (0.57 - 0.31)
            return jumpH * CGFloat(4 * t * (1 - t))
        case ..<0.60: return CGFloat((progress-0.57)/0.03) * 14   // bounce up
        case ..<0.63: return 14 - CGFloat((progress-0.60)/0.03)*14 // settle
        default:      return 0
        }
    }

    private func sheepOpacity(progress: Double) -> CGFloat {
        if progress < 0.05  { return CGFloat(progress / 0.05) }   // fade in
        if progress >= 0.885 { return 0 }                          // hidden off-screen right
        return 1
    }

    // AppKit rotates CCW for positive degrees (same visual result as CSS rotate(-360deg))
    private func sheepRotDeg(progress: Double) -> CGFloat {
        guard doFlip, progress >= 0.31, progress < 0.63 else { return 0 }
        return CGFloat(360 * (progress - 0.31) / (0.63 - 0.31))
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(max(0, min(1, t)))
    }

    private func hhmm() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: Date())
    }
    private func dateString() -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE  d MMM"; return f.string(from: Date())
    }
}
