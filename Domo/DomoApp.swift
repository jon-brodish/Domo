//
//  DomoApp.swift
//  Domo
//
//  Created by Jonathan Brodish on 4/12/26.
//

import SwiftUI

@main
struct DomoApp: App {
    @StateObject private var store = HomeStore(
        aiService: BackendProxyAISetupService(
            endpoint: URL(string: "https://black-base-63f7.jon-brodish1.workers.dev/ai/setup")!
        )
    )

    var body: some Scene {
        WindowGroup {
            RootShellView()
                .environmentObject(store)
        }
    }
}
