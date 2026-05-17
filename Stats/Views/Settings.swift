//
//  Settings.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 12/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public extension NSToolbarItem.Identifier {
    static let closeApplicationButton = NSToolbarItem.Identifier("closeApplicationButton")
}

class SettingsWindow: NSWindow, NSWindowDelegate, NSToolbarDelegate {
    private static let size: CGSize = CGSize(width: 720, height: 480)
    private static let frameAutosaveName = "eu.exelban.Stats.Settings.WindowFrame"

    internal var onClose: (() -> Void)?

    private let mainView: MainView = MainView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
    private var memoryPageSettings: ApplicationSettings = ApplicationSettings()

    private var closeIcon: NSImage { iconFromSymbol(name: "power", scale: .large) }

    init() {
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - SettingsWindow.size.width,
                y: NSScreen.main!.frame.height - SettingsWindow.size.height,
                width: SettingsWindow.size.width,
                height: SettingsWindow.size.height
            ),
            styleMask: [.closable, .titled, .miniaturizable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        let mainVC: NSViewController = NSViewController(nibName: nil, bundle: nil)
        mainVC.view = self.mainView

        let newToolbar = NSToolbar(identifier: "eu.exelban.Stats.Settings.Toolbar")
        newToolbar.allowsUserCustomization = false
        newToolbar.autosavesConfiguration = true
        newToolbar.displayMode = .iconOnly
        newToolbar.showsBaselineSeparator = true
        newToolbar.delegate = self

        self.toolbar = newToolbar
        self.contentViewController = mainVC
        self.titlebarAppearsTransparent = true
        if #unavailable(macOS 26.0) {
            self.backgroundColor = .clear
        }
        self.isRestorable = true
        self.isReleasedWhenClosed = false
        self.delegate = self
        self.setFrameAutosaveName(SettingsWindow.frameAutosaveName)
        if !self.setFrameUsingName(SettingsWindow.frameAutosaveName) {
            self.positionCenter()
        }
        self.setIsVisible(false)
        self.minSize = NSSize(width: SettingsWindow.size.width, height: SettingsWindow.size.height-Constants.Popup.headerHeight)

        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
    }

    func windowWillClose(_ notification: Notification) {
        let onClose = self.onClose
        DispatchQueue.main.async {
            onClose?()
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == NSEvent.EventType.keyDown && event.modifierFlags.contains(.command) {
            if event.keyCode == 12 || event.keyCode == 13 {
                self.setIsVisible(false)
                return true
            } else if event.keyCode == 46 {
                self.miniaturize(event)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func mouseUp(with: NSEvent) {
        NotificationCenter.default.post(name: .clickInSettings, object: nil, userInfo: nil)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .closeApplicationButton:
            return self.toolbarItem(
                itemIdentifier: itemIdentifier,
                title: localizedString("Close application"),
                tooltip: localizedString("Close application"),
                image: self.closeIcon,
                action: #selector(closeApp(_:))
            )
        default:
            return nil
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .closeApplicationButton]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .closeApplicationButton]
    }

    internal func open(module: String? = nil) {
        if !self.isVisible {
            self.setIsVisible(true)
            self.makeKeyAndOrderFront(nil)
        }
        if !self.isKeyWindow {
            self.orderFrontRegardless()
        }

        self.openMemorySettings()
    }

    internal func setModules() {
        self.configureMemorySettingsTab()
        self.openMemorySettings()
        if modules.filter({ $0.enabled != false && $0.available != false && !$0.menuBar.widgets.filter({ $0.isActive }).isEmpty }).isEmpty {
            self.setIsVisible(true)
        }
    }

    private func toolbarItem(itemIdentifier: NSToolbarItem.Identifier, title: String, tooltip: String, image: NSImage, action: Selector) -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.label = title
        toolbarItem.paletteLabel = title
        toolbarItem.toolTip = tooltip
        toolbarItem.image = image
        toolbarItem.target = self
        toolbarItem.action = action
        return toolbarItem
    }

    @objc private func closeApp(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func openMemorySettings() {
        guard let ramModule = modules.first(where: { $0.config.name == "RAM" }), let view = ramModule.window else { return }

        self.configureMemorySettingsTab()
        self.title = "MemoryBar"
        self.mainView.setView(view)
        NotificationCenter.default.post(name: .openWindow, object: nil, userInfo: ["module": ramModule.config.name, "state": true])
    }

    private func configureMemorySettingsTab() {
        guard let ramWindow = modules.first(where: { $0.config.name == "RAM" })?.window else { return }

        ramWindow.setApplicationSettingsView(self.memoryPageSettings) { [weak self] in
            self?.memoryPageSettings.viewWillAppear()
        }
    }

    private func positionCenter() {
        self.setFrameOrigin(NSPoint(
            x: (NSScreen.main!.frame.width - SettingsWindow.size.width)/2,
            y: ((NSScreen.main!.frame.height - SettingsWindow.size.height)/1.75)
        ))
    }
}

// MARK: - MainView

private class MainView: NSView {
    fileprivate let container: NSStackView = NSStackView()

    private let background: NSVisualEffectView = {
        let view = NSVisualEffectView(frame: NSRect.zero)
        view.blendingMode = .withinWindow
        view.material = .contentBackground
        view.state = .active
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }()

    override init(frame: NSRect) {
        super.init(frame: NSRect.zero)

        self.translatesAutoresizingMaskIntoConstraints = false
        self.container.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.background, positioned: .below, relativeTo: .none)
        self.addSubview(self.container)

        NSLayoutConstraint.activate([
            self.background.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.background.trailingAnchor.constraint(equalTo: trailingAnchor),
            self.background.topAnchor.constraint(equalTo: topAnchor),
            self.background.bottomAnchor.constraint(equalTo: bottomAnchor),

            self.container.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.container.trailingAnchor.constraint(equalTo: trailingAnchor),
            self.container.topAnchor.constraint(equalTo: topAnchor, constant: Constants.Popup.headerHeight*1.4),
            self.container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setView(_ view: NSView) {
        if self.container.arrangedSubviews.first === view {
            return
        }

        self.container.subviews.forEach{ $0.removeFromSuperview() }
        self.container.addArrangedSubview(view)

        NSLayoutConstraint.activate([
            view.leftAnchor.constraint(equalTo: self.container.leftAnchor),
            view.rightAnchor.constraint(equalTo: self.container.rightAnchor),
            view.topAnchor.constraint(equalTo: self.container.topAnchor),
            view.bottomAnchor.constraint(equalTo: self.container.bottomAnchor)
        ])
    }
}
