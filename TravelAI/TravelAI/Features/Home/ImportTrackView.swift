import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportTrackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var trackService: TrackImportService

    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                Color(hex: "#111118").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Format explanation card
                        formatCard

                        // 2. Imported tracks list (if any)
                        if !trackService.allImports.isEmpty {
                            importedListCard
                        }

                        // 3. Import state feedback
                        stateCard

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                // Bottom CTA button
                VStack {
                    Spacer()
                    importButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("导入航迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#111118"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(Color(hex: "#00d4aa"))
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.gpx, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFilePickerResult(result)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Format explanation card
    private var formatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#00d4aa"))
                Text("支持格式")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Divider().background(Color.white.opacity(0.1))

            // GPX row
            HStack(alignment: .top, spacing: 12) {
                Text("GPX")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color(hex: "#00d4aa"), in: RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 3) {
                    Text("GPS Exchange Format")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("来自 Garmin、户外运动手表、Keep、咕咚等 App 导出")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            // CSV row
            HStack(alignment: .top, spacing: 12) {
                Text("CSV")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(AppTheme.accentLight, in: RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 3) {
                    Text("逗号分隔值")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("需包含 latitude, longitude 列，timestamp 可选")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                    // Example
                    Text("latitude,longitude,timestamp\n39.9042,116.4074,2024-01-01 08:00:00")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppTheme.accentLight.opacity(0.8))
                        .padding(8)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Imported tracks list
    private var importedListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("已导入航迹")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(trackService.allImports.count) 条")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
            }

            ForEach(trackService.allImports) { imp in
                trackRow(imp)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func trackRow(_ imp: TrackImport) -> some View {
        HStack(spacing: 12) {
            // Format badge
            Text(imp.fileFormat.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(
                    imp.fileFormat == "gpx" ? Color(hex: "#00d4aa") : AppTheme.accentLight,
                    in: RoundedRectangle(cornerRadius: 3)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(imp.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(formatNumber(imp.totalPoints)) 点")
                    if imp.daySpan > 0 {
                        Text("·")
                        Text("\(imp.daySpan) 天")
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            // Visibility toggle
            Button {
                trackService.toggleVisibility(imp, context: modelContext)
            } label: {
                Image(systemName: imp.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 14))
                    .foregroundColor(imp.isVisible ? Color(hex: "#00d4aa") : .white.opacity(0.3))
            }

            // Delete
            Button {
                trackService.delete(imp, context: modelContext)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Import state feedback
    @ViewBuilder
    private var stateCard: some View {
        switch trackService.state {
        case .idle:
            EmptyView()
        case .parsing:
            stateRow(icon: "arrow.triangle.2.circlepath", color: Color(hex: "#00d4aa"),
                     text: "正在解析文件...", showSpinner: true)
        case .saving(let progress):
            VStack(spacing: 8) {
                stateRow(icon: "square.and.arrow.down", color: AppTheme.accentLight,
                         text: "正在保存航迹点...", showSpinner: false)
                ProgressView(value: progress)
                    .tint(AppTheme.accentLight)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        case .success(let count):
            stateRow(icon: "checkmark.circle.fill", color: .green,
                     text: "成功导入 \(formatNumber(count)) 个轨迹点", showSpinner: false)
        case .failure(let msg):
            stateRow(icon: "exclamationmark.triangle.fill", color: AppTheme.red,
                     text: msg, showSpinner: false)
        }
    }

    private func stateRow(icon: String, color: Color, text: String, showSpinner: Bool) -> some View {
        HStack(spacing: 12) {
            if showSpinner {
                ProgressView().tint(color)
            } else {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Import button
    private var importButton: some View {
        Button {
            showFilePicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("选择 GPX / CSV 文件")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.accentGradient, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 4)
        }
        .disabled(trackService.state == .parsing)
        .opacity(trackService.state == .parsing ? 0.5 : 1.0)
    }

    // MARK: - File picker handler
    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await trackService.importFile(url: url, context: modelContext)
            }
        case .failure:
            break  // User cancelled or error — silent
        }
    }

    // MARK: - Number formatter
    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - UTType extension for GPX
extension UTType {
    static let gpx = UTType(importedAs: "com.topografix.gpx")
}
