import SwiftUI
import MapKit
import CoreLocation

struct GlobeView: View {

    var coordinate: CLLocationCoordinate2D?
    var photoService: PhotoMemoryService
    var provinceService: ProvinceHighlightService
    @Binding var flightAnimator: FlightRouteAnimator?
    var footprintMode: Bool = false
    var trackRenderService: TrackRenderService? = nil

    // 足迹模式照片点击回调
    var onPhotoTap: ((String, Date?) -> Void)? = nil

    init(coordinate: CLLocationCoordinate2D?,
         photoService: PhotoMemoryService,
         provinceService: ProvinceHighlightService,
         flightAnimator: Binding<FlightRouteAnimator?> = .constant(nil),
         footprintMode: Bool = false,
         trackRenderService: TrackRenderService? = nil,
         onPhotoTap: ((String, Date?) -> Void)? = nil) {
        self.coordinate = coordinate
        self.photoService = photoService
        self.provinceService = provinceService
        self._flightAnimator = flightAnimator
        self.footprintMode = footprintMode
        self.trackRenderService = trackRenderService
        self.onPhotoTap = onPhotoTap
    }

    var body: some View {
        ZStack {
            if footprintMode {
                // ── 足迹模式：MKMapView，支持6万个照片点复用 + 点击查看照片 ──
                FootprintMapView(
                    photoService: photoService,
                    photoLocationCount: photoService.locations.count,
                    segments: trackRenderService?.manualSegments ?? [],
                    visitedRegions: provinceService.visitedRegions,
                    onPhotoTap: onPhotoTap,
                    userCoordinate: coordinate
                )
                .ignoresSafeArea()
            } else if let animator = flightAnimator, animator.isAnimating {
                // 动画进行时：用独立子视图持有 animator，确保 @Observable 变化驱动重渲染
                AnimatingMapView(
                    animator: animator,
                    coordinate: coordinate,
                    photoService: photoService,
                    provinceService: provinceService
                )
            } else {
                // 无动画时：MKMapView，显示真实GPS照片点 + 省份高亮
                MainMapView(
                    photoService: photoService,
                    photoLocationCount: photoService.locations.count,
                    provinceService: provinceService,
                    coordinate: coordinate,
                    flightAnimator: flightAnimator,
                    initialCamera: initialCameraForMainMap()
                )
                .ignoresSafeArea()
            }
        }
    }

    // 动画结束后继承相机位置，或回到用户位置
    private func initialCameraForMainMap() -> MKMapCamera? {
        if let anim = flightAnimator, let cam = anim.mapCameraPosition.camera {
            return MKMapCamera(
                lookingAtCenter: cam.centerCoordinate,
                fromDistance: cam.distance,
                pitch: cam.pitch,
                heading: cam.heading
            )
        }
        let center = coordinate ?? CLLocationCoordinate2D(latitude: 25, longitude: 110)
        return MKMapCamera(lookingAtCenter: center, fromDistance: 12_000_000, pitch: 0, heading: 0)
    }
}

// MARK: - 动画专用地图子视图（直接持有 @Observable animator，确保变化被追踪）
private struct AnimatingMapView: View {
    // 直接持有 animator（非 optional），SwiftUI 自动订阅其所有 @Observable 属性变化
    var animator: FlightRouteAnimator
    var coordinate: CLLocationCoordinate2D?
    var photoService: PhotoMemoryService
    var provinceService: ProvinceHighlightService

    var body: some View {
        Map(position: Binding(
            get: { animator.mapCameraPosition },
            set: { _ in }
        ), content: {
            // 省份高亮（底层）
            ForEach(provinceService.visitedRegions) { region in
                ForEach(Array(region.polygons.enumerated()), id: \.offset) { _, poly in
                    MapPolygon(coordinates: poly)
                        .foregroundStyle(Color(hex: "#00d4aa").opacity(0.28))
                        .stroke(Color(hex: "#00d4aa").opacity(0.7), lineWidth: 1.2)
                }
            }
            // 用户位置
            if let coord = coordinate {
                Annotation("我在这里", coordinate: coord, anchor: .bottom) {
                    UserLocationDot()
                }
            }



            // 飞行轨迹
            if animator.drawnPoints.count > 1 {
                MapPolyline(coordinates: animator.drawnPoints)
                    .stroke(lineColor, style: StrokeStyle(
                        lineWidth: animator.currentPhase == .enRoute ? 2.5 : 2,
                        lineCap: .round, lineJoin: .round,
                        dash: animator.currentPhase == .enRoute ? [10, 6] : []
                    ))
                MapPolyline(coordinates: animator.drawnPoints)
                    .stroke(lineColor.opacity(0.25),
                            lineWidth: animator.currentPhase == .enRoute ? 10 : 6)
            }

            // 标注
            ForEach(animator.visibleAnnotations) { ann in
                Annotation(ann.label, coordinate: ann.coordinate, anchor: .bottom) {
                    RouteAnnotationView(ann: ann)
                }
            }

            // 交通工具图标
            if let pos = animator.planePosition, animator.currentPhase != .done {
                Annotation("", coordinate: pos, anchor: .center) {
                    PlaneView(heading: animator.planeHeading,
                              phase: animator.currentPhase,
                              transport: animator.transportMode)
                }
            }
        })
        .mapStyle(.hybrid(elevation: .realistic))
        .mapControls { }
    }

    private var lineColor: Color {
        switch animator.currentPhase {
        case .enRoute:             return Color(hex: "#ffffff")
        case .toHub:               return Color(hex: "#5ac8fa")
        case .itineraryDay(let d):
            let c = ["#30d158","#007aff","#af52de","#ff2d55","#ff9f0a","#5ac8fa"]
            return Color(hex: c[d % c.count])
        default:                    return Color(hex: "#ffffff")
        }
    }
}

// MARK: - 3D 飞机视图（SceneKit）
private struct PlaneView: View {
    let heading: Double
    let phase: FlightRouteAnimator.AnimPhase
    let transport: TransportMode

    @State private var glowPulse = false

    var isMoving: Bool { phase == .enRoute || phase == .toHub }

    var body: some View {
        ZStack {
            // 外层光晕
            if isMoving {
                Circle()
                    .fill(Color.white.opacity(glowPulse ? 0.06 : 0.16))
                    .frame(width: glowPulse ? 60 : 44, height: glowPulse ? 60 : 44)
                    .blur(radius: 8)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glowPulse)
            }

            switch transport {
            case .plane:
                Plane3DView(isFlying: isMoving)
                    .frame(width: isMoving ? 54 : 40, height: isMoving ? 54 : 40)
                    .rotationEffect(.degrees(heading - 90))
                    .shadow(color: isMoving ? .white.opacity(0.5) : Color(hex: "#30d158").opacity(0.6),
                            radius: isMoving ? 8 : 5)
            case .train:
                Image(systemName: "tram.fill")
                    .font(.system(size: isMoving ? 30 : 24, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#5ac8fa"), Color(hex: "#007aff")],
                                                   startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(heading - 90))
                    .shadow(color: Color(hex: "#5ac8fa").opacity(0.7), radius: 6)
            case .drive:
                Image(systemName: "car.fill")
                    .font(.system(size: isMoving ? 28 : 22, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#30d158"), Color(hex: "#34c759")],
                                                   startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(heading - 90))
                    .shadow(color: Color(hex: "#30d158").opacity(0.7), radius: 6)
            }
        }
        .onAppear { glowPulse = true }
    }
}

// MARK: - SceneKit 3D 飞机
import SceneKit

private struct Plane3DView: UIViewRepresentable {
    let isFlying: Bool

    // 场景只构建一次，所有实例共享
    private static let sharedScene: SCNScene = buildScene()

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.scene = Self.sharedScene
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let planeNode = view.scene?.rootNode.childNode(withName: "plane", recursively: false)
        if isFlying {
            // 只在没有动画时添加，避免重复叠加
            if planeNode?.animationKeys.isEmpty ?? true {
                let spin = CABasicAnimation(keyPath: "rotation")
                spin.fromValue   = SCNVector4(0, 1, 0, 0)
                spin.toValue     = SCNVector4(0, 1, 0, Float.pi * 2)
                spin.duration    = 8
                spin.repeatCount = .infinity
                planeNode?.addAnimation(spin, forKey: "spin")
            }
        } else {
            planeNode?.removeAnimation(forKey: "spin")
        }
    }

    private static func buildScene() -> SCNScene {
        let scene = SCNScene()

        // 环境光
        let ambient = SCNNode()
        ambient.light = {
            let l = SCNLight(); l.type = .ambient
            l.color = UIColor(white: 0.3, alpha: 1); return l
        }()
        scene.rootNode.addChildNode(ambient)

        // 主光源（模拟阳光）
        let sun = SCNNode()
        sun.light = {
            let l = SCNLight(); l.type = .directional
            l.color = UIColor(red: 1, green: 0.97, blue: 0.9, alpha: 1)
            l.intensity = 1200; return l
        }()
        sun.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/6, 0)
        scene.rootNode.addChildNode(sun)

        // 补光（机腹反光）
        let fill = SCNNode()
        fill.light = {
            let l = SCNLight(); l.type = .directional
            l.color = UIColor(red: 0.6, green: 0.8, blue: 1, alpha: 1)
            l.intensity = 400; return l
        }()
        fill.eulerAngles = SCNVector3(Float.pi/4, -Float.pi/4, 0)
        scene.rootNode.addChildNode(fill)

        // 飞机节点
        let planeNode = SCNNode()
        planeNode.name = "plane"

        // 材质（金属白色机身）
        let mat = SCNMaterial()
        mat.diffuse.contents  = UIColor(white: 0.95, alpha: 1)
        mat.specular.contents = UIColor.white
        mat.metalness.contents = NSNumber(value: 0.7)
        mat.roughness.contents = NSNumber(value: 0.2)
        mat.lightingModel = .physicallyBased

        // 橙色强调材质（发动机/机翼边）
        let accentMat = SCNMaterial()
        accentMat.diffuse.contents  = UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1)
        accentMat.specular.contents = UIColor.white
        accentMat.metalness.contents = NSNumber(value: 0.8)
        accentMat.roughness.contents = NSNumber(value: 0.15)
        accentMat.lightingModel = .physicallyBased

        // ── 机身（细长椭球）──
        let fuselage = SCNNode(geometry: {
            let g = SCNSphere(radius: 0.08)
            g.segmentCount = 24
            g.firstMaterial = mat
            return g
        }())
        fuselage.scale = SCNVector3(4.5, 1, 1)
        planeNode.addChildNode(fuselage)

        // ── 主机翼（两片，薄盒子）──
        for sign in [-1.0, 1.0] {
            let wing = SCNNode(geometry: {
                let g = SCNBox(width: 0.55, height: 0.018, length: 0.18, chamferRadius: 0.004)
                g.firstMaterial = mat; return g
            }())
            wing.position = SCNVector3(0, 0, Float(sign) * 0.24)
            // 后掠翼角度
            wing.eulerAngles = SCNVector3(0, Float(sign) * -0.22, 0)
            planeNode.addChildNode(wing)

            // 翼尖小翼
            let winglet = SCNNode(geometry: {
                let g = SCNBox(width: 0.04, height: 0.06, length: 0.04, chamferRadius: 0.005)
                g.firstMaterial = accentMat; return g
            }())
            winglet.position = SCNVector3(Float(sign) * -0.01, 0.03, Float(sign) * 0.42)
            planeNode.addChildNode(winglet)
        }

        // ── 尾翼（垂直）──
        let vtail = SCNNode(geometry: {
            let g = SCNBox(width: 0.14, height: 0.16, length: 0.014, chamferRadius: 0.003)
            g.firstMaterial = mat; return g
        }())
        vtail.position = SCNVector3(-0.3, 0.09, 0)
        vtail.eulerAngles = SCNVector3(0, 0.15, 0)
        planeNode.addChildNode(vtail)

        // ── 尾翼（水平）──
        for sign in [-1.0, 1.0] {
            let htail = SCNNode(geometry: {
                let g = SCNBox(width: 0.18, height: 0.012, length: 0.07, chamferRadius: 0.003)
                g.firstMaterial = mat; return g
            }())
            htail.position = SCNVector3(-0.3, 0.02, Float(sign) * 0.1)
            htail.eulerAngles = SCNVector3(0, Float(sign) * -0.12, 0)
            planeNode.addChildNode(htail)
        }

        // ── 发动机（2个，挂在机翼下）──
        for sign in [-1.0, 1.0] {
            let eng = SCNNode(geometry: {
                let g = SCNTube(innerRadius: 0.038, outerRadius: 0.052, height: 0.16)
                g.firstMaterial = accentMat; return g
            }())
            eng.position = SCNVector3(0.08, -0.06, Float(sign) * 0.16)
            eng.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            planeNode.addChildNode(eng)
        }

        // ── 驾驶舱（深色玻璃）──
        let cockpitMat = SCNMaterial()
        cockpitMat.diffuse.contents  = UIColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 1)
        cockpitMat.specular.contents = UIColor.white
        cockpitMat.metalness.contents = NSNumber(value: 0.9)
        cockpitMat.roughness.contents = NSNumber(value: 0.05)
        cockpitMat.lightingModel = .physicallyBased

        let cockpit = SCNNode(geometry: {
            let g = SCNSphere(radius: 0.07)
            g.segmentCount = 16
            g.firstMaterial = cockpitMat; return g
        }())
        cockpit.position = SCNVector3(0.32, 0.025, 0)
        cockpit.scale = SCNVector3(1, 0.55, 0.65)
        planeNode.addChildNode(cockpit)

        // 倾斜45°朝向镜头（正面斜视效果更立体）
        planeNode.eulerAngles = SCNVector3(-Float.pi/12, Float.pi/8, Float.pi/14)
        scene.rootNode.addChildNode(planeNode)

        // 相机
        let cam = SCNNode()
        cam.camera = {
            let c = SCNCamera()
            c.fieldOfView = 42
            return c
        }()
        cam.position = SCNVector3(0, 0.3, 1.6)
        cam.eulerAngles = SCNVector3(-0.18, 0, 0)
        scene.rootNode.addChildNode(cam)

        return scene
    }
}

// MARK: - 用户位置圆点
private struct UserLocationDot: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(pulse ? 0.0 : 0.25))
                .frame(width: pulse ? 44 : 24, height: pulse ? 44 : 24)
                .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: pulse)
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .overlay(Circle().fill(Color(hex: "#007aff")).frame(width: 10, height: 10))
                .shadow(color: Color(hex: "#007aff").opacity(0.5), radius: 4)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - 路线标注视图
private struct RouteAnnotationView: View {
    let ann: RouteAnnotation
    @State private var appeared = false

    var body: some View {
        Group {
            switch ann.type {
            case .hub(let icon):
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(ann.color.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(ann.color)
                    }
                    .shadow(color: ann.color.opacity(0.6), radius: 6)
                    Text(ann.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                }

            case .destination:
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(ann.color.opacity(0.25))
                            .frame(width: 44, height: 44)
                            .blur(radius: 4)
                        Circle()
                            .fill(ann.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(ann.color)
                            .shadow(color: ann.color, radius: 8)
                    }
                    Text(ann.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            Capsule().fill(ann.color.opacity(0.85))
                                .shadow(color: ann.color.opacity(0.5), radius: 4)
                        )
                }

            case .waypoint(_):
                ZStack {
                    Circle()
                        .fill(ann.color.opacity(0.3))
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(ann.color)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
                .shadow(color: ann.color.opacity(0.6), radius: 4)
            }
        }
        .scaleEffect(appeared ? 1 : 0.1)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

