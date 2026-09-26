//
//  Kit.swift
//  Tests
//
//  Created by Serhiy Mytrovtsiy on 04/07/2026.
//  Using Swift 6.0.
//  Running on macOS 26.5.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
import Kit
import Cocoa
@testable import MemoryBar

class KitTests: XCTestCase {
    #if !MEMORYBAR
    func testIsNewestVersion_release() throws {
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v2.11.0"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v2.11.1"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.1", latestVersion: "v2.11.0"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v2.12.0"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.12.0", latestVersion: "v2.11.5"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v3.0.0"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v3.0.0", latestVersion: "v2.99.99"))
    }
    
    func testIsNewestVersion_beta() throws {
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.11.0-beta1"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0-beta2", latestVersion: "v2.11.0-beta1"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.11.0-beta2"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.11.0"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.10.9"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v2.11.1-beta1"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.11.1-beta1"))
    }
    
    func testIsNewestVersion_malformed() throws {
        XCTAssertFalse(isNewestVersion(currentVersion: "v3", latestVersion: "v3.0.0"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v3", latestVersion: "v3.0.1"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v3.0", latestVersion: "v3.0.0"))
        XCTAssertFalse(isNewestVersion(currentVersion: "", latestVersion: ""))
    }
    #endif
    
    func testUnitsGetReadableSpeed_byte() throws {
        XCTAssertEqual(Units(bytes: 0).getReadableSpeed(base: .byte), "0 KB/s")
        XCTAssertEqual(Units(bytes: 999).getReadableSpeed(base: .byte), "0 KB/s")
        XCTAssertEqual(Units(bytes: 1_000).getReadableSpeed(base: .byte), "1 KB/s")
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .byte), "500 KB/s")
        XCTAssertEqual(Units(bytes: 2_500_000).getReadableSpeed(base: .byte), "2.5 MB/s")
        XCTAssertEqual(Units(bytes: 150_000_000).getReadableSpeed(base: .byte), "150 MB/s")
        XCTAssertEqual(Units(bytes: 2_000_000_000).getReadableSpeed(base: .byte), "2.0 GB/s")
        XCTAssertEqual(Units(bytes: 2_000_000_000_000).getReadableSpeed(base: .byte), "2.0 TB/s")
        XCTAssertEqual(Units(bytes: -5).getReadableSpeed(base: .byte), "0 KB/s")
    }
    
    func testUnitsGetReadableSpeed_bit() throws {
        XCTAssertEqual(Units(bytes: 100).getReadableSpeed(base: .bit), "0 Kb/s")
        XCTAssertEqual(Units(bytes: 50_000).getReadableSpeed(base: .bit), "400 Kb/s")
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .bit), "4.0 Mb/s")
        XCTAssertEqual(Units(bytes: 200_000_000).getReadableSpeed(base: .bit), "1.6 Gb/s")
        XCTAssertEqual(Units(bytes: 200_000_000_000).getReadableSpeed(base: .bit), "1.6 Tb/s")
    }
    
    func testUnitsGetReadableSpeed_fixedUnit() throws {
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .byte, unit: "KB"), "500 KB/s")
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .byte, unit: "MB"), "0.5 MB/s")
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .bit, unit: "MB"), "4 Mb/s")
    }
}

class SettingsWindowTests: XCTestCase {
    @MainActor
    func testReaderVisibilityFollowsSettingsWindowLifecycle() throws {
        guard modules.contains(where: {
            $0.config.name == "RAM" && $0.enabled && $0.available && $0.menuBar.widgets.contains(where: { $0.isActive })
        }) else {
            throw XCTSkip("Hidden settings initialization requires an active RAM widget; do not change user settings for this test.")
        }

        var notifications: [Notification] = []
        let observer = NotificationCenter.default.addObserver(forName: .openWindow, object: nil, queue: nil) {
            if $0.object is SettingsWindow {
                notifications.append($0)
            }
        }
        let window = SettingsWindow()
        defer {
            NotificationCenter.default.removeObserver(observer)
            window.close()
        }

        func assertVisibility(_ states: [Bool], file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(notifications.map { $0.userInfo?["state"] as? Bool }, states.map { Optional($0) }, file: file, line: line)
            XCTAssertEqual(notifications.map { $0.userInfo?["module"] as? String }, states.map { $0 ? "RAM" : nil }, file: file, line: line)
            XCTAssertTrue(notifications.allSatisfy { ($0.object as? SettingsWindow) === window }, file: file, line: line)
        }

        XCTAssertFalse(window.isVisible)
        assertVisibility([])
        window.setModules()
        XCTAssertFalse(window.isVisible)
        assertVisibility([])

        window.open()
        assertVisibility([true])
        window.open()
        assertVisibility([true])

        window.setIsVisible(false)
        assertVisibility([true, false])
        window.setIsVisible(false)
        assertVisibility([true, false])
        window.open()
        assertVisibility([true, false, true])

        // Exercise the real delegate callbacks without waiting for Dock animations.
        window.windowDidMiniaturize(Notification(name: NSWindow.didMiniaturizeNotification, object: window))
        assertVisibility([true, false, true, false])
        window.windowDidMiniaturize(Notification(name: NSWindow.didMiniaturizeNotification, object: window))
        assertVisibility([true, false, true, false])
        window.windowDidDeminiaturize(Notification(name: NSWindow.didDeminiaturizeNotification, object: window))
        assertVisibility([true, false, true, false, true])

        window.close()
        assertVisibility([true, false, true, false, true, false])
        window.open()
        assertVisibility([true, false, true, false, true, false, true])
    }
}
