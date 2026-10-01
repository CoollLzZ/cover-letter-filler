import SwiftUI

@main
struct CoverLetterFillerApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 960, minHeight: 680)
        }
        .defaultSize(width: 1_120, height: 760)
    }
}
