import Foundation
import UIKit

enum APIError: LocalizedError {
    case server(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .server(let m): return m
        case .empty: return "没有数据"
        }
    }
}

/// dataj.cc 网页版用的公开接口（/api/web/...）。
/// 每次成功的响应都存一份到缓存目录，断网时自动用上次的数据。
final class API {
    static let shared = API()

    private let base = "https://www.dataj.cc/api/web/"
    private let session: URLSession
    private let cacheDir: URL

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.httpAdditionalHeaders = [
            "Referer": "https://www.dataj.cc/comp",
            "Accept": "application/json"
        ]
        session = URLSession(configuration: cfg)
        cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("api", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: 通用请求

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        guard var comps = URLComponents(string: base + path) else { throw APIError.server("地址错误") }
        if !query.isEmpty {
            comps.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw APIError.server("地址错误") }
        let cacheFile = cacheDir.appendingPathComponent(cacheName(for: url))

        do {
            let (data, resp) = try await session.data(from: url)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw APIError.server("服务器返回 \(http.statusCode)")
            }
            let value: T = try decode(data)
            try? data.write(to: cacheFile, options: .atomic)
            return value
        } catch {
            if let data = try? Data(contentsOf: cacheFile), let value: T = try? decode(data) {
                return value
            }
            throw error
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let env = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
        if env.success == false { throw APIError.server(env.message ?? "请求失败") }
        guard let d = env.data else { throw APIError.empty }
        return d
    }

    private func cacheName(for url: URL) -> String {
        let s = url.absoluteString.replacingOccurrences(of: base, with: "")
        let safe = String(s.map { $0.isLetter || $0.isNumber ? $0 : "_" })
        return String(safe.prefix(200)) + ".json"
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        ImageLoader.shared.clear()
    }

    // MARK: 具体接口

    func versions(setId: Int) async throws -> [GameVersion] {
        try await get("gamedata/gameVersion", query: ["setId": "\(setId)"])
    }

    func gameData(setId: Int) async throws -> GameData {
        try await get("gamedata", query: ["setId": "\(setId)"])
    }

    func rankings(setId: Int, version: String) async throws -> [Comp] {
        try await get("comp/rank", query: ["setId": "\(setId)", "gameVersion": version, "minSample": "1"])
    }

    private func q(_ setId: Int, _ version: String) -> [String: String] {
        ["setId": "\(setId)", "gameVersion": version]
    }

    func detail(compId: String, setId: Int, version: String) async throws -> Comp {
        try await get("comp/\(compId)", query: q(setId, version))
    }

    func heroes(compId: String, setId: Int, version: String) async throws -> [CompHero] {
        let r: CompHeroesResponse = try await get("comp/\(compId)/heroes", query: q(setId, version))
        return r.heroes ?? []
    }

    func equips(compId: String, setId: Int, version: String) async throws -> [EquipStat] {
        let r: CompEquipsResponse = try await get("comp/\(compId)/equips", query: q(setId, version))
        return r.equips ?? []
    }

    func hexes(compId: String, setId: Int, version: String) async throws -> [HexStat] {
        let r: CompHexesResponse = try await get("comp/\(compId)/hexes", query: q(setId, version))
        return r.hexes ?? []
    }

    /// 各人口阶段最常见的站位（每个阶段前 3 套）
    func battleBuilds(compId: String, setId: Int, version: String) async throws -> [BattleBuildGroup] {
        try await get("comp/\(compId)/battle-builds", query: q(setId, version))
    }

    /// dataj.cc 生成好的一图流长图
    func singleImage(compId: String, setId: Int, version: String) async throws -> SingleImage {
        try await get("comp/\(compId)/single-image", query: q(setId, version))
    }

    func trend(compId: String) async throws -> [TrendPoint] {
        let r: CompTrendResponse = try await get("comp/\(compId)/trend")
        return r.trend ?? []
    }
}

// MARK: - 图片加载（带 Referer，内存 + 磁盘缓存）

final class ImageLoader {
    static let shared = ImageLoader()

    private let memory = NSCache<NSURL, UIImage>()
    private let urlCache = URLCache(memoryCapacity: 20 << 20, diskCapacity: 200 << 20)
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = urlCache
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.httpAdditionalHeaders = ["Referer": "https://www.dataj.cc/"]
        session = URLSession(configuration: cfg)
    }

    func cached(_ url: URL) -> UIImage? { memory.object(forKey: url as NSURL) }

    func load(_ url: URL) async -> UIImage? {
        if let img = cached(url) { return img }
        guard let result = try? await session.data(from: url), let img = UIImage(data: result.0) else { return nil }
        memory.setObject(img, forKey: url as NSURL)
        return img
    }

    func clear() {
        memory.removeAllObjects()
        urlCache.removeAllCachedResponses()
    }
}
