import Foundation
import SwiftData

enum TrackImportState: Equatable {
    case idle
    case parsing
    case saving(progress: Double)
    case success(Int)  // 成功导入点数
    case failure(String)
}

@Observable
@MainActor
final class TrackImportService {
    var state: TrackImportState = .idle
    var allImports: [TrackImport] = []
    var renderService = TrackRenderService()

    var totalTrackPoints: Int { allImports.reduce(0) { $0 + $1.totalPoints } }

    func importFile(url: URL, context: ModelContext) async {
        state = .parsing

        do {
            // 访问沙箱外文件
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()

            let rawPoints: [RawTrackPoint] = try await Task.detached(priority: .userInitiated) {
                switch ext {
                case "gpx": return try GPXParser.parse(data: data)
                case "csv": return try CSVParser.parse(data: data)
                default:
                    // 未知格式：先尝试 GPX，再尝试 CSV
                    if let r = try? GPXParser.parse(data: data), !r.isEmpty { return r }
                    return try CSVParser.parse(data: data)
                }
            }.value

            guard !rawPoints.isEmpty else {
                state = .failure("文件中没有有效坐标点")
                return
            }

            // 创建 TrackImport 记录
            let imp = TrackImport(fileName: url.lastPathComponent, fileFormat: ext)
            context.insert(imp)

            // 分批写入（每批 500）
            let batchSize = 500
            for (i, raw) in rawPoints.enumerated() {
                let pt = TrackPoint(latitude: raw.latitude, longitude: raw.longitude,
                                    altitude: raw.altitude, timestamp: raw.timestamp,
                                    sortIndex: i)
                pt.trackImport = imp
                context.insert(pt)

                if i % batchSize == 0 {
                    state = .saving(progress: Double(i) / Double(rawPoints.count))
                    try context.save()
                }
            }

            // 计算统计
            imp.totalPoints = rawPoints.count
            let days = Set(rawPoints.compactMap { $0.timestamp }.map {
                Calendar.current.startOfDay(for: $0)
            })
            imp.daySpan = days.count
            if let first = rawPoints.compactMap({ $0.timestamp }).min() { imp.startDate = first }
            if let last  = rawPoints.compactMap({ $0.timestamp }).max() { imp.endDate   = last  }

            try context.save()
            loadAll(context: context)
            state = .success(rawPoints.count)

        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func delete(_ imp: TrackImport, context: ModelContext) {
        context.delete(imp)
        try? context.save()
        loadAll(context: context)
    }

    func toggleVisibility(_ imp: TrackImport, context: ModelContext) {
        imp.isVisible.toggle()
        try? context.save()
    }

    func loadAll(context: ModelContext) {
        let descriptor = FetchDescriptor<TrackImport>(sortBy: [SortDescriptor(\.importedAt, order: .reverse)])
        allImports = (try? context.fetch(descriptor)) ?? []
        // 同步更新渲染数据
        Task { await renderService.load(imports: allImports) }
    }

    // MARK: - 同步照片轨迹（删旧 + 重新写入）
    func syncPhotoTrack(photoService: PhotoMemoryService, context: ModelContext) async {
        guard !photoService.locations.isEmpty else { return }

        // 1. 删除旧的照片轨迹记录
        let fetchDesc = FetchDescriptor<TrackImport>()
        let all = (try? context.fetch(fetchDesc)) ?? []
        for imp in all where imp.isPhotoTrack {
            context.delete(imp)
        }
        try? context.save()

        // 2. 生成 GPX data（PhotoMemoryService 是 @MainActor，直接调用）
        guard let gpxData = photoService.exportGPXData() else { return }

        // 3. 解析 GPX
        let rawPoints: [RawTrackPoint]
        do {
            rawPoints = try await Task.detached(priority: .userInitiated) {
                try GPXParser.parse(data: gpxData)
            }.value
        } catch { return }
        guard !rawPoints.isEmpty else { return }

        // 4. 存入 SwiftData（标记 isPhotoTrack = true）
        let imp = TrackImport(fileName: "photo_memories.gpx", fileFormat: "gpx", isPhotoTrack: true)
        context.insert(imp)

        let batchSize = 500
        for (i, raw) in rawPoints.enumerated() {
            let pt = TrackPoint(latitude: raw.latitude, longitude: raw.longitude,
                                altitude: raw.altitude, timestamp: raw.timestamp,
                                sortIndex: i)
            pt.trackImport = imp
            context.insert(pt)
            if i % batchSize == 0 {
                try? context.save()
            }
        }

        imp.totalPoints = rawPoints.count
        let days = Set(rawPoints.compactMap { $0.timestamp }.map {
            Calendar.current.startOfDay(for: $0)
        })
        imp.daySpan = days.count
        if let first = rawPoints.compactMap({ $0.timestamp }).min() { imp.startDate = first }
        if let last  = rawPoints.compactMap({ $0.timestamp }).max() { imp.endDate   = last  }

        try? context.save()
        loadAll(context: context)
    }
}
