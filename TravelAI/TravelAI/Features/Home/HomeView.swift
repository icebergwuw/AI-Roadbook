import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Photos
import Combine

// MARK: - HomeView
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]

    @State private var locationManager = LocationManager()
    @State private var showTripList = false

    @State private var generatingDestination: String? = nil
    @State private var generationProgress: Double = 0
    @State private var generationMessage: String = ""
    @State private var generationDone: Bool = false
    @State private var showDebugLog: Bool = false

    @State private var photoService = PhotoMemoryService()
    @State private var flightAnimator: FlightRouteAnimator? = nil
    @State private var tripVM = NewTripViewModel()
    @State private var generationTask: Task<Void, Never>? = nil   // 追踪当前生成任务，确保可取消

    private var ctrl: TripInputController { TripInputController.shared }

    var body: some View {
        NavigationStack {
            ZStack {
                GlobeView(coordinate: locationManager.coordinate,
                          photoService: photoService,
                          flightAnimator: $flightAnimator)
                    .ignoresSafeArea()

                VStack { topBar; Spacer() }

                if let dest = generatingDestination {
                    VStack {
                        Spacer()
                        generatingFloatCard(destination: dest)
                            .padding(.bottom, 110)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: generatingDestination)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                TravelInputBar(ctrl: ctrl)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .padding(.bottom, 4)
            }
            .onAppear {
                locationManager.requestWhenInUse()
                Task { await photoService.requestAndLoad() }
                registerGenerationHandler()
            }
            .onChange(of: showTripList) { _, showing in
                // sheet 关闭后重新注册，保证回调始终有效
                if !showing { registerGenerationHandler() }
            }
            .sheet(isPresented: $showTripList) { TripListSheet() }
        }
    }

    // MARK: - 注册生成回调（每次 HomeView 出现 / sheet 关闭后都要重新注册）
    private func registerGenerationHandler() {
        ctrl.onStartGeneration = { dest, start, days, style, transport in
            startGeneration(dest: dest, start: start, days: days, style: style, transport: transport)
        }
    }

    // MARK: - 开始生成
    private func startGeneration(dest: String, start: Date, days: Int, style: String, transport: TransportMode) {
        // 取消上一次未完成的生成任务，防止旧任务回调污染新任务状态
        generationTask?.cancel()
        flightAnimator = nil

        let end = Calendar.current.date(byAdding: .day, value: days - 1, to: start) ?? start
        let vm = NewTripViewModel()
        vm.destination = dest
        vm.startDate = start
        vm.endDate = end
        vm.selectedStyle = NewTripViewModel.TravelStyle.allCases
            .first { $0.rawValue == style } ?? .cultural
        tripVM = vm   // 赋值到 @State 保持引用

        vm.onPhaseChanged = { [weak vm] phase in
            guard let vm, !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                generationProgress = min(phase.progress, 1.0)
                generationMessage  = phase.message
            }
            if phase == .done {
                withAnimation { generationDone = true }
                let coords = vm.generatedItineraryCoords
                let animator = flightAnimator
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation { generatingDestination = nil }
                    ctrl.reset()
                    registerGenerationHandler()   // 确保下次生成回调仍然有效
                    if let anim = animator, !coords.isEmpty {
                        await anim.continueWithItinerary(itinerary: coords)
                    }
                }
            }
        }
        vm.onError = { errMsg in
            AILogger.shared.log("生成失败: \(errMsg)", error: true)
            withAnimation { generatingDestination = nil }
            flightAnimator = nil
            ctrl.reset()
            registerGenerationHandler()
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            generatingDestination = dest
            generationProgress = 0
            generationMessage = ""
            generationDone = false
        }

        let origin = locationManager.coordinate
            ?? CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        let animator = FlightRouteAnimator()
        flightAnimator = animator

        Task { await animator.startPreview(origin: origin, destinationName: dest, mode: transport) }

        let ctx = modelContext
        generationTask = Task {
            await vm.generate(context: ctx)
        }
    }

    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            Button { showTripList = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "suitcase.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("我的旅行")
                        .font(.system(size: 13, weight: .semibold))
                    if !trips.isEmpty {
                        Text("\(trips.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
            }
            Spacer()
            Menu {
                NavigationLink(destination: TodayOverviewView(selectedTab: .constant(1))) {
                    Label("今日行程", systemImage: "calendar")
                }
                NavigationLink(destination: ExploreView()) {
                    Label("探索目的地", systemImage: "safari.fill")
                }
                Divider()
                Button {
                    switch photoService.authStatus {
                    case .notDetermined: Task { await photoService.requestAndLoad() }
                    case .denied, .restricted:
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    default: Task { await photoService.loadLocations() }
                    }
                } label: {
                    switch photoService.authStatus {
                    case .notDetermined:
                        Label("开启照片记忆", systemImage: "photo.on.rectangle.angled")
                    case .denied, .restricted:
                        Label("前往设置开启相册", systemImage: "photo.badge.exclamationmark")
                    default:
                        Label(photoService.isLoading ? "加载中…" : "刷新照片(\(photoService.locations.count)张)",
                              systemImage: "arrow.clockwise")
                    }
                }
                NavigationLink(destination: SettingsView()) {
                    Label("设置", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - 生成进度悬浮卡片
    private func generatingFloatCard(destination: String) -> some View {
        let logger = AILogger.shared
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#E8784A").opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: generationDone ? "checkmark.circle.fill" : "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(generationDone ? Color(hex: "#30D158") : Color(hex: "#E8784A"))
                        .symbolEffect(.pulse, isActive: !generationDone)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(destination)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15)).frame(height: 4)
                            Capsule()
                                .fill(generationDone
                                      ? AnyShapeStyle(Color(hex: "#30D158"))
                                      : AnyShapeStyle(LinearGradient(
                                          colors: [Color(hex: "#E8784A"), Color(hex: "#F4A261")],
                                          startPoint: .leading, endPoint: .trailing)))
                                .frame(width: max(4, geo.size.width * generationProgress), height: 4)
                                .animation(.easeInOut(duration: 0.5), value: generationProgress)
                        }
                    }.frame(height: 4)
                    HStack(spacing: 4) {
                        Text(generationDone ? "攻略已生成 ✓"
                             : (generationMessage.isEmpty ? "AI 正在规划…" : generationMessage))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(1)
                        if !generationDone { GenerationTimerLabel() }
                    }
                }
                Spacer()
                Button { withAnimation { showDebugLog.toggle() } } label: {
                    Image(systemName: showDebugLog ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(showDebugLog ? 1 : 0.5))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            if showDebugLog {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(logger.entries) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(entry.time, format: .dateTime.hour().minute().second())
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 60, alignment: .leading)
                                    Text(entry.text)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(entry.isError
                                                         ? Color(hex: "#FF6B6B")
                                                         : Color.white.opacity(0.85))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }.id(entry.id)
                            }
                            if logger.entries.isEmpty {
                                Text("等待请求…")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }.padding(10)
                    }
                    .frame(height: 180)
                    .onChange(of: logger.entries.count) {
                        if let last = logger.entries.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        // 深色固定背景，不受地图颜色影响
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.92))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.4), radius: 16, y: 4)
    }
}

// MARK: - 计时器标签
private struct GenerationTimerLabel: View {
    @State private var seconds = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var hint: String {
        switch seconds {
        case 0..<30:   return "AI 思考中"
        case 30..<60:  return "正在生成"
        case 60..<120: return "内容较多，请稍候"
        default:       return "即将完成"
        }
    }
    var body: some View {
        HStack(spacing: 3) { Text("·"); Text(hint); Text("\(seconds)s").monospacedDigit() }
            .font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
            .onReceive(timer) { _ in seconds += 1 }
    }
}

// MARK: - 行程列表 Sheet
struct TripListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    private var ctrl: TripInputController { TripInputController.shared }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    VStack(spacing: 20) {
                        Text("🗺️").font(.system(size: 52))
                        Text("还没有旅行计划")
                            .font(AppFont.heading(20)).foregroundColor(AppTheme.textPrimary)
                        Text("用 AI 帮你规划一次完美旅行")
                            .font(AppFont.body(14)).foregroundColor(AppTheme.textSecondary)
                        Button {
                            dismiss()
                        } label: {
                            Label("开始规划", systemImage: "sparkles")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28).padding(.vertical, 13)
                                .background(AppTheme.accentGradient)
                                .cornerRadius(28)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.pageBGGradient.ignoresSafeArea())
                } else {
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip.persistentModelID) {
                                TripCard(trip: trip)
                            }
                            .buttonStyle(TripCardPressStyle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteTrip(trip) } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        // 底部留出输入栏空间
                        Color.clear.frame(height: 100)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.pageBGGradient.ignoresSafeArea())
                    .navigationDestination(for: PersistentIdentifier.self) { id in
                        if let trip = trips.first(where: { $0.persistentModelID == id }) {
                            TripDetailView(trip: trip)
                        }
                    }
                }
            }
            .navigationTitle("我的旅行")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // 用同一个 ctrl，onStartGeneration 由 HomeView 注册
                // 这里在触发生成时先关掉 sheet，让用户看到地图动画
                TravelInputBar(ctrl: ctrl, onWillGenerate: { dismiss() })
                    .padding(.bottom, 4)
                    .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }.foregroundColor(AppTheme.accent)
                }
            }
        }
    }

    private func deleteTrip(_ trip: Trip) {
        withAnimation {
            modelContext.delete(trip)
            try? modelContext.save()
        }
    }
}

// MARK: - TripCard 按压样式
struct TripCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Trip Card
struct TripCard: View {
    let trip: Trip
    private var accent: DestinationAccent { destinationAccent(for: trip.destination) }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(accent.color).frame(width: 4)
                .cornerRadius(2, corners: [.topLeft, .bottomLeft])
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(accent.bgColor).frame(width: 52, height: 52)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(accent.color.opacity(0.15), lineWidth: 1))
                    Text(accent.emoji).font(.system(size: 26))
                }.padding(.leading, AppTheme.Spacing.sm)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(accent.label.uppercased())
                        .font(AppFont.caption(10, weight: .semibold))
                        .foregroundColor(accent.color).tracking(0.8)
                    Text(trip.destination).font(AppFont.heading(20))
                        .foregroundColor(AppTheme.textPrimary).lineLimit(1)
                    Text(dateRangeText).font(AppFont.caption(12))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxs) {
                    statPill("\(trip.days.count) 天", color: accent.color)
                    statPill("\(trip.days.reduce(0) { $0 + $1.events.count }) 项",
                             color: AppTheme.textTertiary)
                }.padding(.trailing, AppTheme.Spacing.sm)
            }
            .padding(.vertical, AppTheme.Spacing.sm + 2)
            .background(AppTheme.cardBG)
        }
        .cornerRadius(AppTheme.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius)
            .stroke(AppTheme.borderSubtle, lineWidth: 1))
        .appShadow(AppTheme.softLift())
    }

    private func statPill(_ text: String, color: Color) -> some View {
        Text(text).font(AppFont.caption(11, weight: .medium)).foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.08)).cornerRadius(6)
    }

    private var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        fmt.locale = Locale(identifier: "zh_CN")
        let year = Calendar.current.component(.year, from: trip.startDate)
        return "\(fmt.string(from: trip.startDate)) — \(fmt.string(from: trip.endDate))  \(year)"
    }
}
