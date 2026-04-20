import SwiftUI
import SwiftData

@main
struct TravelAIApp: App {
    let container: ModelContainer

    private static let defaultMinimaxKey = "sk-cp-6KWwIruCR98Euzmci7whjzcCmcVHP8gW0EXrqdw0qvk1Onz2-EIoflvD0a4oeQJ6ZZ7TcvVWs0jxKlLztKB-RHevISUk1c7RIT-2z6k2wH9takU-MXpKmIQ"

    init() {
        // 强制设置服务商和模型
        UserDefaults.standard.set("minimax", forKey: "travelai.provider")
        UserDefaults.standard.set("MiniMax-M2.5-highspeed", forKey: "travelai.model")
        // 如果用户没有手动填过 key，预填默认 key（让设置页显示正确）
        if (UserDefaults.standard.string(forKey: "travelai.apiKey") ?? "").isEmpty {
            UserDefaults.standard.set(Self.defaultMinimaxKey, forKey: "travelai.apiKey")
        }

        let schema = Schema([
            Trip.self, TripDay.self, TripEvent.self,
            CultureData.self, CultureNode.self,
            ChecklistItem.self, Message.self,
            SOSContact.self, Tip.self,
            TrackImport.self, TrackPoint.self
        ])

        // 先尝试正常加载；若 schema 不兼容则删旧库重建
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            print("[SwiftData] Schema mismatch, rebuilding store: \(error)")
            Self.wipeStore()
            container = try! ModelContainer(for: schema, configurations: config)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }

    // MARK: - 删除旧 store（schema 不兼容时调用）
    private static func wipeStore() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        // SwiftData 默认文件名是 default.store（+ -wal / -shm）
        let names = ["default.store", "default.store-wal", "default.store-shm"]
        for name in names {
            let url = appSupport.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
                print("[SwiftData] Wiped: \(name)")
            }
        }
    }
}
