import SwiftUI

@main
struct WearWiseApp: App {
    @StateObject private var garmentStore = GarmentStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(garmentStore)
                .tint(.wearWiseInk)
        }
    }
}
