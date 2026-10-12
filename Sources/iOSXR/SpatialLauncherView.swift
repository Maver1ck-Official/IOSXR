import SwiftUI
import UIKit

private struct SettingsCategory: Identifiable, Equatable {
    let id: String
    let symbol: String

    static let all: [SettingsCategory] = [
        .init(id: "Search", symbol: "magnifyingglass"),
        .init(id: "My name", symbol: "person.crop.circle"),
        .init(id: "Profiles", symbol: "person.2"),
        .init(id: "Wi-Fi", symbol: "wifi"),
        .init(id: "Bluetooth", symbol: "bluetooth"),
        .init(id: "Devices", symbol: "visionpro"),
        .init(id: "Link", symbol: "link"),
        .init(id: "General", symbol: "slider.horizontal.3"),
        .init(id: "Notifications", symbol: "bell"),
        .init(id: "Environment setup", symbol: "viewfinder"),
    ]
}

private struct SettingsItem: Identifiable {
    enum Accessory {
        case chevron
        case toggle(Bool)
        case value(String)
    }

    let id: String
    let symbol: String
    var accessory: Accessory = .chevron
}

struct SpatialLauncherView: View {
    let heading: String
    let hand: SpatialHandModel
    let handPinch: CGPoint?
    let onOpen: (String) -> Void

    @State private var selectedCategory = "General"
    @State private var searchText = ""
    @State private var settingValues: [String: Bool] = [
        "Cloud backup": true,
        "Virtual keyboard": true,
        "Wi-Fi": true,
        "Bluetooth": true,
        "Notifications": true
    ]
    @State private var detail: SettingsItem?
    @State private var targetFrames: [String: CGRect] = [:]
    @State private var selectedDockItem = "Home"

    private let panelColor = Color(red: 0.105, green: 0.108, blue: 0.115)

    private var items: [SettingsItem] {
        let general = [
            SettingsItem(id: "Software update", symbol: "arrow.down.circle"),
            SettingsItem(id: "Storage", symbol: "externaldrive"),
            SettingsItem(id: "Cloud backup", symbol: "icloud", accessory: .toggle(settingValues["Cloud backup", default: true])),
            SettingsItem(id: "Virtual keyboard", symbol: "keyboard", accessory: .toggle(settingValues["Virtual keyboard", default: true])),
            SettingsItem(id: "Time", symbol: "clock"),
            SettingsItem(id: "Localization", symbol: "globe"),
            SettingsItem(id: "Power", symbol: "power"),
            SettingsItem(id: "About", symbol: "info.circle"),
            SettingsItem(id: "Regulatory information", symbol: "doc.text")
        ]

        switch selectedCategory {
        case "General":
            return general
        case "Wi-Fi":
            return [
                SettingsItem(id: "Wi-Fi", symbol: "wifi", accessory: .toggle(settingValues["Wi-Fi", default: true])),
                SettingsItem(id: "Available networks", symbol: "dot.radiowaves.left.and.right"),
                SettingsItem(id: "Saved networks", symbol: "checkmark.circle")
            ]
        case "Bluetooth":
            return [
                SettingsItem(id: "Bluetooth", symbol: "bluetooth", accessory: .toggle(settingValues["Bluetooth", default: true])),
                SettingsItem(id: "Paired devices", symbol: "headphones"),
                SettingsItem(id: "Pair a new device", symbol: "plus.circle")
            ]
        case "Notifications":
            return [
                SettingsItem(id: "Notifications", symbol: "bell", accessory: .toggle(settingValues["Notifications", default: true])),
                SettingsItem(id: "Do not disturb", symbol: "moon"),
                SettingsItem(id: "App notifications", symbol: "app.badge")
            ]
        case "Search":
            return [
                SettingsItem(id: "Search settings", symbol: "magnifyingglass"),
                SettingsItem(id: "Recent searches", symbol: "clock.arrow.circlepath")
            ]
        case "My name":
            return [
                SettingsItem(id: "Display name", symbol: "person.text.rectangle", accessory: .value("iOSXR user")),
                SettingsItem(id: "Profile picture", symbol: "person.crop.circle"),
                SettingsItem(id: "Account", symbol: "person.badge.key")
            ]
        case "Profiles":
            return [
                SettingsItem(id: "Current profile", symbol: "person.crop.circle", accessory: .value("Personal")),
                SettingsItem(id: "Create profile", symbol: "person.crop.circle.badge.plus"),
                SettingsItem(id: "Profile permissions", symbol: "hand.raised")
            ]
        case "Devices":
            return [
                SettingsItem(id: "Connected devices", symbol: "visionpro"),
                SettingsItem(id: "Pair a device", symbol: "plus.circle"),
                SettingsItem(id: "Hand tracking", symbol: "hand.point.up.left")
            ]
        case "Link":
            return [
                SettingsItem(id: "Connect to a computer", symbol: "link"),
                SettingsItem(id: "Remote display", symbol: "display"),
                SettingsItem(id: "Casting", symbol: "airplayvideo")
            ]
        default:
            return [
                SettingsItem(id: "Scan environment", symbol: "viewfinder"),
                SettingsItem(id: "Room boundary", symbol: "square.dashed"),
                SettingsItem(id: "Reset environment", symbol: "arrow.counterclockwise")
            ]
        }
    }

    private var visibleItems: [SettingsItem] {
        guard selectedCategory == "Search", !searchText.isEmpty else { return items }
        return items.filter { $0.id.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 700
            let panelWidth = min(geometry.size.width - (compact ? 28 : 80), 850)
            let panelHeight = min(geometry.size.height - (compact ? 128 : 112), compact ? 610 : 535)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.22, blue: 0.23).opacity(0.08),
                        Color(red: 0.15, green: 0.15, blue: 0.16).opacity(0.21)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: compact ? 8 : 20)

                    settingsPanel(compact: compact)
                        .frame(width: panelWidth, height: panelHeight)
                        .background {
                            RoundedRectangle(cornerRadius: compact ? 20 : 15, style: .continuous)
                                .fill(panelColor.opacity(0.94))
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: compact ? 20 : 15, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: compact ? 20 : 15, style: .continuous)
                                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.34), radius: 32, x: 0, y: 18)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 20 : 15, style: .continuous))

                    Spacer(minLength: compact ? 10 : 18)

                    appDock(compact: compact)
                        .padding(.bottom, compact ? 12 : 22)
                }
                .padding(.horizontal, compact ? 14 : 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HandSkeletonOverlay(hand: hand)
                    .allowsHitTesting(false)
            }
            .preferredColorScheme(.dark)
            .coordinateSpace(name: "settingsRoot")
            .onPreferenceChange(SettingsTargetFramesKey.self) { targetFrames = $0 }
            .onChange(of: handPinch) { point in
                guard let point else { return }
                let location = CGPoint(
                    x: point.x * geometry.size.width,
                    y: point.y * geometry.size.height
                )
                guard let target = targetFrames.first(where: {
                    $0.value.insetBy(dx: -9, dy: -9).contains(location)
                })?.key else {
                    return
                }
                activate(target)
            }
            .sheet(item: $detail) { item in
                detailSheet(item)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .ignoresSafeArea()
    }

    private func settingsPanel(compact: Bool) -> some View {
        VStack(spacing: 0) {
            if compact {
                compactHeader
                compactCategories
                settingsList(compact: true)
            } else {
                HStack(spacing: 0) {
                    categorySidebar
                        .frame(width: 150)
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 1)
                        .padding(.vertical, 16)
                    VStack(alignment: .leading, spacing: 0) {
                        panelHeader
                        settingsList(compact: false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .background(panelColor.opacity(0.66))
    }

    private var compactHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SETTINGS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.48))
                Text(selectedCategory)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
            }
            Spacer()
            statusIndicators
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var panelHeader: some View {
        HStack(alignment: .center) {
            Text(selectedCategory)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
            Spacer()
            statusIndicators
        }
        .padding(.horizontal, 25)
        .frame(height: 59)
    }

    private var statusIndicators: some View {
        HStack(spacing: 9) {
            Image(systemName: heading.localizedCaseInsensitiveContains("unavailable") ? "location.slash" : "location.north.circle")
            Image(systemName: hand.joints.isEmpty ? "hand.point.up.left" : "hand.point.up.left.fill")
                .foregroundStyle(hand.joints.isEmpty ? .white.opacity(0.55) : .cyan)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.68))
    }

    private var categorySidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(SettingsCategory.all) { category in
                categoryButton(category)
            }
            Spacer(minLength: 0)
            Text(heading)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
    }

    private var compactCategories: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(SettingsCategory.all) { category in
                    Button {
                        select(category.id)
                    } label: {
                        Label(category.id, systemImage: category.symbol)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedCategory == category.id ? .white : .white.opacity(0.68))
                            .background {
                                Capsule()
                                    .fill(selectedCategory == category.id ? .white.opacity(0.16) : .white.opacity(0.055))
                            }
                    }
                    .buttonStyle(.plain)
                    .settingsTarget("category:\(category.id)")
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func categoryButton(_ category: SettingsCategory) -> some View {
        let selected = selectedCategory == category.id
        return Button {
            select(category.id)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: category.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14)
                Text(category.id)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? .black.opacity(0.9) : .white.opacity(0.72))
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.95))
                }
            }
        }
        .buttonStyle(.plain)
        .settingsTarget("category:\(category.id)")
        .accessibilityLabel(category.id)
    }

    private func settingsList(compact: Bool) -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if selectedCategory == "Search" {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("Search settings", text: $searchText)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 37)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 7)
                }

                ForEach(visibleItems) { item in
                    settingsRow(item, compact: compact)
                }
            }
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 5 : 7)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func settingsRow(_ item: SettingsItem, compact: Bool) -> some View {
        if case .toggle = item.accessory {
            HStack(spacing: 10) {
                settingsRowLabel(item, compact: compact)
                Toggle(item.id, isOn: Binding(
                    get: { settingValues[item.id, default: false] },
                    set: { settingValues[item.id] = $0 }
                ))
                .labelsHidden()
                .scaleEffect(0.72, anchor: .trailing)
                .tint(.green)
            }
            .padding(.horizontal, 11)
            .frame(height: compact ? 42 : 35)
            .settingsTarget("setting:\(item.id)")
            .accessibilityLabel(item.id)
        } else {
            Button {
                activate("setting:\(item.id)")
            } label: {
                HStack(spacing: 10) {
                    settingsRowLabel(item, compact: compact)
                    accessoryView(for: item)
                }
                .padding(.horizontal, 11)
                .frame(height: compact ? 42 : 35)
                .background(.white.opacity(0.001))
                .contentShape(Rectangle())
            }
            .buttonStyle(SettingsRowButtonStyle())
            .settingsTarget("setting:\(item.id)")
            .accessibilityLabel(item.id)
        }
    }

    private func settingsRowLabel(_ item: SettingsItem, compact: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 16)
            Text(item.id)
                .font(.system(size: compact ? 12 : 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
    }

    @ViewBuilder
    private func accessoryView(for item: SettingsItem) -> some View {
        switch item.accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.53))
        case .toggle:
            EmptyView()
        case let .value(value):
            HStack(spacing: 7) {
                Text(value)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.54))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func appDock(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 11) {
            dockButton("person.crop.circle.fill", title: "Profile", destination: nil, colors: [.white.opacity(0.4), .white.opacity(0.16)])
            dockButton("house.fill", title: "Home", destination: "home", colors: [.white.opacity(0.19), .white.opacity(0.1)])
            dockButton("safari.fill", title: "Browser", destination: "browser", colors: [.cyan, .blue])
            dockButton("bag.fill", title: "Store", destination: "store", colors: [.orange, .pink])
            dockButton("square.stack.3d.up.fill", title: "Library", destination: "library", colors: [.purple, .indigo])
            dockButton("bubble.left.and.bubble.right.fill", title: "Messages", destination: nil, colors: [.pink, .purple])
            dockButton("gamecontroller.fill", title: "Games", destination: "store", colors: [.green, .teal])
            dockButton("square.grid.2x2.fill", title: "Apps", destination: "library", colors: [.white.opacity(0.3), .white.opacity(0.14)])
        }
        .padding(.horizontal, compact ? 12 : 17)
        .padding(.vertical, compact ? 9 : 10)
        .background {
            Capsule()
                .fill(Color(red: 0.10, green: 0.11, blue: 0.13).opacity(0.9))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.19), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 19, x: 0, y: 8)
        }
    }

    private func dockButton(
        _ symbol: String,
        title: String,
        destination: String?,
        colors: [Color]
    ) -> some View {
        Button {
            selectedDockItem = title
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if let destination {
                if destination != "home" {
                    onOpen(destination)
                } else {
                    select("General")
                }
            } else {
                detail = SettingsItem(id: title, symbol: symbol)
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.27), lineWidth: 0.7))
                .padding(3)
                .background(selectedDockItem == title ? .white.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .settingsTarget("dock:\(title)")
        .accessibilityLabel(title)
    }

    private func detailSheet(_ item: SettingsItem) -> some View {
        VStack(spacing: 15) {
            Image(systemName: item.symbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.cyan)
                .padding(18)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 19))
            Text(item.id)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(detailDescription(for: item.id))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Done") { detail = nil }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .padding(.top, 3)
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.075, green: 0.08, blue: 0.095))
        .preferredColorScheme(.dark)
    }

    private func detailDescription(for title: String) -> String {
        switch title {
        case "Storage":
            return "Manage space used by installed experiences and saved content."
        case "Software update":
            return "Your iOSXR environment is up to date."
        case "Time":
            return "Time and date use your iPhone's current system settings."
        case "Localization":
            return "Language and region follow your iPhone's current system settings."
        case "Power":
            return "Battery and performance information for this device."
        case "About":
            return "iOSXR is a spatial interface running safely inside its iPhone app."
        case "Browser":
            return "Open the built-in web browser."
        case "Store":
            return "Discover community-made spatial experiences."
        default:
            return "\(title) settings for your iOSXR environment."
        }
    }

    private func select(_ category: String) {
        selectedCategory = category
        searchText = ""
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func activate(_ target: String) {
        if target.hasPrefix("category:") {
            select(String(target.dropFirst("category:".count)))
        } else if target.hasPrefix("dock:") {
            let name = String(target.dropFirst("dock:".count))
            selectedDockItem = name
            switch name {
            case "Home": select("General")
            case "Browser": onOpen("browser")
            case "Store", "Games": onOpen("store")
            case "Library", "Apps": onOpen("library")
            default: detail = SettingsItem(id: name, symbol: "person.crop.circle")
            }
        } else if target.hasPrefix("setting:") {
            let name = String(target.dropFirst("setting:".count))
            if settingValues[name] != nil {
                settingValues[name]?.toggle()
                UISelectionFeedbackGenerator().selectionChanged()
            } else {
                let item = items.first { $0.id == name }
                detail = item ?? SettingsItem(id: name, symbol: "slider.horizontal.3")
            }
        }
    }
}

private struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.1 : 0))
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct SettingsTargetFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private extension View {
    func settingsTarget(_ identifier: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SettingsTargetFramesKey.self,
                    value: [identifier: proxy.frame(in: .named("settingsRoot"))]
                )
            }
        }
    }
}

struct SpatialHandModel {
    var joints: [CGPoint] = []
    var bones: [(CGPoint, CGPoint)] = []
    var pinchPoint: CGPoint?
    var isPinching = false

    static let empty = SpatialHandModel()
}

struct HandSkeletonOverlay: View {
    let hand: SpatialHandModel

    private let boneColor = Color(red: 0.45, green: 0.94, blue: 0.91)

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for (start, end) in hand.bones {
                    let path = Path { path in
                        path.move(to: screenPoint(start, in: size))
                        path.addLine(to: screenPoint(end, in: size))
                    }
                    context.stroke(
                        path,
                        with: .color(boneColor.opacity(0.88)),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    context.stroke(
                        path,
                        with: .color(boneColor.opacity(0.25)),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                }

                for joint in hand.joints {
                    let point = screenPoint(joint, in: size)
                    let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.92)))
                }

                if let cursor = hand.pinchPoint {
                    let point = screenPoint(cursor, in: size)
                    let halo = CGRect(x: point.x - 17, y: point.y - 17, width: 34, height: 34)
                    let dot = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                    context.stroke(
                        Path(ellipseIn: halo),
                        with: .color(hand.isPinching ? Color.cyan : .white.opacity(0.9)),
                        lineWidth: 2
                    )
                    context.fill(
                        Path(ellipseIn: dot),
                        with: .color(hand.isPinching ? Color.cyan : .white)
                    )
                }
            }
            .accessibilityHidden(true)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private func screenPoint(_ normalizedPoint: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalizedPoint.x * size.width, y: normalizedPoint.y * size.height)
    }
}
