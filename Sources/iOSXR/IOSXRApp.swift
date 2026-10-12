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
            .tint(Color(red: 0.38, green: 0.79, blue: 1))
            .preferredColorScheme(.dark)
            .toolbar(selectedTab == .launcher ? .hidden : .visible, for: .tabBar)
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
    @State private var showingCatalogNotice = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.17, green: 0.29, blue: 0.58),
                                        Color(red: 0.34, green: 0.20, blue: 0.56),
                                        Color(red: 0.12, green: 0.45, blue: 0.52)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Circle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 185, height: 185)
                            .blur(radius: 34)
                            .offset(x: 210, y: -54)

                        VStack(alignment: .leading, spacing: 12) {
                            Label("THE iOSXR STORE", systemImage: "sparkles")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.75))
                            Text("Find your\nnext dimension.")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Community-made spaces, games, and little worlds.")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.75))
                            Button {
                                showingCatalogNotice = true
                            } label: {
                                Label("Explore experiences", systemImage: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.85))
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 10)
                                    .background(.white, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 3)
                        }
                        .padding(25)
                    }
                    .frame(minHeight: 270)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Made for your space")
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                            Text("Only signed, compatible experiences can be installed.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.cyan)
                    }
                    .padding(17)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 19))
                    .overlay {
                        RoundedRectangle(cornerRadius: 19)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    }

                    ContentUnavailableView(
                        "Catalog is getting ready",
                        systemImage: "shippingbox",
                        description: Text("A trusted community catalog will appear here when its signing key is configured.")
                    )
                    .frame(minHeight: 180)
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.035, green: 0.045, blue: 0.075))
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Store setup required", isPresented: $showingCatalogNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Connect a trusted, signed community catalog before enabling downloads.")
            }
        }
    }
}
