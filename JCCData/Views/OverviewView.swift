import SwiftUI
import UIKit

/// 一图流：按评级分层的主C头像墙，点一个在下方展开该阵容的分人口站位、羁绊和出装
struct OverviewView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedId: String?

    private let tiers = ["S", "A", "B", "C", "D"]

    private func comps(in tier: String) -> [Comp] {
        model.comps
            .filter { ($0.tier ?? "").uppercased() == tier }
            .sorted { ($0.avgPlacement ?? 9) < ($1.avgPlacement ?? 9) }
    }

    /// 没手动选过时，默认选 S 级第一个
    private var selected: Comp? {
        if let id = selectedId, let c = model.comps.first(where: { $0.compId == id }) { return c }
        for t in tiers {
            if let c = comps(in: t).first { return c }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        tierWall(proxy: proxy)

                        if let c = selected {
                            VStack {
                                OneImagePanel(comp: c)
                                    .id(c.compId)   // 换阵容时重置面板状态
                            }
                            .id("panel")
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("一图流")
            .navigationDestination(for: Comp.self) { CompDetailView(comp: $0) }
            .refreshable { await model.loadAll() }
            .overlay {
                if model.isLoading && model.comps.isEmpty {
                    ProgressView("加载中…")
                } else if !model.isLoading && model.comps.isEmpty {
                    EmptyHint(icon: "square.grid.3x3", title: "暂无数据", message: model.errorMessage ?? "下拉刷新试试。")
                }
            }
        }
    }

    // MARK: 评级头像墙

    private func tierWall(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("版本 \(model.selectedVersion ?? "-")").font(.subheadline.weight(.semibold))
                Spacer()
                Text("点头像看站位").font(.caption).foregroundStyle(.secondary)
            }

            ForEach(tiers, id: \.self) { tier in
                let list = comps(in: tier)
                if !list.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        TierBadge(tier: tier, size: 28)
                            .padding(.top, 12)
                        FlowLayout(spacing: 8) {
                            ForEach(list) { c in
                                CarryTile(comp: c, isSelected: c.compId == selected?.compId)
                                    .onTapGesture {
                                        selectedId = c.compId
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo("panel", anchor: .top)
                                        }
                                    }
                            }
                        }
                    }
                    if tier != tiers.last { Divider() }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - 头像墙里的一格

private struct CarryTile: View {
    @EnvironmentObject var model: AppModel
    let comp: Comp
    let isSelected: Bool

    var body: some View {
        let carry = comp.carry
        let gd = carry.flatMap { model.gameData.hero($0.heroId, name: $0.heroName) }
        VStack(spacing: 3) {
            RemoteImage(url: gd?.picture)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Palette.cost(carry?.price ?? 1), lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        .padding(-4)
                )
            Text(comp.name)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(width: 58)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .contentShape(Rectangle())
        .padding(.top, 4)
    }
}

// MARK: - 选中阵容的面板

struct OneImagePanel: View {
    @EnvironmentObject var model: AppModel
    let comp: Comp

    @State private var groups: [BattleBuildGroup] = []
    @State private var stage = 0          // 0 = 成型站位；其余为人口数
    @State private var buildIndex = 0
    @State private var image: SingleImage?
    @State private var showImage = false
    @State private var loading = true

    private var group: BattleBuildGroup? { groups.first(where: { $0.peopleNum == stage }) }

    private var build: BattleBuild? {
        guard let g = group, !g.builds.isEmpty else { return nil }
        return g.builds[min(buildIndex, g.builds.count - 1)]
    }

    private var units: [BoardUnit] {
        if stage == 0 { return comp.heroes.compactMap { $0.boardUnit } }
        guard let b = build else { return [] }
        return b.heroes.compactMap { (h: BuildHero) -> BoardUnit? in
            guard let r = h.row, let c = h.col else { return nil }
            let gd = model.gameData.hero(h.heroId, name: "") ?? model.gameData.hero(h.heroBaseId, name: "")
            return BoardUnit(
                id: "\(b.id)-\(h.heroId)-\(r)-\(c)",
                heroId: h.heroBaseId,
                name: gd?.name ?? "",
                price: gd?.price ?? 1,
                star: h.star,
                row: r,
                col: c
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            HStack {
                StatCell(title: "平均排名", value: Fmt.num(comp.avgPlacement))
                StatCell(title: "前四率", value: Fmt.pct(comp.top4Rate))
                StatCell(title: "登顶率", value: Fmt.pct(comp.topRate))
                StatCell(title: "出场率", value: Fmt.pct(comp.pickRate, digits: 2))
            }

            stagePicker

            BoardView(units: units)

            stageInfo

            if !comp.traits.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(comp.traits) { TraitChip(trait: $0) }
                }
            }

            itemsBlock

            Button {
                showImage = true
            } label: {
                Label(imageButtonTitle, systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!(image?.isReady ?? false))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        .task(id: model.selectedVersion) { await load() }
        .sheet(isPresented: $showImage) {
            SingleImageViewer(url: image?.url, title: comp.name)
        }
    }

    private var imageButtonTitle: String {
        if loading { return "一图流大图加载中…" }
        return (image?.isReady ?? false) ? "查看一图流大图" : "暂无一图流大图"
    }

    private func load() async {
        loading = true
        let id = comp.compId
        let sid = model.setId
        let v = model.selectedVersion ?? ""
        async let g = API.shared.battleBuilds(compId: id, setId: sid, version: v)
        async let img = API.shared.singleImage(compId: id, setId: sid, version: v)
        groups = ((try? await g) ?? [])
            .filter { !$0.builds.isEmpty }
            .sorted { $0.peopleNum < $1.peopleNum }
        image = try? await img
        loading = false
    }

    // MARK: 子视图

    private var header: some View {
        HStack(spacing: 10) {
            TierBadge(tier: comp.tier, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(comp.name).font(.title3.bold())
                Text("\(Fmt.count(comp.sampleCount)) 局样本")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink(value: comp) {
                HStack(spacing: 2) {
                    Text("完整数据")
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
            }
        }
    }

    private var stagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(groups) { g in
                    stageChip("\(g.peopleNum)人口", value: g.peopleNum)
                }
                stageChip("成型", value: 0)
            }
        }
    }

    private func stageChip(_ title: String, value: Int) -> some View {
        let on = stage == value
        return Button {
            stage = value
            buildIndex = 0
        } label: {
            Text(title)
                .font(.subheadline.weight(on ? .semibold : .regular))
                .padding(.horizontal, 12)
                .frame(height: 30)
                .foregroundColor(on ? .white : .primary)
                .background(Capsule().fill(on ? Color.accentColor : Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var stageInfo: some View {
        if stage == 0 {
            Text("最终成型站位，上方为前排。")
                .font(.caption).foregroundStyle(.secondary)
        } else if let b = build, let g = group {
            HStack(spacing: 10) {
                Text("第 \(min(buildIndex, g.builds.count - 1) + 1) 常见 · \(Fmt.count(b.sampleCount)) 局")
                if let w = b.winRate {
                    Text("胜率 \(Fmt.pct(w))")
                }
                Spacer()
                if g.builds.count > 1 {
                    Button {
                        buildIndex = (buildIndex + 1) % g.builds.count
                    } label: {
                        Label("换一套", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.caption)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// 带装备的英雄：头像 + 推荐三件套
    private var itemsBlock: some View {
        let carriers = comp.heroes.filter { !comp.equips(for: $0).isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            if !carriers.isEmpty {
                Text("核心出装").font(.subheadline.weight(.semibold))
                ForEach(carriers) { hero in
                    HStack(spacing: 8) {
                        HeroAvatar(hero: hero, size: 34)
                        Text(hero.heroName).font(.subheadline)
                        Spacer()
                        ForEach(Array(comp.equips(for: hero).enumerated()), id: \.offset) { _, eq in
                            RemoteImage(url: model.gameData.equip(eq.equipId)?.picture)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 一图流大图查看器

struct SingleImageViewer: View {
    let url: String?
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var failed = false
    @State private var saved = false

    private var shareTitle: String { title + "一图流" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    ZoomableImage(image: image)
                        .ignoresSafeArea(edges: .bottom)
                } else if failed {
                    Text("图片加载失败").foregroundColor(.white)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if let image {
                        Button {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                            saved = true
                        } label: {
                            Image(systemName: saved ? "checkmark.circle" : "square.and.arrow.down")
                        }
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(shareTitle, image: Image(uiImage: image))
                        )
                    }
                }
            }
        }
        .task {
            guard let u = URL.lenient(url) else {
                failed = true
                return
            }
            if let img = await ImageLoader.shared.load(u) {
                image = img
            } else {
                failed = true
            }
        }
    }
}

/// 可双指缩放、双击放大的长图
struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ImageScrollView {
        ImageScrollView(image: image)
    }

    func updateUIView(_ uiView: ImageScrollView, context: Context) {}
}

final class ImageScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var lastWidth: CGFloat = 0

    init(image: UIImage) {
        super.init(frame: .zero)
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        showsHorizontalScrollIndicator = false
        backgroundColor = .black
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.width != lastWidth,
              let img = imageView.image, img.size.width > 0 else { return }
        lastWidth = bounds.width
        zoomScale = 1
        let h = bounds.width * img.size.height / img.size.width
        imageView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: h)
        contentSize = imageView.frame.size
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        if zoomScale > 1 {
            setZoomScale(1, animated: true)
        } else {
            let p = g.location(in: imageView)
            let scale: CGFloat = 2.5
            let w = bounds.width / scale
            let h = bounds.height / scale
            zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
        }
    }
}
