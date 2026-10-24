import SwiftUI

public struct ContentView: View {
    @ObservedObject var player = AudioPlayerService.shared

    @State private var selectedTab: Int = 0
    @State private var showNowPlayingSheet: Bool = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(onNavigateToChat: { selectedTab = 3 })
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                SearchView(onNavigateToChat: { selectedTab = 3 })
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }
                    .tag(2)

                ChatView()
                    .tabItem {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .tag(3)
            }
            .accentColor(Color(hex: "06B6D4"))

            // Floating Mini PlayerBar
            if player.currentSong != nil {
                PlayerBarView(onTap: {
                    showNowPlayingSheet = true
                })
                .padding(.horizontal, 12)
                .padding(.bottom, 56)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showNowPlayingSheet) {
            NowPlayingView(
                onDismiss: { showNowPlayingSheet = false },
                onNavigateToChat: {
                    showNowPlayingSheet = false
                    selectedTab = 3
                }
            )
        }
    }
}
