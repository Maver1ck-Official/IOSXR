import ARKit
import ImageIO
import RealityKit
import SwiftUI
import UIKit
import Vision

struct SpatialDashboardView: View {
    let isActive: Bool
    let onNavigate: (AppTab) -> Void
    @StateObject private var compass = CompassHeadingService()
    @State private var handPose = SpatialHandModel.empty
    @State private var handPinch: CGPoint?

    var body: some View {
        ZStack {
            if isActive {
                SpatialARView(
                    isActive: true,
                    onPinch: { point in
                        handPinch = point
                    },
                    onHandPose: {
                        handPose = $0
                        if !$0.isPinching {
                            handPinch = nil
                        }
                    }
                )
                .ignoresSafeArea()
                .blur(radius: 2.5)
                .overlay(Color.white.opacity(0.16))
            } else {
                Color.black.ignoresSafeArea()
            }

            SpatialLauncherView(
                heading: compass.headingDegrees.map {
                    String(format: "%@ · %.0f°", compass.status, $0)
                } ?? compass.status,
                hand: handPose,
                handPinch: handPinch,
                onOpen: { destination in
                    switch destination {
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
            )

            if !ARWorldTrackingConfiguration.isSupported {
                VStack {
                    Spacer()
                    Label("AR unavailable · touch controls still work", systemImage: "viewfinder")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            if isActive {
                compass.start()
            }
        }
        .onChange(of: isActive) { active in
            if active {
                handPose = .empty
                handPinch = nil
                compass.start()
            } else {
                compass.stop()
            }
        }
        .onDisappear(perform: compass.stop)
    }
}

private struct SpatialARView: UIViewRepresentable {
    let isActive: Bool
    let onPinch: (CGPoint) -> Void
    let onHandPose: (SpatialHandModel) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPinch: onPinch, onHandPose: onHandPose)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        context.coordinator.arView = view
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
        context.coordinator.onPinch = onPinch
        context.coordinator.onHandPose = onHandPose
        context.coordinator.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        var onPinch: (CGPoint) -> Void
        var onHandPose: (SpatialHandModel) -> Void
        var configuration: ARWorldTrackingConfiguration?
        private var isActive = false
        private let visionQueue = DispatchQueue(label: "com.iosxr.hand-pose")
        private let frameGate = DispatchSemaphore(value: 1)
        private var pinchWasActive = false
        private var lastDetectionTime = CACurrentMediaTime()

        init(
            onPinch: @escaping (CGPoint) -> Void,
            onHandPose: @escaping (SpatialHandModel) -> Void
        ) {
            self.onPinch = onPinch
            self.onHandPose = onHandPose
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

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard CACurrentMediaTime() - lastDetectionTime >= 1.0 / 12.0 else { return }
            guard frameGate.wait(timeout: .now()) == .success else { return }
            lastDetectionTime = CACurrentMediaTime()
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
                    DispatchQueue.main.async { [weak self] in
                        self?.onHandPose(.empty)
                    }
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
                    DispatchQueue.main.async { [weak self] in
                        self?.onHandPose(.empty)
                    }
                    return
                }

                let dx = thumb.location.x - index.location.x
                let dy = thumb.location.y - index.location.y
                let isPinching = hypot(dx, dy) < 0.045
                let didBeginPinch = isPinching && !self.pinchWasActive
                self.pinchWasActive = isPinching
                let recognizedJoints = try? hand.recognizedPoints(.all)
                let bones = Self.bonePairs.compactMap { pair -> (CGPoint, CGPoint)? in
                    let (first, second) = pair
                    guard
                        let a = recognizedJoints?[first],
                        let b = recognizedJoints?[second],
                        a.confidence > 0.25,
                        b.confidence > 0.25
                    else {
                        return nil
                    }
                    return (a.location, b.location)
                }
                let visibleJoints = Self.jointNames.compactMap { joint -> CGPoint? in
                    guard
                        let point = recognizedJoints?[joint],
                        point.confidence > 0.25
                    else {
                        return nil
                    }
                    return point.location
                }

                DispatchQueue.main.async { [weak self] in
                    guard
                        let self,
                        let view = self.arView,
                        view.bounds.width > 0,
                        view.bounds.height > 0
                    else {
                        return
                    }

                    let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
                    let transform = frame.displayTransform(
                        for: orientation,
                        viewportSize: view.bounds.size
                    )
                    func displayPoint(_ point: CGPoint) -> CGPoint {
                        CGPoint(x: point.x, y: 1 - point.y)
                            .applying(transform)
                    }
                    let cursor = displayPoint(index.location)
                    let displayedBones = bones.map {
                        (displayPoint($0.0), displayPoint($0.1))
                    }
                    let displayedJoints = visibleJoints.map(displayPoint)
                    self.onHandPose(SpatialHandModel(
                        joints: displayedJoints,
                        bones: displayedBones,
                        pinchPoint: cursor,
                        isPinching: isPinching
                    ))
                    guard didBeginPinch else { return }
                    self.onPinch(cursor)
                }
            }
        }

        private static let jointNames: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]

        private static let bonePairs: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
            (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
            (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
            (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
            (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip),
            (.indexMCP, .middleMCP), (.middleMCP, .ringMCP), (.ringMCP, .littleMCP)
        ]
    }
}
