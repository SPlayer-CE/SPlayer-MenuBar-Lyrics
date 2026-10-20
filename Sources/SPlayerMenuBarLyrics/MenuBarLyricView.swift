import AppKit
import CoreText

/// 菜单栏歌词项：音符图标 + 逐字扫过的歌词 + 右侧播放控制
final class MenuBarLyricView: NSView {
    private let musicIcon = SymbolView(symbol: "music.note", pointSize: 13)
    private let textView = KaraokeTextView()
    private let previousButton = ControlButtonView(
        symbol: "backward.fill",
        tooltip: L10n.t(.previousTrack)
    )
    private let playPauseButton = ControlButtonView(
        symbol: "play.fill",
        tooltip: L10n.t(.play)
    )
    private let nextButton = ControlButtonView(
        symbol: "forward.fill",
        tooltip: L10n.t(.nextTrack)
    )
    private let favoriteButton = ControlButtonView(
        symbol: "heart",
        tooltip: L10n.t(.favorite)
    )

    var onPrevious: (() -> Void)?
    var onTogglePlayback: (() -> Void)?
    var onNext: (() -> Void)?
    var onToggleFavorite: (() -> Void)?

    private var controlsVisible = false
    private var favoriteSupported = false
    private var iconPosition: MenuBarIconPosition = .left

    private let buttonSize: CGFloat = 18
    private let rightInset: CGFloat = 6
    private let iconSize: CGFloat = 16

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        addSubview(musicIcon)
        addSubview(textView)
        addSubview(previousButton)
        addSubview(playPauseButton)
        addSubview(nextButton)
        addSubview(favoriteButton)

        previousButton.action = { [weak self] in self?.onPrevious?() }
        playPauseButton.action = { [weak self] in self?.onTogglePlayback?() }
        nextButton.action = { [weak self] in self?.onNext?() }
        favoriteButton.action = { [weak self] in self?.onToggleFavorite?() }
    }

    func setIcon(connected: Bool) {
        musicIcon.symbol = connected ? "music.note.list" : "music.note"
    }

    /// 音乐图标放在歌词左侧、右侧，或隐藏
    func setIconPosition(_ position: MenuBarIconPosition) {
        guard iconPosition != position else { return }
        iconPosition = position
        musicIcon.isHidden = position == .hidden
        needsLayout = true
    }

    func setPlaying(_ playing: Bool) {
        playPauseButton.symbol = playing ? "pause.fill" : "play.fill"
        playPauseButton.updateTooltip(L10n.t(playing ? .pause : .play))
    }

    /// 语言切换后刷新固定按钮的提示
    func applyLocalizedTooltips() {
        previousButton.updateTooltip(L10n.t(.previousTrack))
        nextButton.updateTooltip(L10n.t(.nextTrack))
    }

    func setControlsVisible(_ visible: Bool) {
        controlsVisible = visible
        updateControlVisibility()
    }

    func setFavorite(favorite: Bool, supported: Bool, available: Bool) {
        favoriteSupported = supported
        favoriteButton.symbol = favorite ? "heart.fill" : "heart"
        if !available {
            favoriteButton.updateTooltip(L10n.t(.favoriteUnavailable))
        } else {
            favoriteButton.updateTooltip(L10n.t(favorite ? .unfavorite : .favorite))
        }
        updateControlVisibility()
    }

    private func updateControlVisibility() {
        previousButton.isHidden = !controlsVisible
        playPauseButton.isHidden = !controlsVisible
        nextButton.isHidden = !controlsVisible
        favoriteButton.isHidden = !(controlsVisible && favoriteSupported)
        needsLayout = true
    }

    func update(
        text: String,
        mainLineUTF16: Int,
        timings: [CharacterTiming],
        timeMs: Double,
        highlight: Bool,
        alignment: LyricAlignment,
        lineStartMs: Double,
        lineEndMs: Double
    ) {
        textView.update(
            text: text,
            mainLineUTF16: mainLineUTF16,
            timings: timings,
            timeMs: timeMs,
            highlight: highlight,
            alignment: alignment,
            lineStartMs: lineStartMs,
            lineEndMs: lineEndMs
        )
    }

    override var isOpaque: Bool { false }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    /// 只有控制按钮区域接收鼠标；其余区域返回 nil，交给状态栏按钮弹出菜单
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        for button in [previousButton, playPauseButton, nextButton, favoriteButton]
        where !button.isHidden {
            if button.frame.contains(local) {
                return button
            }
        }
        return nil
    }

    override func layout() {
        super.layout()
        let height = bounds.height

        let favoriteVisible = !favoriteButton.isHidden
        let visibleCount = 3 + (favoriteVisible ? 1 : 0)
        let controlsWidth = buttonSize * CGFloat(visibleCount)
        let controlStart = bounds.width - rightInset - controlsWidth
        let buttonY = (height - buttonSize) / 2
        previousButton.frame = NSRect(
            x: controlStart,
            y: buttonY,
            width: buttonSize,
            height: buttonSize
        )
        playPauseButton.frame = NSRect(
            x: controlStart + buttonSize,
            y: buttonY,
            width: buttonSize,
            height: buttonSize
        )
        nextButton.frame = NSRect(
            x: controlStart + buttonSize * 2,
            y: buttonY,
            width: buttonSize,
            height: buttonSize
        )
        favoriteButton.frame = NSRect(
            x: controlStart + buttonSize * 3,
            y: buttonY,
            width: buttonSize,
            height: buttonSize
        )

        let controlsHidden = previousButton.isHidden
        let areaEnd = controlsHidden ? bounds.width - rightInset : controlStart - 4
        let iconY = (height - iconSize) / 2

        let textLeft: CGFloat
        let textEnd: CGFloat
        switch iconPosition {
        case .left:
            musicIcon.frame = NSRect(
                x: 6,
                y: iconY,
                width: iconSize,
                height: iconSize
            )
            textLeft = 26
            textEnd = areaEnd
        case .right:
            let iconX = max(6, areaEnd - iconSize)
            musicIcon.frame = NSRect(
                x: iconX,
                y: iconY,
                width: iconSize,
                height: iconSize
            )
            textLeft = 6
            textEnd = iconX - 4
        case .hidden:
            textLeft = 6
            textEnd = areaEnd
        }

        textView.frame = NSRect(
            x: textLeft,
            y: 0,
            width: max(0, textEnd - textLeft),
            height: height
        )
    }
}

/// 用当前外观的 labelColor 自绘 SF Symbol，避免 NSButton 模板图标的取色问题
private class SymbolView: NSView {
    var symbol: String {
        didSet { needsDisplay = true }
    }
    var pointSize: CGFloat
    var weight: NSFont.Weight = .medium

    override var isOpaque: Bool { false }

    init(symbol: String, pointSize: CGFloat) {
        self.symbol = symbol
        self.pointSize = pointSize
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTooltip(_ text: String) {
        toolTip = text
        setAccessibilityLabel(text)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = makeImage() else { return }
        let size = image.size
        let rect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: rect)
    }

    private func makeImage() -> NSImage? {
        // 在视图自身的外观下解析动态颜色，避免取到应用外观而不是菜单栏外观
        var resolved = NSColor.labelColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = NSColor.labelColor.usingColorSpace(.deviceRGB) ?? NSColor.labelColor
        }
        let palette = NSImage.SymbolConfiguration(paletteColors: [resolved])
        let configuration = palette.applying(
            NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        )
        return NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip)?
            .withSymbolConfiguration(configuration)
    }
}

/// 可点击的符号按钮，按下时给一点背景反馈
private final class ControlButtonView: SymbolView {
    var action: (() -> Void)?
    private var pressed = false {
        didSet { needsDisplay = true }
    }

    init(symbol: String, tooltip: String) {
        super.init(symbol: symbol, pointSize: 11)
        updateTooltip(tooltip)
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        pressed = true
    }

    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        pressed = false
        if inside {
            action?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        pressed = bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override func draw(_ dirtyRect: NSRect) {
        if pressed {
            NSColor.labelColor.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
        }
        super.draw(dirtyRect)
    }
}

/// 单行歌词绘制：先画未播放色，再按逐字进度裁切画已播放色，形成连续扫光
private final class KaraokeTextView: NSView {
    private var text = ""
    private var mainLineUTF16 = 0
    private var timings: [CharacterTiming] = []
    private var timeMs: Double = 0
    private var highlight = false
    private var alignment: LyricAlignment = .left

    private var ctLine: CTLine?
    private var lineWidth: CGFloat = 0
    private var ascent: CGFloat = 0
    private var descent: CGFloat = 0
    private var lineUTF16 = 0
    private var builtWidth: CGFloat = -1

    /// 超宽歌词的横向滚动状态
    private var scrolling = false
    private var scrollOffset: CGFloat = 0
    private var lineStartMs: Double = 0
    private var lineEndMs: Double = 0

    /// 无逐字时间（如显示歌曲标题）时的匀速滚动状态
    private var marqueeWaitUntil: TimeInterval = 0
    private var lastTick: TimeInterval = 0

    private let marqueeSpeed: CGFloat = 60
    /// 循环滚动时两段文字之间的间隔
    private let scrollGap: CGFloat = 40
    private let marqueeStartDelay: TimeInterval = 0.6

    private let font = NSFont.systemFont(ofSize: 13, weight: .regular)

    override var isOpaque: Bool { false }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if newSize.width != builtWidth {
            rebuild()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    func update(
        text: String,
        mainLineUTF16: Int,
        timings: [CharacterTiming],
        timeMs: Double,
        highlight: Bool,
        alignment: LyricAlignment,
        lineStartMs: Double,
        lineEndMs: Double
    ) {
        let textChanged = self.text != text
        self.text = text
        self.mainLineUTF16 = mainLineUTF16
        self.timings = timings
        self.timeMs = timeMs
        self.highlight = highlight
        self.alignment = alignment
        self.lineStartMs = lineStartMs
        self.lineEndMs = lineEndMs
        if textChanged || ctLine == nil {
            rebuild()
        }
        updateScrollOffset()
        needsDisplay = true
    }

    /// 滚动位置跟随已唱到的位置：唱到行尾时恰好露出结尾
    private func updateScrollOffset() {
        guard scrolling else {
            scrollOffset = 0
            return
        }
        if let progress = lyricProgress() {
            let visible = max(1, bounds.width - 2)
            let overflow = max(0, lineWidth - visible)
            scrollOffset = -overflow * progress
        } else {
            advanceMarquee()
        }
    }

    /// 当前行已唱到的比例（0…1）；优先使用逐字时间，整行歌词则按行时间推进
    private func lyricProgress() -> CGFloat? {
        guard let line = ctLine, lineWidth > 0 else { return nil }

        if !timings.isEmpty {
            guard let probe = LyricHighlight.probe(at: timeMs, timings: timings) else {
                return 0
            }
            return min(max(sweepX(for: probe, line: line) / lineWidth, 0), 1)
        }

        guard lineEndMs > lineStartMs else { return nil }
        let fraction = (timeMs - lineStartMs) / (lineEndMs - lineStartMs)
        return CGFloat(min(max(fraction, 0), 1))
    }

    /// 没有歌词时间信息时（如显示歌曲标题）匀速循环滚动
    private func advanceMarquee() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(max(now - lastTick, 0), 0.1)
        lastTick = now
        guard now >= marqueeWaitUntil else { return }

        scrollOffset -= marqueeSpeed * CGFloat(delta)
        let period = lineWidth + scrollGap
        if scrollOffset <= -period {
            // 第二段恰好滚到起点，复位后画面无缝衔接
            scrollOffset += period
        }
    }

    /// 高亮扫光边缘在整行中的 x 坐标
    private func sweepX(for probe: HighlightProbe, line: CTLine) -> CGFloat {
        if probe.utf16Start >= lineUTF16 {
            return lineWidth
        }
        if probe.utf16End > probe.utf16Start {
            let start = min(probe.utf16Start, lineUTF16)
            let end = min(probe.utf16End, lineUTF16)
            let startOffset = CGFloat(CTLineGetOffsetForStringIndex(line, CFIndex(start), nil))
            let endOffset = CGFloat(CTLineGetOffsetForStringIndex(line, CFIndex(end), nil))
            return startOffset + (endOffset - startOffset) * CGFloat(probe.fraction)
        }
        let index = min(probe.utf16Start, lineUTF16)
        return CGFloat(CTLineGetOffsetForStringIndex(line, CFIndex(index), nil))
    }

    private func makeAttributed(_ string: String) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: font,
                // 允许用 CGContext 的填充色绘制同一行文本的两种颜色
                NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
            ]
        )
    }

    private func makeLine(
        _ string: String
    ) -> (line: CTLine, width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        let line = CTLineCreateWithAttributedString(makeAttributed(string))
        var lineAscent: CGFloat = 0
        var lineDescent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(
            CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &leading)
        )
        return (line, width, lineAscent, lineDescent)
    }

    private func rebuild() {
        builtWidth = bounds.width
        let available = max(1, bounds.width - 2)
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            ctLine = nil
            lineWidth = 0
            lineUTF16 = 0
            scrolling = false
            needsDisplay = true
            return
        }

        let full = makeLine(normalized)
        ctLine = full.line
        lineWidth = full.width
        ascent = full.ascent
        descent = full.descent
        lineUTF16 = normalized.utf16.count

        // 放不下的整行不再截断加省略号，而是跟随播放进度横向滚动
        scrolling = full.width > available
        scrollOffset = 0
        marqueeWaitUntil = ProcessInfo.processInfo.systemUptime + marqueeStartDelay
        lastTick = ProcessInfo.processInfo.systemUptime
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let line = ctLine, lineWidth > 0,
              let context = NSGraphicsContext.current?.cgContext else { return }
        let baseline = (bounds.height - (ascent + descent)) / 2 + descent
        let origins = textOrigins

        // 滚动时文字起点会为负、下一段会越界，必须裁到自身区域，不能盖住图标和右侧按钮
        context.saveGState()
        context.clip(to: bounds)
        defer { context.restoreGState() }

        guard highlight, !timings.isEmpty else {
            for origin in origins {
                drawText(line, color: .labelColor, baseline: baseline, originX: origin)
            }
            return
        }

        for origin in origins {
            drawText(line, color: .secondaryLabelColor, baseline: baseline, originX: origin)
        }
        guard let probe = LyricHighlight.probe(at: timeMs, timings: timings) else {
            return
        }

        let progressX = sweepX(for: probe, line: line)
        guard progressX > 0.5 else { return }

        for origin in origins {
            context.saveGState()
            context.clip(
                to: CGRect(
                    x: origin,
                    y: 0,
                    width: progressX,
                    height: bounds.height
                )
            )
            drawText(line, color: .labelColor, baseline: baseline, originX: origin)
            context.restoreGState()
        }
    }

    /// 绘制起点：不滚动时按对齐方式定位；滚动时同时画本段与下一段，循环处无缝衔接
    private var textOrigins: [CGFloat] {
        guard scrolling else {
            let slack = bounds.width - lineWidth
            switch alignment {
            case .left: return [0]
            case .center: return [max(0, slack / 2)]
            case .right: return [max(0, slack)]
            }
        }
        return [scrollOffset, scrollOffset + lineWidth + scrollGap]
    }

    private func drawText(
        _ line: CTLine,
        color: NSColor,
        baseline: CGFloat,
        originX: CGFloat
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: originX, y: baseline)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
