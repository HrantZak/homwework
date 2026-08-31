import SwiftUI

@main
struct UspevaiApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).preferredColorScheme(store.darkMode ? .dark : .light)
        }
    }
}

