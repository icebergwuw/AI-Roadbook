import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)

            TodayOverviewView(selectedTab: $selectedTab)
                .tabItem { Label("行程", systemImage: "calendar") }
                .tag(1)

            NewTripView()
                .tabItem { Label("新建", systemImage: "plus.circle.fill") }
                .tag(2)

            NavigationStack {
                Text("探索")
                    .foregroundColor(AppTheme.textPrimary)
            }
            .tabItem { Label("探索", systemImage: "safari.fill") }
            .tag(3)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
