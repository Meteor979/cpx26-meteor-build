import SwiftUI

@main
struct WearWiseApp: App {
    @StateObject private var garmentStore = GarmentStore()
    @StateObject private var planStore = SavedPlanStore()
    @StateObject private var weatherStore = WeatherContextStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(garmentStore)
                .environmentObject(planStore)
                .environmentObject(weatherStore)
                .tint(.wearWiseInk)
        }
    }
}
