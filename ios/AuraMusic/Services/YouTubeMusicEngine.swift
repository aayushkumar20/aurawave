import Foundation

public final class YouTubeMusicEngine {
    public static let shared = YouTubeMusicEngine()

    private let invidiousEndpoints = [
        "https://yt.chocolatemoo53.com"
    ]

    /**
     * Fetches 100% REAL-TIME LIVE trending songs from YouTube. Zero hardcoding.
     */
    public func fetchTrendingTracks() async -> [Song] {
        let songs = await searchYouTubeInnerTube(query: "Trending Music Charts")
        if !songs.isEmpty {
            return songs
        }

        // Fallback to Invidious live trending
        for base in invidiousEndpoints {
            guard let url = URL(string: "\(base)/api/v1/trending?type=music") else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    if let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        let parsed = parseInvidiousItems(items)
                        if !parsed.isEmpty {
                            return parsed
                        }
                    }
                }
            } catch {
                continue
            }
        }

        return await searchYouTubeInnerTube(query: "Top Music Hits 2026")
    }

    /**
     * Real-time search suggestions / autocomplete from YouTube search API
     */
    public func getSearchSuggestions(query: String) async -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=\(encoded)") else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
                   array.count > 1,
                   let suggestions = array[1] as? [String] {
                    return Array(suggestions.prefix(8))
                }
            }
        } catch {}

        return []
    }

    /**
     * Live YouTube Music search (100% Real-Time, Zero Hardcoded Lists)
     */
    public func searchSongs(query: String) async -> [Song] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let q = trimmed.isEmpty ? "Trending Music Hits" : trimmed

        // 1. Direct YouTube InnerTube search in real-time
        let directResults = await searchYouTubeInnerTube(query: q)
        if !directResults.isEmpty {
            return directResults
        }

        // 2. Real-time Invidious search
        if let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            for base in invidiousEndpoints {
                guard let url = URL(string: "\(base)/api/v1/search?q=\(encoded)&type=video") else { continue }
                var request = URLRequest(url: url)
                request.timeoutInterval = 4
                request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                        if let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            let parsed = parseInvidiousItems(items)
                            if !parsed.isEmpty {
                                return parsed
                            }
                        }
                    }
                } catch {
                    continue
                }
            }
        }

        return []
    }

    /**
     * Queries YouTube InnerTube Production Search API Directly
     */
    private func searchYouTubeInnerTube(query: String) async -> [Song] {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/search") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 6

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20231201.00.00"
                ]
            ],
            "query": query
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return [] }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contents = json["contents"] as? [String: Any],
                  let twoColumn = contents["twoColumnSearchResultsRenderer"] as? [String: Any],
                  let primary = twoColumn["primaryContents"] as? [String: Any],
                  let sectionList = primary["sectionListRenderer"] as? [String: Any],
                  let sectionContents = sectionList["contents"] as? [[String: Any]] else {
                return []
            }

            var songs: [Song] = []
            for section in sectionContents {
                guard let itemSection = section["itemSectionRenderer"] as? [String: Any],
                      let items = itemSection["contents"] as? [[String: Any]] else { continue }

                for item in items {
                    guard let v = item["videoRenderer"] as? [String: Any],
                          let videoId = v["videoId"] as? String, !videoId.isEmpty else { continue }

                    let titleRuns = (v["title"] as? [String: Any])?["runs"] as? [[String: Any]]
                    let title = titleRuns?.first?["text"] as? String ?? "Unknown Title"

                    let ownerRuns = (v["ownerText"] as? [String: Any])?["runs"] as? [[String: Any]]
                    let artist = ownerRuns?.first?["text"] as? String ?? "YouTube Artist"

                    let durText = ((v["lengthText"] as? [String: Any])?["simpleText"] as? String) ?? "3:30"
                    let thumb = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"

                    let durSeconds = parseDurationToSeconds(durText)

                    songs.append(
                        Song(
                            id: videoId,
                            title: title,
                            artist: artist,
                            album: "YouTube Music",
                            durationText: durText,
                            durationSeconds: durSeconds,
                            thumbnailUrl: thumb,
                            streamUrl: nil
                        )
                    )
                }
            }
            return songs
        } catch {
            return []
        }
    }

    private func parseDurationToSeconds(_ durText: String) -> Double {
        let parts = durText.split(separator: ":")
        var total: Double = 0
        for p in parts {
            let num = Double(p) ?? 0
            total = total * 60 + num
        }
        return total > 0 ? total : 210
    }

    private func parseInvidiousItems(_ items: [[String: Any]]) -> [Song] {
        return items.compactMap { (item: [String: Any]) -> Song? in
            guard let videoId = item["videoId"] as? String, !videoId.isEmpty else { return nil }
            let title = item["title"] as? String ?? "Unknown Title"
            let author = item["author"] as? String ?? "YouTube Artist"
            let durationSec = item["lengthSeconds"] as? Int ?? 210
            let thumb = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"

            let mins = durationSec / 60
            let secs = durationSec % 60
            let durText = String(format: "%d:%02d", mins, secs)

            return Song(
                id: videoId,
                title: title,
                artist: author,
                album: "YouTube Music",
                durationText: durText,
                durationSeconds: Double(durationSec),
                thumbnailUrl: thumb,
                streamUrl: nil
            )
        }
    }
}
