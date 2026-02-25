import ScreenSaver
import WebKit

@objc(CountingSheepSaver)
class CountingSheepSaver: ScreenSaverView {

    private var webView: WKWebView?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        animationTimeInterval = 1.0 / 30.0

        // WKWebView requires a layer-backed view hierarchy to render.
        wantsLayer = true

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []

        let wv = WKWebView(frame: bounds, configuration: config)
        wv.autoresizingMask = [.width, .height]
        wv.wantsLayer = true
        addSubview(wv)
        webView = wv

        guard let url = Bundle(for: type(of: self))
                .url(forResource: "index", withExtension: "html") else { return }
        wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    override func animateOneFrame() {
        // Animation is driven by the WKWebView — nothing needed here
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
