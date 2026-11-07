import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var setIdDraft = 18
    @State private var cleared = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("赛季 setId：\(setIdDraft)", value: $setIdDraft, in: 1...99)
                } header: {
                    Text("赛季")
                } footer: {
                    Text("网站当前是 S18（setId 18）。新赛季开始后，如果列表没自动更新，把这里加 1 再试。")
                }

                Section {
                    Button(cleared ? "已清除" : "清除缓存（数据与图片）") {
                        API.shared.clearCache()
                        cleared = true
                    }
                    .disabled(cleared)
                } footer: {
                    Text("断网时 App 会显示上一次成功加载的数据。")
                }

                Section("关于") {
                    LabeledContent("数据来源", value: "dataj.cc 金铲铲大数据")
                    LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Text("个人自用的数据查看工具，非官方应用，数据仅供参考。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if setIdDraft != model.setId {
                            model.setId = setIdDraft
                            model.selectedVersion = nil
                            model.comps = []
                            Task { await model.loadAll() }
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { setIdDraft = model.setId }
        }
    }
}
