//
//  CCZUHelperLiteApp.swift
//  CCZUHelperLite Watch App
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI

@main
struct CCZUHelperLite_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if canImport(WatchConnectivity)
                    WatchConnectivityReceiver.shared.activate()
                    #endif
                }
        }
    }
}
