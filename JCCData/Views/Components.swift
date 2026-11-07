import SwiftUI

// MARK: - 颜色

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Palette {
    static func tier(_ t: String?) -> Color {
        switch (t ?? "").uppercased() {
        case "S": return Color(hex: 0xFF5A5F)
        case "A": return Color(hex: 0xFF9F43)
        case "B": return Color(hex: 0xF5B800)
        case "C": return Color(hex: 0x1DB98A)
        case "D": return Color(hex: 0x8395A7)
        default: return .gray
        }
    }

    /// 英雄费用边框色
    static func cost(_ p: Int) -> Color {
        switch p {
        case 1: return Color(hex: 0x9AA4AF)
        case 2: return Color(hex: 0x2ECC71)
        case 3: return Color(hex: 0x3498DB)
        case 4: return Color(hex: 0xB45CE0)
        default: return Color(hex: 0xF1B90F)
        }
    }

    /// 羁绊等级：1 铜 2 银 3 金 4 彩
    static func trait(_ level: Int) -> Color {
        switch level {
        case 1: return Color(hex: 0xB0805A)
        case 2: return Color(hex: 0xA9B5C0)
        case 3: return Color(hex: 0xE8B931)
        default: return Color(hex: 0xC77DFF)
        }
    }

    static let good = Color(hex: 0x1DB98A)
    static let bad = Color(hex: 0xFF5A5F)
}

// MARK: - 数字格式

enum Fmt {
    static func pct(_ v: Double?, digits: Int = 1) -> String {
        guard let v else { return "-" }
        return String(format: "%.\(digits)f%%", v)
    }

    static func num(_ v: Double?, digits: Int = 2) -> String {
        guard let v else { return "-" }
        return String(format: "%.\(digits)f", v)
    }

    static func signed(_ v: Double?, digits: Int = 2) -> String {
        guard let v else { return "-" }
        return String(format: "%+.\(digits)f", v)
    }

    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    static func count(_ v: Int?) -> String {
        guard let v else { return "-" }
        return grouping.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

// MARK: - 网络图片

struct RemoteImage: View {
    let url: String?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(Color.secondary.opacity(0.15))
            }
        }
        .task(id: url) {
            guard let s = url, let u = URL(string: s) else {
                image = nil
                return
            }
            if let c = ImageLoader.shared.cached(u) {
                image = c
                return
            }
            image = await ImageLoader.shared.load(u)
        }
    }
}

// MARK: - 评级徽章

struct TierBadge: View {
    let tier: String?
    var size: CGFloat = 34

    var body: some View {
        Text(tier ?? "-")
            .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.25).fill(Palette.tier(tier)))
    }
}

// MARK: - 英雄头像

struct HeroAvatar: View {
    @EnvironmentObject var model: AppModel
    let hero: CompHero
    var size: CGFloat = 34
    var showStars = true

    var body: some View {
        let gd = model.gameData.hero(hero.heroId, name: hero.heroName)
        RemoteImage(url: gd?.picture)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.18)
                    .stroke(Palette.cost(hero.price), lineWidth: max(1.5, size * 0.06))
            )
            .overlay(alignment: .topTrailing) {
                if hero.isCarry {
                    Image(systemName: "flame.fill")
                        .font(.system(size: size * 0.3))
                        .foregroundColor(.orange)
                        .padding(1)
                        .background(Circle().fill(Color(.systemBackground)))
                        .offset(x: size * 0.12, y: -size * 0.12)
                }
            }
            .overlay(alignment: .bottom) {
                if showStars, let s = hero.star, s >= 3 {
                    HStack(spacing: 0) {
                        ForEach(0..<min(s, 4), id: \.self) { _ in
                            Image(systemName: "star.fill")
                        }
                    }
                    .font(.system(size: size * 0.22))
                    .foregroundColor(Color(hex: 0xF1B90F))
                    .shadow(color: .black.opacity(0.6), radius: 1)
                    .offset(y: size * 0.14)
                }
            }
            .accessibilityLabel(hero.heroName)
    }
}

struct HeroStrip: View {
    let heroes: [CompHero]
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: 5) {
            ForEach(heroes) { h in
                HeroAvatar(hero: h, size: size)
            }
        }
        .padding(.bottom, 3)
    }
}

// MARK: - 羁绊标签

struct TraitChip: View {
    @EnvironmentObject var model: AppModel
    let trait: CompTrait

    var level: Int { Int(trait.id.suffix(2)) ?? 1 }

    var body: some View {
        let gd = model.gameData.trait(trait.id)
        HStack(spacing: 4) {
            RemoteImage(url: gd?.picture)
                .frame(width: 16, height: 16)
            Text(trait.name).font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Palette.trait(gd?.color ?? level).opacity(0.25)))
        .overlay(Capsule().stroke(Palette.trait(gd?.color ?? level), lineWidth: 1))
    }
}

// MARK: - 数据块

struct StatCell: View {
    let title: String
    let value: String
    var highlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(highlighted ? .bold : .medium))
                .foregroundColor(highlighted ? .accentColor : .primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    var trailing: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let trailing {
                    Text(trailing).font(.caption).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - 六边形（棋盘格子）

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.25))
        p.addLine(to: CGPoint(x: w, y: h * 0.75))
        p.addLine(to: CGPoint(x: w / 2, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.75))
        p.addLine(to: CGPoint(x: 0, y: h * 0.25))
        p.closeSubpath()
        return p
    }
}
