import Foundation

// MARK: - 通用响应外壳 { code, success, message, data }

struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int?
    let success: Bool?
    let message: String?
    let data: T?
}

// MARK: - 宽松解码：接口里同一个字段有时是数字、有时是字符串

extension KeyedDecodingContainer {
    func flexString(_ key: Key) -> String? {
        if let v = try? decodeIfPresent(String.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return String(v) }
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return String(v) }
        return nil
    }

    func flexDouble(_ key: Key) -> Double? {
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }

    func flexInt(_ key: Key) -> Int? {
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int(s) }
        return nil
    }

    func flexBool(_ key: Key) -> Bool {
        if let v = try? decodeIfPresent(Bool.self, forKey: key) { return v }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i != 0 }
        return false
    }

    func list<T: Decodable>(_ type: T.Type, _ key: Key) -> [T] {
        (try? decodeIfPresent([T].self, forKey: key)) ?? []
    }
}

// MARK: - 版本

struct GameVersion: Decodable, Hashable, Identifiable {
    var id: String { gameVersion }
    let setId: Int
    let gameVersion: String
    let startTime: String?
    let battleCount: Int

    enum CodingKeys: String, CodingKey { case setId, gameVersion, startTime, battleCount }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        setId = c.flexInt(.setId) ?? 0
        gameVersion = c.flexString(.gameVersion) ?? ""
        startTime = c.flexString(.startTime)
        battleCount = c.flexInt(.battleCount) ?? 0
    }
}

// MARK: - 阵容

struct CompHero: Decodable, Identifiable, Hashable {
    let id: String          // 阵容内英雄 id（装备通过 compHeroId 关联到这里）
    let heroId: String
    let heroName: String
    let isCarry: Bool
    let isSubCarry: Bool
    let isCore: Bool
    let price: Int
    let star: Int?
    let position: String?   // "行,列"，行 1~4，列 1~7
    // 以下仅 /comp/{id}/heroes 返回
    let sampleCount: Int?
    let playRate: Double?
    let avgPlacement: Double?
    let top4Rate: Double?
    let topRate: Double?

    enum CodingKeys: String, CodingKey {
        case id, heroId, heroName, isCarry, isSubCarry, isCore, price, heroStarNum, position
        case sampleCount, playRate, avgPlacement, top4Rate, topRate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.id) ?? UUID().uuidString
        heroId = c.flexString(.heroId) ?? ""
        heroName = c.flexString(.heroName) ?? ""
        isCarry = c.flexBool(.isCarry)
        isSubCarry = c.flexBool(.isSubCarry)
        isCore = c.flexBool(.isCore)
        price = c.flexInt(.price) ?? 1
        star = c.flexInt(.heroStarNum)
        position = c.flexString(.position)
        sampleCount = c.flexInt(.sampleCount)
        playRate = c.flexDouble(.playRate)
        avgPlacement = c.flexDouble(.avgPlacement)
        top4Rate = c.flexDouble(.top4Rate)
        topRate = c.flexDouble(.topRate)
    }

    var boardRow: Int? { parsePosition()?.0 }
    var boardCol: Int? { parsePosition()?.1 }

    private func parsePosition() -> (Int, Int)? {
        guard let p = position else { return nil }
        let parts = p.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }
}

struct CompTrait: Decodable, Identifiable, Hashable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey { case id, name }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.id) ?? UUID().uuidString
        name = c.flexString(.name) ?? ""
    }
}

struct CompEquipRef: Decodable, Hashable {
    let heroId: String
    let equipId: String
    let compHeroId: String

    enum CodingKeys: String, CodingKey { case heroId, equipId, compHeroId }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        heroId = c.flexString(.heroId) ?? ""
        equipId = c.flexString(.equipId) ?? ""
        compHeroId = c.flexString(.compHeroId) ?? ""
    }
}

struct PlacementCount: Decodable, Identifiable, Hashable {
    var id: Int { ranking }
    let ranking: Int
    let count: Int

    enum CodingKeys: String, CodingKey { case ranking, count }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ranking = c.flexInt(.ranking) ?? 0
        count = c.flexInt(.count) ?? 0
    }
}

/// 排行列表与阵容详情共用同一结构；详情多出 desc / gameCode / placementDistribution
struct Comp: Decodable, Identifiable, Hashable {
    var id: String { compId }
    let compId: String
    let name: String
    let heroes: [CompHero]
    let traits: [CompTrait]
    let equips: [CompEquipRef]
    let top4Rate: Double?
    let topRate: Double?
    let pickRate: Double?
    let avgPlacement: Double?
    let sampleCount: Int?
    let tier: String?
    let dataMode: String?
    let desc: String?
    let gameCode: String?
    let placementDistribution: [PlacementCount]

    enum CodingKeys: String, CodingKey {
        case compId, name, heroes, traits, equips, top4Rate, topRate, pickRate, avgPlacement
        case sampleCount, tier, dataMode, desc, gameCode, placementDistribution
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        compId = c.flexString(.compId) ?? UUID().uuidString
        name = c.flexString(.name) ?? "未命名阵容"
        heroes = c.list(CompHero.self, .heroes)
        traits = c.list(CompTrait.self, .traits)
        equips = c.list(CompEquipRef.self, .equips)
        top4Rate = c.flexDouble(.top4Rate)
        topRate = c.flexDouble(.topRate)
        pickRate = c.flexDouble(.pickRate)
        avgPlacement = c.flexDouble(.avgPlacement)
        sampleCount = c.flexInt(.sampleCount)
        tier = c.flexString(.tier)
        dataMode = c.flexString(.dataMode)
        desc = c.flexString(.desc)
        gameCode = c.flexString(.gameCode)
        placementDistribution = c.list(PlacementCount.self, .placementDistribution)
    }

    static func == (l: Comp, r: Comp) -> Bool { l.compId == r.compId }
    func hash(into h: inout Hasher) { h.combine(compId) }

    var carry: CompHero? { heroes.first(where: { $0.isCarry }) ?? heroes.first }

    func equips(for hero: CompHero) -> [CompEquipRef] {
        equips.filter { $0.compHeroId == hero.id }
    }
}

// MARK: - 详情页统计

struct EquipStat: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let picture: String?
    let type: String?
    let sampleCount: Int?
    let playRate: Double?
    let avgPlacement: Double?
    let top4Rate: Double?
    let topRate: Double?

    enum CodingKeys: String, CodingKey {
        case equipId, name, picture, type, sampleCount, playRate, avgPlacement, top4Rate, topRate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.equipId) ?? UUID().uuidString
        name = c.flexString(.name) ?? ""
        picture = c.flexString(.picture)
        type = c.flexString(.type)
        sampleCount = c.flexInt(.sampleCount)
        playRate = c.flexDouble(.playRate)
        avgPlacement = c.flexDouble(.avgPlacement)
        top4Rate = c.flexDouble(.top4Rate)
        topRate = c.flexDouble(.topRate)
    }
}

struct HexStat: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String?
    let level: Int?
    let sampleCount: Int?
    let playRate: Double?
    let avgPlacement: Double?
    let top4Rate: Double?
    let topRate: Double?
    let tier: String?
    let placementDelta: Double?

    enum CodingKeys: String, CodingKey {
        case hexId, name, icon, level, sampleCount, playRate, avgPlacement, top4Rate, topRate, tier, placementDelta
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.hexId) ?? UUID().uuidString
        name = c.flexString(.name) ?? ""
        icon = c.flexString(.icon)
        level = c.flexInt(.level)
        sampleCount = c.flexInt(.sampleCount)
        playRate = c.flexDouble(.playRate)
        avgPlacement = c.flexDouble(.avgPlacement)
        top4Rate = c.flexDouble(.top4Rate)
        topRate = c.flexDouble(.topRate)
        tier = c.flexString(.tier)
        placementDelta = c.flexDouble(.placementDelta)
    }
}

struct TrendPoint: Decodable, Identifiable, Hashable {
    var id: String { date }
    let date: String
    let playRate: Double?
    let avgPlacement: Double?
    let top4Rate: Double?
    let topRate: Double?
    let sampleCount: Int?

    enum CodingKeys: String, CodingKey { case date, playRate, avgPlacement, top4Rate, topRate, sampleCount }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = c.flexString(.date) ?? ""
        playRate = c.flexDouble(.playRate)
        avgPlacement = c.flexDouble(.avgPlacement)
        top4Rate = c.flexDouble(.top4Rate)
        topRate = c.flexDouble(.topRate)
        sampleCount = c.flexInt(.sampleCount)
    }

    /// "2026-11-06" → "11-06"
    var shortDate: String { date.count >= 10 ? String(date.suffix(5)) : date }
}

struct CompHeroesResponse: Decodable { let heroes: [CompHero]? }
struct CompEquipsResponse: Decodable { let equips: [EquipStat]? }
struct CompHexesResponse: Decodable { let hexes: [HexStat]? }
struct CompTrendResponse: Decodable { let trend: [TrendPoint]? }

// MARK: - 赛季基础资料（头像、装备图标、羁绊图标）

struct GDHero: Decodable {
    let id: String
    let name: String
    let picture: String?
    let price: Int?

    enum CodingKeys: String, CodingKey { case id, name, picture, price }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.id) ?? ""
        name = c.flexString(.name) ?? ""
        picture = c.flexString(.picture)
        price = c.flexInt(.price)
    }
}

struct GDTrait: Decodable {
    let id: String
    let name: String
    let picture: String?
    let color: Int?

    enum CodingKeys: String, CodingKey { case id, name, picture, color }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.id) ?? ""
        name = c.flexString(.name) ?? ""
        picture = c.flexString(.picture)
        color = c.flexInt(.color)
    }
}

struct GDEquip: Decodable {
    let id: String
    let name: String
    let picture: String?

    enum CodingKeys: String, CodingKey { case id, name, picture }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.id) ?? ""
        name = c.flexString(.name) ?? ""
        picture = c.flexString(.picture)
    }
}

struct GameData: Decodable {
    let hero: [GDHero]
    let trait: [GDTrait]
    let equip: [GDEquip]

    enum CodingKeys: String, CodingKey { case hero, trait, equip }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hero = c.list(GDHero.self, .hero)
        trait = c.list(GDTrait.self, .trait)
        equip = c.list(GDEquip.self, .equip)
    }
}

/// 把基础资料建成查找表
struct GameDataIndex {
    private var heroById: [String: GDHero] = [:]
    private var heroByName: [String: GDHero] = [:]
    private var traitById: [String: GDTrait] = [:]
    private var equipById: [String: GDEquip] = [:]

    static let empty = GameDataIndex()

    init() {}

    init(_ g: GameData) {
        for h in g.hero {
            heroById[h.id] = h
            if heroByName[h.name] == nil { heroByName[h.name] = h }
        }
        for t in g.trait { traitById[t.id] = t }
        for e in g.equip { equipById[e.id] = e }
    }

    /// 阵容里的 heroId 是 "1508"，资料里是 "11508"（模式前缀 + id），所以多试几种
    func hero(_ heroId: String, name: String) -> GDHero? {
        heroById[heroId] ?? heroById["1" + heroId] ?? heroByName[name]
    }

    func trait(_ id: String) -> GDTrait? { traitById[id] }
    func equip(_ id: String) -> GDEquip? { equipById[id] }
}
