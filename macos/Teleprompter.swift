import Cocoa

final class Prompter: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    let scroll = NSScrollView()
    let script = NSTextView()
    let speed = NSSlider(value: 140, minValue: 60, maxValue: 240, target: nil, action: nil)
    let speedLabel = NSTextField(labelWithString: "140 词/分钟")
    let play = NSButton(title: "开始", target: nil, action: nil)
    var running = false
    var timer: Timer?
    var previous = ProcessInfo.processInfo.systemUptime
    var position: CGFloat = 0
    let gap = NSSlider(value: 80, minValue: 0, maxValue: 400, target: nil, action: nil)
    let gapLabel = NSTextField(labelWithString: "开头留白 80")
    var finished = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 200, y: 250, width: 540, height: 390), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "悬浮提词器"
        window.minSize = NSSize(width: 420, height: 270)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.9)
        window.alphaValue = 0.94
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        let root = NSView()
        window.contentView = root
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 9
        play.target = self; play.action = #selector(toggle)
        let reset = NSButton(title: "重置", target: self, action: #selector(resetPosition))
        let top = NSButton(checkboxWithTitle: "置顶", target: self, action: #selector(changeTop(_:)))
        top.state = .on
        [play, reset, top].forEach { controls.addArrangedSubview($0) }
        let speedRow = NSStackView()
        speedRow.orientation = .horizontal; speedRow.spacing = 8
        speed.target = self; speed.action = #selector(changeSpeed)
        speed.widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        speedRow.addArrangedSubview(speed); speedRow.addArrangedSubview(speedLabel)
        let gapRow = NSStackView()
        gapRow.orientation = .horizontal; gapRow.spacing = 8
        gap.target = self; gap.action = #selector(changeGap)
        gap.doubleValue = UserDefaults.standard.object(forKey: "openingGap") as? Double ?? 80
        gapLabel.stringValue = "开头留白 \(Int(gap.doubleValue))"
        gapLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        gap.widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        gapRow.addArrangedSubview(gap); gapRow.addArrangedSubview(gapLabel)
        let opacity = NSSlider(value: 0.94, minValue: 0.45, maxValue: 1, target: self, action: #selector(changeOpacity(_:)))
        opacity.widthAnchor.constraint(equalToConstant: 85).isActive = true
        controls.addArrangedSubview(NSTextField(labelWithString: "透明度")); controls.addArrangedSubview(opacity)
        let hint = NSTextField(labelWithString: "直接编辑或粘贴台词 · 拖动标题栏移动 · 拖动边缘调整大小")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        script.isRichText = false
        script.isEditable = true
        script.isSelectable = true
        script.drawsBackground = false
        script.textColor = .white
        script.insertionPointColor = .white
        script.font = .systemFont(ofSize: 30, weight: .medium)
        script.textContainerInset = NSSize(width: 20, height: 22 + gap.doubleValue)
        script.isVerticallyResizable = false
        script.isHorizontallyResizable = false
        script.autoresizingMask = [.width]
        script.textContainer?.widthTracksTextView = true
        script.textContainer?.containerSize = NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude)
        script.minSize = NSSize(width: 0, height: 0)
        script.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 10
        script.defaultParagraphStyle = paragraph
        script.typingAttributes = [.font: script.font!, .foregroundColor: NSColor.white, .paragraphStyle: paragraph]
        script.string = "Welcome! Paste your interview script here.\n\nSpeak naturally and press Start when you are ready. The text will scroll smoothly at approximately 140 words per minute.\n\n你可以直接粘贴或编辑中文、英文台词。点击“开始”后文字会平滑向上滚动，滑杆可以随时调整速度。\n\n点击“暂停”可修改台词，点击“重置”回到开头。拖动标题栏移动窗口，拖动窗口边缘调整大小。"
        script.textStorage?.addAttributes(script.typingAttributes, range: NSRange(location: 0, length: (script.string as NSString).length))
        script.delegate = self
        scroll.documentView = script
        let stack = NSStackView(views: [controls, speedRow, gapRow, hint, scroll])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            speedRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            gapRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "退出提词器", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); menu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑"); editItem.submenu = editMenu
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = menu
        if let saved = UserDefaults.standard.string(forKey: "script") { script.string = saved }
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        timer = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }
    @objc func toggle() {
        if finished { resetPosition() }
        running.toggle()
        script.isEditable = !running
        play.title = running ? "暂停" : "开始"
        position = scroll.contentView.bounds.origin.y
        previous = ProcessInfo.processInfo.systemUptime
    }
    @objc func resetPosition() {
        running = false; script.isEditable = true; script.isHidden = false
        finished = false; play.title = "开始"; position = 0
        scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView)
    }
    @objc func changeGap() {
        gapLabel.stringValue = "开头留白 \(Int(gap.doubleValue))"
        script.textContainerInset = NSSize(width: 20, height: 22 + gap.doubleValue)
        UserDefaults.standard.set(gap.doubleValue, forKey: "openingGap")
        resetPosition()
    }
    @objc func changeSpeed() { speedLabel.stringValue = "\(Int(speed.doubleValue)) 词/分钟" }
    @objc func changeOpacity(_ sender: NSSlider) { window.alphaValue = sender.doubleValue }
    @objc func changeTop(_ sender: NSButton) { window.level = sender.state == .on ? .floating : .normal }
    func textDidChange(_ notification: Notification) { UserDefaults.standard.set(script.string, forKey: "script") }
    @objc func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(now - previous, 0.1); previous = now
        guard let layout = script.layoutManager, let container = script.textContainer else { return }
        layout.ensureLayout(for: container)
        let height = layout.usedRect(for: container).height
        // A full viewport of trailing space lets even the final line leave the top.
        let documentHeight = height + 2 * script.textContainerInset.height + scroll.contentView.bounds.height
        if abs(script.frame.height - documentHeight) > 0.5 {
            script.setFrameSize(NSSize(width: scroll.contentView.bounds.width, height: documentHeight))
        }
        guard running else { return }
        let words = script.string.split { !$0.isLetter && !$0.isNumber }.filter { part in part.contains { $0.isASCII } }.count
        let chinese = script.string.unicodeScalars.filter { (0x3400...0x9FFF).contains(Int($0.value)) }.count
        let units = max(Double(words) + Double(chinese) * 140.0 / 300.0, 1)
        let pixelsPerSecond = Double(height) / units * speed.doubleValue / 60.0
        let maxY = max(0, script.frame.height - scroll.contentView.bounds.height)
        position = min(position + CGFloat(elapsed * pixelsPerSecond), maxY)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: position))
        scroll.reflectScrolledClipView(scroll.contentView)
        if position >= maxY { running = false; finished = true; script.isEditable = true; play.title = "开始" }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Prompter()
app.delegate = delegate
app.run()
