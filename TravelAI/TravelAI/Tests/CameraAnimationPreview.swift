import SwiftUI
import MapKit
import Observation

// MARK: - 相机动画预览
// 单一 CADisplayLink 驱动，altitude/pitch/center/heading 全部在同一 tick 里
// 按各自曲线计算，全程无分段衔接，完全连续。

// MARK: - MKMapView 包装
struct AnimatedMapView: UIViewRepresentable {
    let coordinator: FlightCameraCoordinator

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = .hybridFlyover
        map.showsCompass = false
        map.isPitchEnabled = true
        map.isRotateEnabled = true
        coordinator.attach(to: map)
        return map
    }
    func updateUIView(_ uiView: MKMapView, context: Context) {}
}

// MARK: - 单一 DisplayLink 飞行相机
@MainActor
final class FlightCameraCoordinator: NSObject {
    private weak var mapView: MKMapView?
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    var onComplete: (() -> Void)?

    // 路线参数（外部设置）
    var origin:      CLLocationCoordinate2D = .init()
    var destination: CLLocationCoordinate2D = .init()
    var totalDuration: Double = 7.0   // 整段总时长（秒）

    // 相机参数（可调）
    var startAltitude: Double  = 1_500_000   // 出发地初始高度（米）
    var cruiseAltitude: Double = 6_000_000   // 最高巡航高度
    var endAltitude: Double    = 1_500_000   // 目的地落地高度
    var startPitch: Double     = 45          // 出发地 pitch
    var cruisePitch: Double    = 15          // 巡航 pitch（俯视感）
    var endPitch: Double       = 45          // 目的地 pitch

    func attach(to map: MKMapView) {
        self.mapView = map
        // 初始相机
        let cam = MKMapCamera()
        cam.centerCoordinate = origin
        cam.altitude = startAltitude
        cam.pitch    = CGFloat(startPitch)
        cam.heading  = headingBetween(origin, destination)
        map.setCamera(cam, animated: false)
    }

    func start() {
        displayLink?.invalidate()
        let dl = CADisplayLink(target: self, selector: #selector(tick))
        dl.add(to: .main, forMode: .common)
        startTime = CACurrentMediaTime()
        displayLink = dl
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ dl: CADisplayLink) {
        let rawT = min((CACurrentMediaTime() - startTime) / totalDuration, 1.0)

        // ── center/altitude 用 smoothstep(rawT)：起降慢、中间快 ──
        let t = rawT * rawT * (3.0 - 2.0 * rawT)

        // ── center：大圆弧插值，用 eased t ──
        let center = slerp(origin, destination, t: t)

        // ── altitude：半周期 sin 抛物线（0→1→0），用 eased t ──
        let altBlend = sin(t * .pi)
        let altitude = lerp(lerp(startAltitude, endAltitude, t), cruiseAltitude, altBlend)

        // ── pitch：用 sin(rawT×π)，rawT=0→0, 0.5→1, 1→0，完全对称回升 ──
        let pitchBlend = sin(rawT * .pi)
        let edgePitch  = lerp(startPitch, endPitch, rawT)
        let pitch      = lerp(edgePitch, cruisePitch, pitchBlend)

        // ── heading：始终朝飞行方向 ──
        let heading = headingBetween(origin, destination)

        let cam = MKMapCamera()
        cam.centerCoordinate = center
        cam.altitude = altitude
        cam.pitch    = CGFloat(pitch)
        cam.heading  = heading
        mapView?.setCamera(cam, animated: false)

        if rawT >= 1.0 {
            dl.invalidate()
            displayLink = nil
            onComplete?()
        }
    }

    // MARK: - 球面线性插值（SLERP）
    private func slerp(_ a: CLLocationCoordinate2D,
                       _ b: CLLocationCoordinate2D,
                       t: Double) -> CLLocationCoordinate2D {
        let lat1 = a.latitude  * .pi / 180
        let lon1 = a.longitude * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let lon2 = b.longitude * .pi / 180
        let d = 2 * asin(sqrt(
            pow(sin((lat2 - lat1) / 2), 2) +
            cos(lat1) * cos(lat2) * pow(sin((lon2 - lon1) / 2), 2)
        ))
        guard d > 1e-10 else { return a }
        let A = sin((1 - t) * d) / sin(d)
        let B = sin(t * d) / sin(d)
        let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
        let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
        let z = A * sin(lat1)             + B * sin(lat2)
        return CLLocationCoordinate2D(
            latitude:  atan2(z, sqrt(x*x + y*y)) * 180 / .pi,
            longitude: atan2(y, x) * 180 / .pi
        )
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func headingBetween(_ from: CLLocationCoordinate2D,
                                _ to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - 控制器
@Observable @MainActor
final class CamPreviewCtrl {
    let coord = FlightCameraCoordinator()
    var status: String = "点击播放"
    var running = false

    // ── 测试路线（可改）──
    let origin      = CLLocationCoordinate2D(latitude: 39.91, longitude: 116.39)  // 北京
    let destination = CLLocationCoordinate2D(latitude: 25.20, longitude: 55.27)   // 迪拜

    init() {
        let dist = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        coord.origin      = origin
        coord.destination = destination
        coord.totalDuration  = 6.3
        coord.startAltitude  = 1_200_000
        coord.cruiseAltitude = max(dist * 1.1, 6_000_000)
        coord.endAltitude    = 1_200_000
        coord.startPitch     = 50
        coord.cruisePitch    = 10
        coord.endPitch       = 50
    }

    func play() {
        guard !running else { return }
        running = true
        status  = "飞行中…"
        coord.start()
        coord.onComplete = { [weak self] in
            self?.status  = "完成 ✓"
            self?.running = false
        }
    }

}

// MARK: - Preview UI
struct CameraAnimationPreview: View {
    @State private var ctrl = CamPreviewCtrl()

    var body: some View {
        ZStack(alignment: .bottom) {
            AnimatedMapView(coordinator: ctrl.coord)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text(ctrl.status)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())

                HStack(spacing: 12) {
                    Button {
                        ctrl.play()
                    } label: {
                        Text(ctrl.running ? "飞行中…" : "▶ 播放")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28).padding(.vertical, 11)
                            .background(ctrl.running ? Color.gray : Color.blue)
                            .clipShape(Capsule())
                    }
                    .disabled(ctrl.running)
                }
            }
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    CameraAnimationPreview()
}
