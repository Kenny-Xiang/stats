//
//  helpers.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 13/07/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

extension AppDelegate {
    internal func parseArguments() {
        let args = CommandLine.arguments
        
        if args.contains("--reset") {
            debug("Receive --reset argument. Resetting store (UserDefaults)...")
            Store.shared.reset()
        }
        
        if let disableIndex = args.firstIndex(of: "--disable") {
            if args.indices.contains(disableIndex+1) {
                let disableModules = args[disableIndex+1].split(separator: ",")
                
                disableModules.forEach { (moduleName: Substring) in
                    if let module = modules.first(where: { $0.config.name.lowercased() == moduleName.lowercased()}) {
                        module.unmount()
                    }
                }
            }
        }
        
        if let mountIndex = args.firstIndex(of: "--mount-path") {
            if args.indices.contains(mountIndex+1) {
                let mountPath = args[mountIndex+1]
                let tmp = NSTemporaryDirectory()
                let stdTmp = (tmp as NSString).standardizingPath
                let stdMount = (mountPath as NSString).standardizingPath
                let inTmp = stdMount.hasPrefix(stdTmp) || stdMount.hasPrefix("/private/tmp/") || stdMount.hasPrefix("/tmp/")
                if inTmp, !stdMount.contains("..") {
                    let detach = Process()
                    detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    detach.arguments = ["detach", mountPath, "-force"]
                    try? detach.run()
                    detach.waitUntilExit()
                    try? FileManager.default.removeItem(atPath: mountPath)
                    
                    debug("DMG was unmounted and mountPath deleted")
                } else {
                    debug("rejected --mount-path outside tmp: \(mountPath)")
                }
            }
        }
        
        if let dmgIndex = args.firstIndex(of: "--dmg-path") {
            if args.indices.contains(dmgIndex+1) {
                let dmgPath = args[dmgIndex+1]
                let stdDmg = (dmgPath as NSString).standardizingPath
                let downloads = (try? FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false).path) ?? ""
                let inDownloads = downloads.isEmpty || stdDmg.hasPrefix(downloads)
                if stdDmg.hasSuffix(".dmg"), !stdDmg.contains(".."), inDownloads {
                    try? FileManager.default.removeItem(atPath: dmgPath)
                    debug("DMG was deleted")
                } else {
                    debug("rejected --dmg-path: \(dmgPath)")
                }
            }
        }
    }
    
    internal func parseVersion() {
        let key = "version"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
        if !Store.shared.exist(key: key) {
            Store.shared.reset()
            debug("Previous version not detected. Current version (\(currentVersion) set")
        } else {
            let prevVersion = Store.shared.string(key: key, defaultValue: "")
            if prevVersion == currentVersion {
                return
            }
            debug("Detected previous version \(prevVersion). Current version (\(currentVersion) set")
        }
        
        Store.shared.set(key: key, value: currentVersion)
    }
    
    internal func defaultValues() {
        if Store.shared.exist(key: "runAtLoginInitialized") {
            LaunchAtLogin.migrate()
        }
        
        if Store.shared.exist(key: "dockIcon") {
            let dockIconStatus = Store.shared.bool(key: "dockIcon", defaultValue: false) ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
            NSApp.setActivationPolicy(dockIconStatus)
        }
    }
    
    internal func setup(completion: @escaping () -> Void) {
        if Store.shared.exist(key: "setupProcess") || Store.shared.exist(key: "runAtLoginInitialized") {
            completion()
            return
        }
        
        debug("showing the setup window")
        
        let window = self.ensureSetupWindow()
        window.show()
        window.finishHandler = {
            debug("setup is finished, starting the app")
            completion()
        }
        Store.shared.set(key: "setupProcess", value: true)
    }
    
    @objc internal func openSettings() {
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": "RAM"])
    }
    
    internal func handleKeyEvent(_ event: NSEvent) {
        var keyCodes: [UInt16] = []
        if event.modifierFlags.contains(.control) { keyCodes.append(59) }
        if event.modifierFlags.contains(.shift) { keyCodes.append(60) }
        if event.modifierFlags.contains(.command) { keyCodes.append(55) }
        if event.modifierFlags.contains(.option) { keyCodes.append(58) }
        keyCodes.append(event.keyCode)
        
        guard !keyCodes.isEmpty,
              let module = modules.first(where: { $0.enabled && $0.popupKeyboardShortcut == keyCodes }),
              let widget = module.menuBar.widgets.filter({ $0.isActive }).first,
              let window = widget.item.window else { return }
        
        NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
            "module": module.name,
            "widget": widget.type,
            "origin": window.frame.origin,
            "center": window.frame.width/2
        ])
    }
}
