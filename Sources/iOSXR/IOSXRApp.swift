import SwiftUI

@main
struct IOSXRApp: App {
    @State private var selectedTab = AppTab.launcher

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                SpatialDashboardView(isActive: selectedTab == .launcher) { destination in
                    selectedTab = destination
                }
                .tabItem {
                    Label("Launcher", systemImage: "square.grid.2x2")
                }
                .tag(AppTab.launcher)

                StoreView()
                    .tabItem {
                        Label("Store", systemImage: "bag")
                    }
                    .tag(AppTab.store)

                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "square.stack.3d.up")
                    }
                    .tag(AppTab.library)

                BrowserView()
                    .tabItem {
                        Label("Browser", systemImage: "safari")
                    }
                    .tag(AppTab.browser)
            }
        }
    }
}

enum AppTab: Hashable {
    case launcher
    case store
    case library
    case browser
}

private struct StoreView: View {
    var body: some View {
        ContentUnavailableView(
            "Community Store",
            systemImage: "bag",
            description: Text("Community packages can be installed after a trusted catalog and signing key are configured.")
        )
    }
}
