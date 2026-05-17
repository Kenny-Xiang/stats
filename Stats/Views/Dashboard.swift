//
//  Stats.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 24/12/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class Dashboard: SystemInformationView {
    init() {
        super.init(refreshModuleNames: ["Dashboard"])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
