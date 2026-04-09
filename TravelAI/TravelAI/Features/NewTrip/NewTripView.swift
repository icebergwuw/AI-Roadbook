import SwiftUI

struct NewTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm = NewTripViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Destination
                        VStack(alignment: .leading, spacing: 8) {
                            label("目的地")
                            TextField("如：Egypt、Japan、Greece", text: $vm.destination)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(AppTheme.cardBackground)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        // Date range
                        VStack(alignment: .leading, spacing: 8) {
                            label("出发日期")
                            DatePicker("", selection: $vm.startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(AppTheme.gold)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            label("返回日期")
                            DatePicker("", selection: $vm.endDate, in: vm.startDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(AppTheme.gold)
                        }

                        // Style
                        VStack(alignment: .leading, spacing: 8) {
                            label("旅行风格")
                            HStack(spacing: 8) {
                                ForEach(NewTripViewModel.TravelStyle.allCases, id: \.self) { style in
                                    Button(style.rawValue) {
                                        vm.selectedStyle = style
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(vm.selectedStyle == style ? AppTheme.gold : AppTheme.cardBackground)
                                    .foregroundColor(vm.selectedStyle == style ? .black : AppTheme.textSecondary)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border))
                                }
                            }
                        }

                        // Error
                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                        }

                        // Generate button
                        Button {
                            Task { await vm.generate(context: modelContext) }
                        } label: {
                            HStack {
                                if vm.isGenerating {
                                    ProgressView().tint(.black)
                                    Text("AI 生成中…")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("AI 生成攻略")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(vm.isValid ? AppTheme.gold : AppTheme.border)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .font(.headline)
                        }
                        .disabled(!vm.isValid || vm.isGenerating)
                        .onChange(of: vm.isGenerating) { _, new in
                            if !new && vm.errorMessage == nil { dismiss() }
                        }
                    }
                    .padding(AppTheme.padding)
                }
            }
            .navigationTitle("新建旅行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .textCase(.uppercase)
            .tracking(1)
    }
}
