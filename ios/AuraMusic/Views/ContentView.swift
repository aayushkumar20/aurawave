import SwiftUI

public struct ContentView: View {
    @ObservedObject var player = AudioPlayerService.shared

    @State private var selectedTab: Int = 0
    @State private var showNowPlayingSheet: Bool = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Active View Container
            Group {
                switch selectedTab {
                case 0:
                    HomeView(onNavigateToChat: { selectedTab = 3 })
                case 1:
                    SearchView(onNavigateToChat: { selectedTab = 3 })
                case 2:
                    LibraryView()
                case 3:
                    ChatView()
                default:
                    HomeView(onNavigateToChat: { selectedTab = 3 })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Docked Player Bar & Bottom Navigation Stack
            VStack(spacing: 0) {
                // Mini Player Bar (Sits directly above navigation)
                if player.currentSong != nil {
                    PlayerBarView(onTap: {
                        showNowPlayingSheet = true
                    })
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Sleek Glassmorphic Bottom Navigation Bar
                customBottomBar
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.clear,
                        AuraColors.background.opacity(0.85),
                        AuraColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )

            // Invisible Background WebKit Player (Keeps background audio active)
            YouTubeBackgroundPlayerView()
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .background(AuraColors.background.ignoresSafeArea())
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

    // -------------------------------------------------------------
    // Custom Glassmorphic Navigation Bar
    // -------------------------------------------------------------
    private var customBottomBar: some View {
        HStack(spacing: 0) {
            navItem(tab: 0, title: "Home", icon: "house.fill")
            navItem(tab: 1, title: "Search", icon: "magnifyingglass")
            navItem(tab: 2, title: "Library", icon: "music.note.list")
            navItem(tab: 3, title: "Chat", icon: "bubble.left.and.bubble.right.fill")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AuraColors.surface.opacity(0.95))
                .shadow(color: Color.black.opacity(0.5), radius: 16, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func navItem(tab: Int, title: String, icon: String) -> some View {
        let isSelected = selectedTab == tab
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? AuraColors.cyan : AuraColors.textSecondary)
                    .scaleEffect(isSelected ? 1.15 : 1.0)

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : AuraColors.textMuted)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
