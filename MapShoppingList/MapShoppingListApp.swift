//
//  MapShoppingListApp.swift
//  MapShoppingList
//
//  Created by 山田貴彦 on 2025/10/29.
//

import SwiftUI
import CoreLocation
import CoreMotion

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
            let mapResult = MapServicesConfigurator.configure()
            let itemCategoryResult = ItemCategoryServicesConfigurator.configure()
            AppEnvironment.configureShared(
                placesSearchService: mapResult.placesService,
                geocodingService: mapResult.geocodingService,
                itemCategoryClassifier: itemCategoryResult.classifier
            )
            environment = AppEnvironment.shared
            _configurationWarning = State(
                initialValue: [mapResult.warningMessage, itemCategoryResult.warningMessage]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
                    .nilIfEmpty
            )
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
                itemCategoryClassifier: UnavailableItemCategoryClassifier(reason: reason),
                geofenceRegistryRepository: NoopGeofenceRegistryRepository(),
                notificationScheduler: notificationScheduler,
                locationPermissionManager: locationManager,
                currentLocationProvider: DefaultCurrentLocationProvider(),
                activityPermissionManager: NoopActivityPermissionManager(
                    status: LaunchArguments.activityAuthorizationOverride ?? .authorized
                ),
                activityMonitor: NoopActivityMonitor(),
                nearbySuggestionTriggerHandler: NoopNearbySuggestionTriggerHandler()
            )
        } else {
            AppEnvironment.configureShared(
                stack: stack,
                placesSearchService: UnavailablePlacesSearchService(reason: reason),
                geocodingService: UnavailableGeocodingService(reason: reason),
                itemCategoryClassifier: UnavailableItemCategoryClassifier(reason: reason),
                geofenceRegistryRepository: NoopGeofenceRegistryRepository(),
                notificationScheduler: notificationScheduler,
                locationPermissionManager: locationManager,
                currentLocationProvider: FixedCurrentLocationProvider(
                    coordinate: PlaceSearchViewModel.fallbackCoordinate
                ),
                activityPermissionManager: NoopActivityPermissionManager(
                    status: LaunchArguments.activityAuthorizationOverride ?? .authorized
                ),
                activityMonitor: NoopActivityMonitor(),
                nearbySuggestionTriggerHandler: NoopNearbySuggestionTriggerHandler()
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
