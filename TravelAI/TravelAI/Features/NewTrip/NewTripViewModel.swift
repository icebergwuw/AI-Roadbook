import SwiftData
import Foundation
import CoreLocation

@Observable
final class NewTripViewModel {
    var destination: String = ""
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var selectedStyle: TravelStyle = .cultural
    var isGenerating: Bool = false
    var errorMessage: String? = nil

    var generationPhase: GenerationPhase = .idle

    /// 生成成功后的行程坐标（每天一组，传给飞行动画）
    var generatedItineraryCoords: [[CLLocationCoordinate2D]] = []

    /// 阶段变化回调（由 HomeView 注入，用于更新地图浮层）
    var onPhaseChanged: ((GenerationPhase) -> Void)?
    /// 错误回调
    var onError: ((String) -> Void)?

    // 设置阶段并触发回调
    private func setPhase(_ phase: GenerationPhase) {
        generationPhase = phase
        onPhaseChanged?(phase)
    }

    enum GenerationPhase: Equatable {
        case idle
        case analyzing     // 分析目的地
        case planning      // 规划行程
        case culture       // 整理文化知识
        case tips          // 整理贴士
        case saving        // 保存数据
        case done          // 完成

        var message: String {
            switch self {
            case .idle:      return ""
            case .analyzing: return "正在分析目的地…"
            case .planning:  return "规划每日行程…"
            case .culture:   return "整理文化知识图谱…"
            case .tips:      return "整理实用贴士…"
            case .saving:    return "保存行程数据…"
            case .done:      return "攻略生成完毕！"
            }
        }

        var icon: String {
            switch self {
            case .idle:      return "sparkles"
            case .analyzing: return "magnifyingglass"
            case .planning:  return "calendar"
            case .culture:   return "book.pages"
            case .tips:      return "lightbulb"
            case .saving:    return "icloud.and.arrow.down"
            case .done:      return "checkmark.circle.fill"
            }
        }

        var progress: Double {
            switch self {
            case .idle:      return 0
            case .analyzing: return 0.15
            case .planning:  return 0.45
            case .culture:   return 0.70
            case .tips:      return 0.85
            case .saving:    return 0.95
            case .done:      return 1.0
            }
        }
    }

    enum TravelStyle: String, CaseIterable {
        case cultural = "文化深度"
        case leisure = "休闲放松"
        case adventure = "探险挑战"

        var apiValue: String {
            switch self {
            case .cultural: return "cultural"
            case .leisure: return "leisure"
            case .adventure: return "adventure"
            }
        }
    }

    var isValid: Bool {
        !destination.trimmingCharacters(in: .whitespaces).isEmpty && endDate > startDate
    }

    func generate(context: ModelContext) async {
        guard isValid else { return }
        await MainActor.run {
            isGenerating = true
            errorMessage = nil
            setPhase(.analyzing)
        }

        // 进度动画：前 40s 推进到 85%，之后每 5s 微推，最多等 180s
        let phaseTask = Task {
            let phases: [(GenerationPhase, Double)] = [
                (.analyzing, 3.0),
                (.planning,  10.0),
                (.culture,   15.0),
                (.tips,      12.0),
            ]
            for (phase, delay) in phases {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { return }
                await MainActor.run { self.setPhase(phase) }
            }
            // AI 还没回来？继续刷新计时，最多等 240s 额外时间
            var extra = 0
            while !Task.isCancelled && extra < 48 {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { return }
                extra += 1
                await MainActor.run { self.onPhaseChanged?(.tips) }
            }
        }

        do {
            let json = try await AIService.generateTrip(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                style: selectedStyle.apiValue
            )
            phaseTask.cancel()

            await MainActor.run { setPhase(.saving) }

            let jsonLen = json.count
            AILogger.shared.log("JSON 收到 \(jsonLen) 字符")
            print("[NewTrip] JSON received, length=\(jsonLen)")
            // 打前300字符方便调试
            print("[NewTrip] JSON preview: \(json.prefix(300))")

            // 解析
            let parsed: ParsedTrip
            do {
                parsed = try AIResponseParser.parse(json: json)
            } catch {
                // 写失败的 JSON 到 Documents 供调试
                let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                try? json.write(to: docDir!.appendingPathComponent("parse_failed.json"), atomically: true, encoding: .utf8)
                AILogger.shared.log("✗ 解析失败: \(error) | JSON前200: \(json.prefix(200))", error: true)
                throw error
            }
            AILogger.shared.log("解析成功: \(parsed.destination), \(parsed.days.count)天")
            print("[NewTrip] Parsed OK: \(parsed.destination), days=\(parsed.days.count)")

            // 提取坐标
            let coords: [[CLLocationCoordinate2D]] = parsed.days
                .sorted { $0.sortIndex < $1.sortIndex }
                .map { day in
                    day.events
                        .sorted { $0.sortIndex < $1.sortIndex }
                        .compactMap { e -> CLLocationCoordinate2D? in
                            guard let lat = e.latitude, let lng = e.longitude,
                                  lat != 0, lng != 0 else { return nil }
                            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        }
                }
                .filter { !$0.isEmpty }

            // 写入 SwiftData（必须在 MainActor）
            try await MainActor.run {
                generatedItineraryCoords = coords

                // destination 若为空则用用户输入的值兜底
                let saveDestination = parsed.destination.trimmingCharacters(in: .whitespaces).isEmpty
                    ? self.destination : parsed.destination

                let trip = Trip(
                    destination: saveDestination,
                    startDate: parsed.startDate.timeIntervalSince1970 < 1000 ? self.startDate : parsed.startDate,
                    endDate:   parsed.endDate.timeIntervalSince1970   < 1000 ? self.endDate   : parsed.endDate
                )
                context.insert(trip)

                for d in parsed.days.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    let day = TripDay(date: d.date, title: d.title, sortIndex: d.sortIndex)
                    context.insert(day)
                    for e in d.events.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                        let ev = TripEvent(
                            time: e.time, title: e.title, description: e.description,
                            locationName: e.locationName,
                            latitude: e.latitude, longitude: e.longitude,
                            eventType: e.eventType, sortIndex: e.sortIndex
                        )
                        context.insert(ev)
                        day.events.append(ev)
                    }
                    trip.days.append(day)
                }
                for c in parsed.checklist {
                    let item = ChecklistItem(title: c.title, isCompleted: c.isCompleted, dayIndex: c.dayIndex)
                    context.insert(item)
                    trip.checklist.append(item)
                }
                if let cu = parsed.culture {
                    let cd = CultureData(type: cu.type, title: cu.title)
                    context.insert(cd)
                    for n in cu.nodes {
                        let node = CultureNode(nodeId: n.nodeId, name: n.name, subtitle: n.subtitle,
                                               description: n.description, emoji: n.emoji,
                                               parentId: n.parentId, relationType: n.relationType)
                        context.insert(node)
                        cd.nodes.append(node)
                    }
                    trip.culture = cd
                }
                for t in parsed.tips {
                    let tip = Tip(content: t.content, sortIndex: t.sortIndex)
                    context.insert(tip)
                    trip.tips.append(tip)
                }
                for s in parsed.sosContacts {
                    let sos = SOSContact(title: s.title, subtitle: s.subtitle,
                                        phone: s.phone, emoji: s.emoji, sortIndex: s.sortIndex)
                    context.insert(sos)
                    trip.sosContacts.append(sos)
                }

                try context.save()
                AILogger.shared.log("✓ Trip 保存成功：\(saveDestination)，\(parsed.days.count)天")
                print("[NewTrip] save OK: \(saveDestination)")
            }

            await MainActor.run { setPhase(.done) }
            try? await Task.sleep(nanoseconds: 800_000_000)

        } catch {
            phaseTask.cancel()
            let msg = error.localizedDescription
            AILogger.shared.log("✗ 生成失败: \(msg)", error: true)
            await MainActor.run {
                errorMessage = msg
                setPhase(.idle)
                onError?(msg)
            }
        }

        await MainActor.run { isGenerating = false }
    }
}
