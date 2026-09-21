//
//  x3f_convertApp.swift
//  X3Fuse
//
//  Created by Sang Lee on 7/8/25.
//

import SwiftUI

@main
struct x3f_convertApp: App {
    @StateObject private var updaterService = UpdaterService.shared
    
    init() {
        // Configure Sparkle on app launch
        Task { @MainActor in
            UpdaterService.shared.configureSparkle()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(updaterService)
                // Files from Finder ("Open With", Dock drops) and x3fuse:// URLs from the
                // Finder Quick Action. Without the handlesExternalEvents preference macOS
                // opens a fresh window for every URL instead of reusing this one.
                .onOpenURL { url in
                    ExternalOpenService.shared.handle(url)
                }
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        }
        .commands {
            MenuCommands()
        }
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
                .environmentObject(updaterService)
                .frame(width: 450, height: 700)
        }
    }
}
