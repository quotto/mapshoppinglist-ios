//
//  MapShoppingListApp.swift
//  MapShoppingList
//
//  Created by 山田貴彦 on 2025/10/29.
//

import SwiftUI

@main
struct MapShoppingListApp: App {
    @State private var configurationWarning: String?
    private let environment: AppEnvironment

    init() {
        let result = MapServicesConfigurator.configure()
        environment = AppEnvironment(placesSearchService: result.placesService, geocodingService: result.geocodingService)
        _configurationWarning = State(initialValue: result.warningMessage)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(environment: environment)
                .environment(\.appEnvironment, environment)
                .alert("設定エラー", isPresented: Binding(
                    get: { configurationWarning != nil },
                    set: { if !$0 { configurationWarning = nil } }
                )) {
                    Button("OK", role: .cancel) { configurationWarning = nil }
                } message: {
                    Text(configurationWarning ?? "")
                }
        }
    }
}
