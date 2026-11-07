import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.favoriteIds.isEmpty {
                    EmptyHint(
                        icon: "star",
                        title: "还没有收藏",
                        message: "在排行榜里左滑一个阵容，或在详情页点右上角的星标即可收藏。"
                    )
                } else {
                    List {
                        ForEach(model.favoriteIds, id: \.self) { id in
                            if let comp = model.comps.first(where: { $0.compId == id }) {
                                NavigationLink(value: comp) {
                                    CompRow(comp: comp, sort: .avgPlacement)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(model.favorites[id] ?? "阵容 \(id)").font(.headline)
                                    Text("版本 \(model.selectedVersion ?? "-") 暂无该阵容的数据")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { model.favoriteIds[$0] }
                            ids.forEach { model.removeFavorite($0) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("我的收藏")
            .navigationDestination(for: Comp.self) { CompDetailView(comp: $0) }
            .toolbar {
                if !model.favoriteIds.isEmpty {
                    EditButton()
                }
            }
        }
    }
}

struct EmptyHint: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
