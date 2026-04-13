//
//  DomoApp.swift
//  Domo
//
//  Created by Jonathan Brodish on 4/12/26.
//

import SwiftUI

@main
struct DomoApp: App {
    @StateObject private var store = HomeStore(aiService: MockAISetupService())

    var body: some Scene {
        WindowGroup {
            RootShellView()
                .environmentObject(store)
        }
    }
}
