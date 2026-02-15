//
//  quantumApp.swift
//  quantum
//
//  Created by Anh Thai Vo on 15/2/26.
//

import SwiftUI

@main
struct quantumApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color("AccentColor"))
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.zoom(nil)
                    }
                }
        }
    }
}
