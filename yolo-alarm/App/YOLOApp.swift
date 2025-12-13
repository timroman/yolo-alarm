import SwiftUI
import AVFoundation

@main
struct YOLOApp: App {
    @StateObject private var appState = AppState()

    init() {
        print("🚀 YOLO App initializing...")
        print("🚀 YOLO App ready")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    print("🚀 ContentView appeared")
                }
        }
    }
}
