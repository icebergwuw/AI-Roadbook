import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                Text("首页")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .tabItem { Label("首页", systemImage: "house.fill") }

            NavigationStack {
                Text("行程")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .tabItem { Label("行程", systemImage: "calendar") }

            NavigationStack {
                Text("新建")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .tabItem { Label("新建", systemImage: "plus.circle.fill") }

            NavigationStack {
                Text("探索")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .tabItem { Label("探索", systemImage: "safari.fill") }

            NavigationStack {
                Text("设置")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
