import SwiftUI

struct CompareView: View {
    @EnvironmentObject var model: AppModel

    private struct Metric: Identifiable {
        let id: String
        let lowerIsBetter: Bool
        let value: (Comp) -> Double?
        let format: (Double?) -> String
    }

    private let metrics: [Metric] = [
        Metric(id: "平均排名", lowerIsBetter: true, value: { $0.avgPlacement }, format: { Fmt.num($0) }),
        Metric(id: "前四率", lowerIsBetter: false, value: { $0.top4Rate }, format: { Fmt.pct($0) }),
        Metric(id: "登顶率", lowerIsBetter: false, value: { $0.topRate }, format: { Fmt.pct($0) }),
        Metric(id: "出场率", lowerIsBetter: false, value: { $0.pickRate }, format: { Fmt.pct($0, digits: 2) }),
        Metric(id: "样本局数", lowerIsBetter: false, value: { $0.sampleCount.map(Double.init) },
               format: { $0.map { Fmt.count(Int($0)) } ?? "-" })
    ]

    var body: some View {
        NavigationStack {
            Group {
                if model.compareItems.isEmpty {
                    EmptyHint(
                        icon: "square.split.2x1",
                        title: "对比栏是空的",
                        message: "在排行榜里右滑阵容「加入对比」，最多 \(AppModel.maxCompare) 个。"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            table
                            heroesBlock
                            Text("绿色为该项最优。数据为版本 \(model.selectedVersion ?? "-")。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("阵容对比")
            .navigationDestination(for: Comp.self) { CompDetailView(comp: $0) }
            .toolbar {
                if !model.compareItems.isEmpty {
                    Button("清空") { model.compareItems.removeAll() }
                }
            }
        }
    }

    private var table: some View {
        let items = model.compareItems
        return Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: 12) {
            GridRow {
                Color.clear.frame(width: 64, height: 1)
                ForEach(items) { c in
                    VStack(spacing: 6) {
                        TierBadge(tier: c.tier, size: 30)
                        NavigationLink(value: c) {
                            Text(c.name)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        Button {
                            model.toggleCompare(c)
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider().gridCellUnsizedAxes(.horizontal)

            ForEach(metrics) { m in
                let best = bestValue(m, items)
                GridRow {
                    Text(m.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.leading)
                    ForEach(items) { c in
                        let v = m.value(c)
                        let isBest = items.count > 1 && v != nil && v == best
                        Text(m.format(v))
                            .font(.system(.subheadline, design: .rounded).weight(isBest ? .bold : .regular))
                            .monospacedDigit()
                            .foregroundColor(isBest ? Palette.good : .primary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func bestValue(_ m: Metric, _ items: [Comp]) -> Double? {
        let values = items.compactMap { m.value($0) }
        return m.lowerIsBetter ? values.min() : values.max()
    }

    private var heroesBlock: some View {
        VStack(spacing: 12) {
            ForEach(model.compareItems) { c in
                SectionCard(title: c.name) {
                    FlowLayout(spacing: 6) {
                        ForEach(c.heroes) { HeroAvatar(hero: $0, size: 34) }
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(c.traits) { TraitChip(trait: $0) }
                    }
                }
            }
        }
    }
}
