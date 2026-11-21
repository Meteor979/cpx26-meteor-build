import SwiftUI

@main
struct WearWiseApp: App {
    @StateObject private var garmentStore = GarmentStore()
    @StateObject private var planStore = SavedPlanStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(garmentStore)
                .environmentObject(planStore)
                .tint(.wearWiseInk)
        }
    }
}
