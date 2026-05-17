//
//  AppSettings.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 15/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class ApplicationSettings: NSStackView {
    private var temperatureUnitsValue: String {
        get { Store.shared.string(key: "temperature_units", defaultValue: "system") }
        set { Store.shared.set(key: "temperature_units", value: newValue) }
    }
    
    private var startAtLoginBtn: NSSwitch?
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Constants.Settings.width, height: Constants.Settings.height))
        self.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = ScrollableStackView(orientation: .vertical)
        scrollView.stackView.edgeInsets = NSEdgeInsets(
            top: 0,
            left: Constants.Settings.margin,
            bottom: Constants.Settings.margin,
            right: Constants.Settings.margin
        )
        scrollView.stackView.spacing = Constants.Settings.margin
        
        scrollView.stackView.addArrangedSubview(self.informationView())
        
        self.startAtLoginBtn = switchView(
            action: #selector(self.toggleLaunchAtLogin),
            state: LaunchAtLogin.isEnabled
        )
        
        scrollView.stackView.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Temperature"), component: selectView(
                action: #selector(self.toggleTemperatureUnits),
                items: TemperatureUnits,
                selected: self.temperatureUnitsValue
            )),
            PreferencesRow(localizedString("Show icon in dock"), component: switchView(
                action: #selector(self.toggleDock),
                state: Store.shared.bool(key: "dockIcon", defaultValue: false)
            )),
            PreferencesRow(localizedString("Start at login"), component: self.startAtLoginBtn!)
        ]))
        
        scrollView.stackView.addArrangedSubview(PreferencesSection(title: localizedString("Settings"), [
            PreferencesRow(
                localizedString("Export settings"),
                component: buttonView(#selector(self.exportSettings), text: localizedString("Save"))
            ),
            PreferencesRow(
                localizedString("Import settings"),
                component: buttonView(#selector(self.importSettings), text: localizedString("Choose file"))
            ),
            PreferencesRow(
                localizedString("Reset settings"),
                component: buttonView(#selector(self.resetSettings), text: localizedString("Reset"))
            )
        ]))
        
        self.addArrangedSubview(scrollView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func viewWillAppear() {
        self.startAtLoginBtn?.state = LaunchAtLogin.isEnabled ? .on : .off
    }
    
    private func informationView() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: 220).isActive = true
        view.orientation = .vertical
        view.distribution = .fill
        view.alignment = .centerY
        view.spacing = 0
        
        let container: NSGridView = NSGridView()
        container.heightAnchor.constraint(equalToConstant: 180).isActive = true
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let iconView: NSImageView = NSImageView(image: NSImage(named: NSImage.Name("AppIcon"))!)
        
        let statsName: NSTextField = TextView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 22))
        statsName.alignment = .center
        statsName.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        statsName.stringValue = "MemoryBar"
        statsName.isSelectable = true
        
        container.addRow(with: [iconView])
        container.addRow(with: [statsName])
        
        container.row(at: 1).height = 22
        
        view.addArrangedSubview(container)
        
        return view
    }
    
    // MARK: - actions
    
    @objc private func toggleTemperatureUnits(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.temperatureUnitsValue = key
    }
    
    @objc private func toggleDock(_ sender: NSButton) {
        let state = sender.state
        Store.shared.set(key: "dockIcon", value: state == NSControl.StateValue.on)
        let dockIconStatus = state == NSControl.StateValue.on ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
        NSApp.setActivationPolicy(dockIconStatus)
        if state == .off {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        LaunchAtLogin.isEnabled = sender.state == NSControl.StateValue.on
        if !Store.shared.exist(key: "runAtLoginInitialized") {
            Store.shared.set(key: "runAtLoginInitialized", value: true)
        }
    }
    
    @objc private func importSettings() {
        let panel = NSOpenPanel()
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        panel.begin { (result) in
            guard result.rawValue == NSApplication.ModalResponse.OK.rawValue else { return }
            if let url = panel.url {
                Store.shared.import(from: url)
            }
        }
    }
    
    @objc private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MemoryBar.plist"
        panel.showsTagField = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        panel.begin { (result) in
            guard result.rawValue == NSApplication.ModalResponse.OK.rawValue else { return }
            if let url = panel.url {
                Store.shared.export(to: url)
            }
        }
    }
    
    @objc private func resetSettings() {
        let alert = NSAlert()
        alert.messageText = localizedString("Reset settings")
        alert.informativeText = localizedString("Reset settings text")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localizedString("Yes"))
        alert.addButton(withTitle: localizedString("No"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            Store.shared.reset()
            restartApp(self)
        }
    }
    
}
