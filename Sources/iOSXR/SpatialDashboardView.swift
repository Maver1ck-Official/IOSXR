import ARKit
import RealityKit
import SwiftUI
import UIKit
import Vision

struct SpatialDashboardView: View {
    let isActive: Bool
    let onNavigate: (AppTab) -> Void
    @StateObject private var compass = CompassHeadingService()

    var body: some View {
        ZStack(alignment: .top) {
            SpatialARView(isActive: isActive) { name in
                switch name {
                case "store":
                    onNavigate(.store)
                case "library":
                    onNavigate(.library)
                case "browser":
                    onNavigate(.browser)
                default:
                    break
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("iOSXR")
                    .font(.largeTitle.bold())
                Text(compass.headingDegrees.map {
                    String(format: "%@ · %.0f°", compass.status, $0)
                } ?? compass.status)
                    .font(.callout)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.top, 20)
            .allowsHitTesting(false)

            if !ARWorldTrackingConfiguration.isSupported {
                ContentUnavailableView(
                    "AR Tracking Is Not Supported",
                    systemImage: "viewfinder",
                    description: Text("This device does not support ARKit world tracking.")
                )
                .padding(.top, 110)
            }

            HStack(spacing: 20) {
                navigationButton("Store", symbol: "bag", tab: .store)
                navigationButton("Library", symbol: "square.stack.3d.up", tab: .library)
                navigationButton("Browser", symbol: "safari", tab: .browser)
            }
            .padding(12)
            .background(.regularMaterial, in: Capsule())
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 76)
        }
        .onAppear {
            if isActive {
                compass.start()
            }
        }
        .onChange(of: isActive) { active in
            if active {
                compass.start()
            } else {
                compass.stop()
            }
        }
        .onDisappear(perform: compass.stop)
    }

    private func navigationButton(_ title: String, symbol: String, tab: AppTab) -> some View {
        Button {
            onNavigate(tab)
        } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.plain)
    }
}

private struct SpatialARView: UIViewRepresentable {
    let isActive: Bool
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        context.coordinator.arView = view
        context.coordinator.installDashboard(in: view)

        guard ARWorldTrackingConfiguration.isSupported else {
            return view
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        view.session.delegate = context.coordinator
        context.coordinator.configuration = configuration
        context.coordinator.setActive(isActive)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        var onSelect: (String) -> Void
        var configuration: ARWorldTrackingConfiguration?
        private var isActive = false
        private let visionQueue = DispatchQueue(label: "com.iosxr.hand-pose")
        private let frameGate = DispatchSemaphore(value: 1)
        private var pinchWasActive = false

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        func setActive(_ active: Bool) {
            guard active != isActive else { return }
            isActive = active
            guard let arView else { return }

            if active, let configuration {
                arView.session.run(configuration)
            } else {
                arView.session.pause()
            }
        }

        func installDashboard(in view: ARView) {
            let anchor = AnchorEntity(.camera)
            let panelDefinitions: [(String, SIMD3<Float>, UIColor)] = [
                ("store", SIMD3(-0.31, 0, 0), .systemTeal),
                ("library", SIMD3(0, 0, 0), .systemIndigo),
                ("browser", SIMD3(0.31, 0, 0), .systemOrange)
            ]

            for (name, position, color) in panelDefinitions {
                let panel = ModelEntity(
                    mesh: .generateBox(size: SIMD3(0.27, 0.2, 0.025)),
                    materials: [SimpleMaterial(color: color, isMetallic: false)]
                )
                panel.name = name
                panel.position = SIMD3(position.x, position.y, -0.75)
                panel.generateCollisionShapes(recursive: false)
                anchor.addChild(panel)
            }

            view.scene.addAnchor(anchor)
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard frameGate.wait(timeout: .now()) == .success else { return }
            visionQueue.async { [weak self, frameGate] in
                defer { frameGate.signal() }
                guard let self else { return }
                let request = VNDetectHumanHandPoseRequest()
                request.maximumHandCount = 1

                do {
                    try VNImageRequestHandler(
                        cvPixelBuffer: frame.capturedImage,
                        orientation: .up
                    ).perform([request])
                } catch {
                    self.pinchWasActive = false
                    return
                }

                guard
                    let hand = request.results?.first,
                    let thumb = try? hand.recognizedPoint(.thumbTip),
                    let index = try? hand.recognizedPoint(.indexTip),
                    thumb.confidence > 0.5,
                    index.confidence > 0.5
                else {
                    self.pinchWasActive = false
                    return
                }

                let dx = thumb.location.x - index.location.x
                let dy = thumb.location.y - index.location.y
                let isPinching = hypot(dx, dy) < 0.045
                let didBeginPinch = isPinching && !self.pinchWasActive
                self.pinchWasActive = isPinching

                guard didBeginPinch else { return }
                DispatchQueue.main.async { [weak self] in
                    guard
                        let self,
                        let view = self.arView,
                        view.bounds.width > 0,
                        view.bounds.height > 0
                    else {
                        return
                    }

                    let imagePoint = CGPoint(
                        x: index.location.x,
                        y: 1 - index.location.y
                    )
                    let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
                    let screenPoint = imagePoint
                        .applying(frame.displayTransform(
                            for: orientation,
                            viewportSize: view.bounds.size
                        ))
                        .applying(CGAffineTransform(
                            scaleX: view.bounds.width,
                            y: view.bounds.height
                        ))
                    guard let hit = view.hitTest(
                        screenPoint,
                        query: .nearest,
                        mask: .all
                    ).first else {
                        return
                    }
                    self.onSelect(hit.entity.name)
                }
            }
        }
    }
}
