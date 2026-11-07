import Foundation
import SwiftUI

enum SortField: String, CaseIterable, Identifiable {
    case pickRate = "出场率"
    case avgPlacement = "平均排名"
    case top4Rate = "前四率"
    case topRate = "登顶率"

    var id: String { rawValue }

    func value(_ c: Comp) -> Double? {
        switch self {
        case .pickRate: return c.pickRate
        case .avgPlacement: return c.avgPlacement
        case .top4Rate: return c.top4Rate
        case .topRate: return c.topRate
        }
    }

    /// 平均排名越小越好，默认升序；其余默认降序
    var defaultAscending: Bool { self == .avgPlacement }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var setId: Int {
        didSet { UserDefaults.standard.set(setId, forKey: "setId") }
    }
    @Published var versions: [GameVersion] = []
    @Published var selectedVersion: String?
    @Published var comps: [Comp] = []
    @Published var gameData = GameDataIndex.empty
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 收藏：compId → 阵容名（换版本后该阵容不在榜上时也能显示名字）
    @Published private(set) var favorites: [String: String] {
        didSet { UserDefaults.standard.set(favorites, forKey: "favorites") }
    }

    /// 对比栏，最多 3 个
    @Published var compareItems: [Comp] = []
    static let maxCompare = 3

    init() {
        let s = UserDefaults.standard.integer(forKey: "setId")
        setId = s > 0 ? s : 18
        favorites = (UserDefaults.standard.dictionary(forKey: "favorites") as? [String: String]) ?? [:]
    }

    var currentVersion: GameVersion? {
        versions.first(where: { $0.gameVersion == selectedVersion })
    }

    // MARK: 加载

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        let sid = setId
        async let gd = API.shared.gameData(setId: sid)
        do {
            let vs = try await API.shared.versions(setId: sid)
            versions = vs
            if selectedVersion == nil || !vs.contains(where: { $0.gameVersion == selectedVersion }) {
                selectedVersion = vs.first?.gameVersion
            }
            await loadRankings()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
        if let g = try? await gd {
            gameData = GameDataIndex(g)
        }
    }

    func loadRankings() async {
        guard let v = selectedVersion else {
            isLoading = false
            return
        }
        isLoading = true
        do {
            let list = try await API.shared.rankings(setId: setId, version: v)
            comps = list
            errorMessage = nil
            // 对比栏里的阵容换成当前版本的数据
            compareItems = compareItems.map { old in list.first(where: { $0.compId == old.compId }) ?? old }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func selectVersion(_ v: String) {
        guard v != selectedVersion else { return }
        selectedVersion = v
        Task { await loadRankings() }
    }

    // MARK: 收藏

    func isFavorite(_ id: String) -> Bool { favorites[id] != nil }

    func toggleFavorite(_ c: Comp) {
        if favorites[c.compId] != nil {
            favorites.removeValue(forKey: c.compId)
        } else {
            favorites[c.compId] = c.name
        }
    }

    func removeFavorite(_ id: String) {
        favorites.removeValue(forKey: id)
    }

    var favoriteIds: [String] {
        favorites.keys.sorted { (favorites[$0] ?? "") < (favorites[$1] ?? "") }
    }

    // MARK: 对比

    func isComparing(_ id: String) -> Bool { compareItems.contains(where: { $0.compId == id }) }

    /// 返回 false 表示对比栏已满
    @discardableResult
    func toggleCompare(_ c: Comp) -> Bool {
        if let i = compareItems.firstIndex(where: { $0.compId == c.compId }) {
            compareItems.remove(at: i)
            return true
        }
        guard compareItems.count < Self.maxCompare else { return false }
        compareItems.append(c)
        return true
    }
}
