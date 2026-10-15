import SwiftUI

@main
struct GeoKameraApp: App {
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)
        }
    }
}
