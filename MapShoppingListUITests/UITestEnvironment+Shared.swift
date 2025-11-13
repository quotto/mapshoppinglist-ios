enum UITestEnvironmentKeys {
    static let scenario = "UITEST_SCENARIO"
    static let locationStatus = "UITEST_LOCATION_STATUS"
    static let notificationStatus = "UITEST_NOTIFICATION_STATUS"
}

enum UITestScenariosShared {
    static let permissionPrompt = "permission_prompt"
    static let placeManagementSeed = "place_management"
}

enum UITestLocationStatusValue {
    static let always = "always"
    static let whenInUse = "when_in_use"
    static let denied = "denied"
}

enum UITestNotificationStatusValue {
    static let authorized = "authorized"
    static let denied = "denied"
}
