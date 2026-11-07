import SwiftUI

struct RankListView: View {
    @EnvironmentObject var model: AppModel

    @AppStorage("sortField") private var sortRaw = SortField.pickRate.rawValue
    @AppStorage("sortAscending") private var ascending = false
    @AppStorage("minSample") private var minSample = 0
    @State private var tiers: Set<String> = []
    @State private var search = ""
    @State private var showSettings = false
    @State private var compareFullAlert = false

    private let tierOptions = ["S", "A", "B", "C", "D"]
    private let sampleOptions = [0, 50, 100, 300, 500, 1000, 3000]

    private var sort: SortField { SortField(rawValue: sortRaw) ?? .pickRate }

    private var items: [Comp] {
        let key = search.trimmingCharacters(in: .whitespaces)
        let filtered = model.comps.filter { c in
            if (c.sampleCount ?? 0) < minSample { return false }
            if !tiers.isEmpty && !tiers.contains((c.tier ?? "").uppercased()) { return false }
            if !key.isEmpty {
                let hit = c.name.localizedCaseInsensitiveContains(key)
                    || c.heroes.contains(where: { $0.heroName.contains(key) })
                    || c.traits.contains(where: { $0.name.contains(key) })
                if !hit { return false }
            }
            return true
        }
        let field = sort
        let asc = ascending
        return filtered.sorted { a, b in
            switch (field.value(a), field.value(b)) {
            case let (x?, y?): return asc ? x < y : x > y
            case (nil, _?): return false
            case (_?, nil): return true
            default: return a.name < b.name
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterHeader
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if let err = model.errorMessage, model.comps.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("加载失败", systemImage: "wifi.exclamationmark").font(.headline)
                            Text(err).font(.caption).foregroundStyle(.secondary)
                            Button("重试") { Task { await model.loadAll() } }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    ForEach(items) { comp in
                        NavigationLink(value: comp) {
                            CompRow(comp: comp, sort: sort)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                model.toggleFavorite(comp)
                            } label: {
                                Label(model.isFavorite(comp.compId) ? "取消收藏" : "收藏",
                                      systemImage: model.isFavorite(comp.compId) ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                if !model.toggleCompare(comp) { compareFullAlert = true }
                            } label: {
                                Label(model.isComparing(comp.compId) ? "移出对比" : "加入对比",
                                      systemImage: "square.split.2x1")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button {
                                model.toggleFavorite(comp)
                            } label: {
                                Label(model.isFavorite(comp.compId) ? "取消收藏" : "收藏",
                                      systemImage: model.isFavorite(comp.compId) ? "star.slash" : "star")
                            }
                            Button {
                                if !model.toggleCompare(comp) { compareFullAlert = true }
                            } label: {
                                Label(model.isComparing(comp.compId) ? "移出对比" : "加入对比",
                                      systemImage: "square.split.2x1")
                            }
                        }
                    }
                } footer: {
                    if !model.comps.isEmpty {
                        Text("数据来源：dataj.cc 金铲铲大数据，仅供参考。右滑加入对比，左滑收藏。")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("阵容排行")
            .navigationDestination(for: Comp.self) { CompDetailView(comp: $0) }
            .searchable(text: $search, prompt: "阵容名 / 英雄 / 羁绊")
            .refreshable { await model.loadAll() }
            .overlay {
                if model.isLoading && model.comps.isEmpty {
                    ProgressView("加载中…")
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { versionMenu }
                ToolbarItem(placement: .navigationBarTrailing) { sortMenu }
            }
            .sheet(isPresented: $showSettings) { SettingsView().environmentObject(model) }
            .alert("对比栏已满", isPresented: $compareFullAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("最多同时对比 \(AppModel.maxCompare) 个阵容，请先在「对比」页移除一个。")
            }
        }
    }

    // MARK: 顶部筛选区

    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let v = model.currentVersion {
                    Text("版本 \(v.gameVersion)").font(.subheadline.weight(.semibold))
                    Text("· \(Fmt.count(v.battleCount)) 局").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(items.count) 个阵容").font(.caption).foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tierOptions, id: \.self) { t in
                        let on = tiers.contains(t)
                        Button {
                            if on { tiers.remove(t) } else { tiers.insert(t) }
                        } label: {
                            Text(t)
                                .font(.subheadline.weight(.bold))
                                .frame(width: 36, height: 28)
                                .foregroundColor(on ? .white : Palette.tier(t))
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(on ? Palette.tier(t) : Palette.tier(t).opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().frame(height: 22)

                    Menu {
                        Picker("最小样本", selection: $minSample) {
                            ForEach(sampleOptions, id: \.self) { n in
                                Text(n == 0 ? "不限" : "≥ \(n) 局").tag(n)
                            }
                        }
                    } label: {
                        Label(minSample == 0 ? "样本不限" : "样本≥\(minSample)", systemImage: "number")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
                    }
                }
            }
        }
    }

    // MARK: 工具栏

    private var versionMenu: some View {
        Menu {
            Picker("版本", selection: Binding(
                get: { model.selectedVersion ?? "" },
                set: { model.selectVersion($0) }
            )) {
                ForEach(model.versions) { v in
                    Text("\(v.gameVersion)（\(Fmt.count(v.battleCount)) 局）").tag(v.gameVersion)
                }
            }
            Divider()
            Button {
                showSettings = true
            } label: {
                Label("设置", systemImage: "gearshape")
            }
        } label: {
            HStack(spacing: 3) {
                Text(model.selectedVersion ?? "版本")
                Image(systemName: "chevron.down").font(.caption2)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("排序依据", selection: Binding(
                get: { sort },
                set: { f in
                    sortRaw = f.rawValue
                    ascending = f.defaultAscending
                }
            )) {
                ForEach(SortField.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            Divider()
            Button {
                ascending.toggle()
            } label: {
                Label(ascending ? "当前：升序" : "当前：降序",
                      systemImage: ascending ? "arrow.up" : "arrow.down")
            }
        } label: {
            HStack(spacing: 3) {
                Text(sort.rawValue)
                Image(systemName: ascending ? "arrow.up" : "arrow.down").font(.caption)
            }
        }
    }
}

// MARK: - 列表行

struct CompRow: View {
    @EnvironmentObject var model: AppModel
    let comp: Comp
    let sort: SortField

    /// 人口多时头像缩小，保证一行放得下
    private var avatarSize: CGFloat {
        let n = CGFloat(max(comp.heroes.count, 1))
        return min(30, max(20, 270 / n - 5))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TierBadge(tier: comp.tier)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(comp.name).font(.headline).lineLimit(1)
                    if model.isFavorite(comp.compId) {
                        Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow)
                    }
                    if model.isComparing(comp.compId) {
                        Image(systemName: "square.split.2x1.fill").font(.caption).foregroundColor(.blue)
                    }
                    Spacer(minLength: 4)
                    Text("\(Fmt.count(comp.sampleCount)) 局")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HeroStrip(heroes: comp.heroes, size: avatarSize)
                    .padding(.top, 4)

                HStack(spacing: 4) {
                    StatCell(title: "平均排名", value: Fmt.num(comp.avgPlacement), highlighted: sort == .avgPlacement)
                    StatCell(title: "出场率", value: Fmt.pct(comp.pickRate, digits: 2), highlighted: sort == .pickRate)
                    StatCell(title: "登顶率", value: Fmt.pct(comp.topRate), highlighted: sort == .topRate)
                    StatCell(title: "前四率", value: Fmt.pct(comp.top4Rate), highlighted: sort == .top4Rate)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
