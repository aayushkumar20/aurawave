import SwiftUI

public struct SearchView: View {
    @ObservedObject var player = AudioPlayerService.shared
    public let onNavigateToChat: () -> Void

    @State private var query: String = ""
    @State private var results: [Song] = []
    @State private var suggestions: [String] = []
    @State private var isLoading: Bool = false
    @State private var selectedFilter: String = "All"
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var suggestTask: Task<Void, Never>? = nil

    private let filters = ["All", "Top Hits", "Hip-Hop", "Electronic", "Chill", "Rock"]

    public init(onNavigateToChat: @escaping () -> Void) {
        self.onNavigateToChat = onNavigateToChat
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 14) {
                Text("Live Search & Suggest")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "06B6D4"))

                    TextField("Search any song, artist, album live...", text: $query)
                        .foregroundColor(.white)
                        .onChange(of: query) { newQuery in
                            triggerSuggest(text: newQuery)
                            triggerSearch(text: newQuery)
                        }

                    if !query.isEmpty {
                        Button(action: {
                            query = ""
                            suggestions = []
                            results = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hex: "64748B"))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(hex: "131824"))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Real-time suggestions pills
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(suggestions, id: \.self) { item in
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "06B6D4"))
                                    Text(item)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "1E2536"))
                                .clipShape(Capsule())
                                .onTapGesture {
                                    query = item
                                    suggestions = []
                                    triggerSearch(text: item)
                                }
                            }
                        }
                    }
                }

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            let isSelected = selectedFilter == filter
                            Text(filter)
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? .white : Color(hex: "94A3B8"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color(hex: "6366F1") : Color(hex: "131824"))
                                .clipShape(Capsule())
                                .onTapGesture {
                                    selectedFilter = filter
                                    if filter != "All" {
                                        query = filter
                                        triggerSearch(text: filter)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(Color(hex: "06B6D4"))
                    .scaleEffect(1.2)
                Spacer()
            } else {
                let itemsToShow = results.isEmpty ? player.trendingSongs : results

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if results.isEmpty && !player.trendingSongs.isEmpty {
                            HStack {
                                Text("Trending Searches & Tracks")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "64748B"))
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                        }

                        ForEach(itemsToShow) { song in
                            SongRowView(
                                song: song,
                                isPlayingThisSong: player.currentSong?.id == song.id,
                                isFavorite: player.favorites.contains(song.id),
                                onPlay: { player.playSong(song) },
                                onPlayNext: { player.playNext(song) },
                                onPlayLast: { player.playLast(song) },
                                onToggleFavorite: { player.toggleFavorite(song) },
                                onShareToChat: onNavigateToChat
                            )
                            .padding(.horizontal, 20)
                        }
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .background(Color(hex: "090D16").ignoresSafeArea())
    }

    private func triggerSuggest(text: String) {
        suggestTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            suggestions = []
            return
        }

        suggestTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            let list = await YouTubeMusicEngine.shared.getSearchSuggestions(query: trimmed)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.suggestions = list
            }
        }
    }

    private func triggerSearch(text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            isLoading = false
            return
        }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let searchResults = await YouTubeMusicEngine.shared.searchSongs(query: trimmed)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.results = searchResults
                self.isLoading = false
            }
        }
    }
}
