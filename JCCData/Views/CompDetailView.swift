import SwiftUI
import Charts

struct CompDetailView: View {
    @EnvironmentObject var model: AppModel
    let comp: Comp

    @State private var detail: Comp?
    @State private var heroStats: [CompHero] = []
    @State private var equips: [EquipStat] = []
    @State private var hexes: [HexStat] = []
    @State private var trend: [TrendPoint] = []
    @State private var loading = true
    @State private var copied = false
    @State private var compareFullAlert = false
    @State private var trendMetric: SortField = .avgPlacement

    private var shown: Comp { detail ?? comp }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                statsCard

                if let code = shown.gameCode, !code.isEmpty {
                    codeCard(code)
                }

                if shown.heroes.contains(where: { $0.boardRow != nil }) {
                    SectionCard(title: "站位", trailing: "上方为前排") {
                        BoardView(heroes: shown.heroes)
                    }
                }

                heroesCard

                if !shown.placementDistribution.isEmpty {
                    distributionCard
                }

                if trend.count > 1 {
                    trendCard
                }

                if !equips.isEmpty {
                    equipsCard
                }

                if !hexes.isEmpty {
                    hexesCard
                }

                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding()
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(comp.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    if !model.toggleCompare(shown) { compareFullAlert = true }
                } label: {
                    Image(systemName: model.isComparing(comp.compId) ? "square.split.2x1.fill" : "square.split.2x1")
                }
                Button {
                    model.toggleFavorite(shown)
                } label: {
                    Image(systemName: model.isFavorite(comp.compId) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
            }
        }
        .alert("对比栏已满", isPresented: $compareFullAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text("最多同时对比 \(AppModel.maxCompare) 个阵容。")
        }
        .task(id: model.selectedVersion) { await load() }
    }

    // MARK: 加载

    private func load() async {
        loading = true
        let id = comp.compId
        let sid = model.setId
        let v = model.selectedVersion ?? ""

        async let d = API.shared.detail(compId: id, setId: sid, version: v)
        async let h = API.shared.heroes(compId: id, setId: sid, version: v)
        async let e = API.shared.equips(compId: id, setId: sid, version: v)
        async let x = API.shared.hexes(compId: id, setId: sid, version: v)
        async let t = API.shared.trend(compId: id)

        if let value = try? await d { detail = value }
        heroStats = (try? await h) ?? []
        equips = (try? await e) ?? []
        hexes = (try? await x) ?? []
        trend = (try? await t) ?? []
        loading = false
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            TierBadge(tier: shown.tier, size: 46)
            VStack(alignment: .leading, spacing: 6) {
                Text(shown.name).font(.title2.bold())
                if let carry = shown.carry {
                    Text("主C：\(carry.heroName)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var statsCard: some View {
        SectionCard(title: "数据", trailing: "版本 \(model.selectedVersion ?? "-")") {
            HStack {
                StatCell(title: "平均排名", value: Fmt.num(shown.avgPlacement))
                StatCell(title: "前四率", value: Fmt.pct(shown.top4Rate))
                StatCell(title: "登顶率", value: Fmt.pct(shown.topRate))
            }
            HStack {
                StatCell(title: "出场率", value: Fmt.pct(shown.pickRate, digits: 2))
                StatCell(title: "样本", value: "\(Fmt.count(shown.sampleCount)) 局")
                StatCell(title: "评级", value: shown.tier ?? "-")
            }
            if !shown.traits.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(shown.traits) { TraitChip(trait: $0) }
                }
                .padding(.top, 4)
            }
            if let desc = shown.desc, !desc.isEmpty {
                Text(desc).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func codeCard(_ code: String) -> some View {
        SectionCard(title: "阵容码") {
            HStack {
                Text(code)
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copied = false
                    }
                } label: {
                    Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .tint(copied ? .green : .accentColor)
            }
            Text("复制后打开金铲铲，在阵容助手里粘贴即可导入。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 英雄与出装

    private var heroesCard: some View {
        let list = heroStats.isEmpty ? shown.heroes : heroStats
        return SectionCard(title: "英雄与推荐装备", trailing: heroStats.isEmpty ? nil : "出场率 / 平均排名") {
            VStack(spacing: 10) {
                ForEach(list) { hero in
                    HStack(spacing: 10) {
                        HeroAvatar(hero: hero, size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(hero.heroName).font(.subheadline.weight(.semibold))
                                if hero.isCarry { tag("主C", .orange) }
                                else if hero.isSubCarry { tag("副C", .purple) }
                                else if hero.isCore { tag("核心", .blue) }
                            }
                            Text(heroSubtitle(hero))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(Array(shown.equips(for: hero).enumerated()), id: \.offset) { _, eq in
                                RemoteImage(url: model.gameData.equip(eq.equipId)?.picture)
                                    .frame(width: 26, height: 26)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        if hero.playRate != nil || hero.avgPlacement != nil {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Fmt.pct(hero.playRate, digits: 0)).font(.caption.monospacedDigit())
                                Text(Fmt.num(hero.avgPlacement)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func heroSubtitle(_ hero: CompHero) -> String {
        var s = "\(hero.price) 费"
        if let star = hero.star { s += " · \(star) 星" }
        return s
    }

    private func tag(_ s: String, _ c: Color) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(c)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(c.opacity(0.15)))
    }

    // MARK: 名次分布

    private var distributionCard: some View {
        let total = max(1, shown.placementDistribution.reduce(0) { $0 + $1.count })
        return SectionCard(title: "名次分布") {
            Chart(shown.placementDistribution) { p in
                BarMark(
                    x: .value("名次", "第\(p.ranking)"),
                    y: .value("占比", Double(p.count) / Double(total) * 100)
                )
                .foregroundStyle(p.ranking == 1 ? Color(hex: 0xF1B90F) : (p.ranking <= 4 ? Palette.good : Color.gray.opacity(0.5)))
                .annotation(position: .top) {
                    Text(String(format: "%.0f%%", Double(p.count) / Double(total) * 100))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)
        }
    }

    // MARK: 趋势

    private var trendCard: some View {
        SectionCard(title: "近期趋势") {
            Picker("指标", selection: $trendMetric) {
                ForEach(SortField.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Chart(trendSeries) { p in
                LineMark(x: .value("日期", p.label), y: .value("数值", p.value))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("日期", p.label), y: .value("数值", p.value))
                    .annotation(position: .top) {
                        Text(trendMetric == .avgPlacement ? Fmt.num(p.value) : String(format: "%.1f", p.value))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 170)

            if trendMetric == .avgPlacement {
                Text("平均排名越低越好").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private struct TrendValue: Identifiable {
        let id: String
        let label: String
        let value: Double
    }

    private var trendSeries: [TrendValue] {
        trend.compactMap { p in
            trendValue(p).map { TrendValue(id: p.id, label: p.shortDate, value: $0) }
        }
    }

    private func trendValue(_ p: TrendPoint) -> Double? {
        switch trendMetric {
        case .avgPlacement: return p.avgPlacement
        case .pickRate: return p.playRate
        case .top4Rate: return p.top4Rate
        case .topRate: return p.topRate
        }
    }

    // MARK: 装备 / 海克斯

    private var equipsCard: some View {
        SectionCard(title: "常用装备", trailing: "出场率 · 均名 · 前四") {
            VStack(spacing: 8) {
                ForEach(equips.prefix(12)) { e in
                    HStack(spacing: 10) {
                        RemoteImage(url: e.picture ?? model.gameData.equip(e.id)?.picture)
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(e.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        statTriple(Fmt.pct(e.playRate, digits: 0), Fmt.num(e.avgPlacement), Fmt.pct(e.top4Rate, digits: 0))
                    }
                }
            }
        }
    }

    private var hexesCard: some View {
        SectionCard(title: "海克斯强化", trailing: "出场率 · 均名 · 排名变化") {
            VStack(spacing: 8) {
                ForEach(hexes.prefix(12)) { h in
                    HStack(spacing: 10) {
                        RemoteImage(url: h.icon)
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(h.name).font(.subheadline).lineLimit(1)
                                if let t = h.tier { TierBadge(tier: t, size: 16) }
                            }
                        }
                        Spacer()
                        Text(Fmt.pct(h.playRate, digits: 0))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40, alignment: .trailing)
                        Text(Fmt.num(h.avgPlacement))
                            .font(.caption.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                        Text(Fmt.signed(h.placementDelta))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundColor((h.placementDelta ?? 0) <= 0 ? Palette.good : Palette.bad)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Text("排名变化为负表示带上这个海克斯后平均排名更靠前。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statTriple(_ a: String, _ b: String, _ c: String) -> some View {
        HStack(spacing: 0) {
            Text(a).frame(width: 40, alignment: .trailing)
            Text(b).frame(width: 40, alignment: .trailing)
            Text(c).frame(width: 40, alignment: .trailing)
        }
        .font(.caption.monospacedDigit())
    }
}

// MARK: - 棋盘

struct BoardView: View {
    let heroes: [CompHero]
    private let rows = 4
    private let cols = 7

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / (CGFloat(cols) + 0.5)
            let rowStep = w * 0.86
            ZStack(alignment: .topLeading) {
                ForEach(1...rows, id: \.self) { row in
                    ForEach(1...cols, id: \.self) { col in
                        cell(row: row, col: col, size: w * 0.94)
                            .position(center(row: row, col: col, w: w, rowStep: rowStep))
                    }
                }
            }
        }
        .aspectRatio(boardRatio, contentMode: .fit)
    }

    private var boardRatio: CGFloat {
        (CGFloat(cols) + 0.5) / (CGFloat(rows - 1) * 0.86 + 1)
    }

    /// 偶数行向右错半格，形成蜂窝棋盘
    private func center(row: Int, col: Int, w: CGFloat, rowStep: CGFloat) -> CGPoint {
        let shift: CGFloat = row % 2 == 0 ? w / 2 : 0
        let x = CGFloat(col - 1) * w + shift + w / 2
        let y = CGFloat(row - 1) * rowStep + w / 2
        return CGPoint(x: x, y: y)
    }

    @ViewBuilder
    private func cell(row: Int, col: Int, size: CGFloat) -> some View {
        if let hero = heroes.first(where: { $0.boardRow == row && $0.boardCol == col }) {
            BoardHeroCell(hero: hero, size: size)
        } else {
            Hexagon()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: size, height: size)
        }
    }
}

private struct BoardHeroCell: View {
    @EnvironmentObject var model: AppModel
    let hero: CompHero
    let size: CGFloat

    var body: some View {
        let gd = model.gameData.hero(hero.heroId, name: hero.heroName)
        RemoteImage(url: gd?.picture)
            .frame(width: size, height: size)
            .clipShape(Hexagon())
            .overlay(Hexagon().stroke(Palette.cost(hero.price), lineWidth: 2.5))
            .overlay(alignment: .bottom) {
                if let s = hero.star, s >= 3 {
                    HStack(spacing: 0) {
                        ForEach(0..<min(s, 4), id: \.self) { _ in Image(systemName: "star.fill") }
                    }
                    .font(.system(size: size * 0.16))
                    .foregroundColor(Color(hex: 0xF1B90F))
                    .shadow(color: .black.opacity(0.7), radius: 1)
                    .offset(y: size * 0.04)
                }
            }
    }
}

// MARK: - 自动换行布局（羁绊标签）

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
