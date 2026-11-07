import SwiftUI

@main
struct JCCDataApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task { await model.loadAll() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView {
            RankListView()
                .tabItem { Label("阵容排行", systemImage: "list.number") }

            FavoritesView()
                .tabItem { Label("收藏", systemImage: "star") }

            CompareView()
                .tabItem { Label("对比", systemImage: "square.split.2x1") }
                .badge(model.compareItems.count)
        }
    }
}
