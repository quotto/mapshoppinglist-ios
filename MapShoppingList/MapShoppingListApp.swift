//
//  MapShoppingListApp.swift
//  MapShoppingList
//
//  Created by 山田貴彦 on 2025/10/29.
//

import SwiftUI

@main
struct MapShoppingListApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var configurationWarning: String?
    private let environment: AppEnvironment

    init() {
        if LaunchArguments.isUITesting {
            AppEnvironment.configureShared(
                stack: CoreDataStack.makeInMemory(),
                placesSearchService: UnavailablePlacesSearchService(reason: "UITests"),
                geocodingService: UnavailableGeocodingService(reason: "UITests")
            )
            environment = AppEnvironment.shared
            _configurationWarning = State(initialValue: nil)
        } else {
            let result = MapServicesConfigurator.configure()
            AppEnvironment.configureShared(
                placesSearchService: result.placesService,
                geocodingService: result.geocodingService
            )
            environment = AppEnvironment.shared
            _configurationWarning = State(initialValue: result.warningMessage)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(environment: environment)
                .environment(\.appEnvironment, environment)
                .tint(.appPrimary)
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
