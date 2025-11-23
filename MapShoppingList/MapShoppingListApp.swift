//
//  MapShoppingListApp.swift
//  MapShoppingList
//
//  Created by 山田貴彦 on 2025/10/29.
//

import SwiftUI
import CoreLocation

@main
struct MapShoppingListApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var configurationWarning: String?
    private let environment: AppEnvironment

    init() {
        if LaunchArguments.isUITesting {
            environment = Self.makeTestEnvironment(reason: "UITests", useRealMaps: true)
            _configurationWarning = State(initialValue: nil)
        } else if LaunchArguments.isUnitTesting {
            environment = Self.makeTestEnvironment(reason: "UnitTests", useRealMaps: false)
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

    private static func makeTestEnvironment(reason: String, useRealMaps: Bool) -> AppEnvironment {
        let stack = CoreDataStack.makeInMemory()
        let locationManager = NoopLocationPermissionManager(
            status: LaunchArguments.locationAuthorizationOverride ?? .authorizedAlways
        )
        let notificationScheduler = NoopNotificationScheduler(
            status: LaunchArguments.notificationAuthorizationOverride ?? .authorized
        )
        if useRealMaps {
            let mapResult = MapServicesConfigurator.configure()
            AppEnvironment.configureShared(
                stack: stack,
                placesSearchService: mapResult.placesService,
                geocodingService: mapResult.geocodingService,
                geofenceRegistryRepository: NoopGeofenceRegistryRepository(),
                notificationScheduler: notificationScheduler,
                locationPermissionManager: locationManager,
                currentLocationProvider: DefaultCurrentLocationProvider()
            )
        } else {
            AppEnvironment.configureShared(
                stack: stack,
                placesSearchService: UnavailablePlacesSearchService(reason: reason),
                geocodingService: UnavailableGeocodingService(reason: reason),
                geofenceRegistryRepository: NoopGeofenceRegistryRepository(),
                notificationScheduler: notificationScheduler,
                locationPermissionManager: locationManager
            )
        }
        let environment = AppEnvironment.shared
        UITestScenarioSeeder.seedIfNeeded(environment: environment)
        return environment
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
