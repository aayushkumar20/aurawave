#!/usr/bin/env python3
import http.server
import json
import os
import sys
import urllib.parse
import urllib.request

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
PUBLIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "firebase", "public")

def query_youtube_innertube(query):
    url = "https://www.youtube.com/youtubei/v1/search"
    payload = {
        "context": {
            "client": {
                "clientName": "WEB",
                "clientVersion": "2.20231201.00.00"
            }
        },
        "query": query
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode("utf-8"))
            contents = (
                data.get("contents", {})
                .get("twoColumnSearchResultsRenderer", {})
                .get("primaryContents", {})
                .get("sectionListRenderer", {})
                .get("contents", [])
            )
            songs = []
            for section in contents:
                item_section = section.get("itemSectionRenderer", {})
                items = item_section.get("contents", [])
                for item in items:
                    v = item.get("videoRenderer")
                    if not v:
                        continue
                    video_id = v.get("videoId")
                    if not video_id:
                        continue
                    
                    # Title
                    title_runs = v.get("title", {}).get("runs", [])
                    title = title_runs[0].get("text", "Unknown Title") if title_runs else "Unknown Title"
                    
                    # Artist / Channel
                    owner_runs = v.get("ownerText", {}).get("runs", [])
                    artist = owner_runs[0].get("text", "YouTube Music") if owner_runs else "YouTube Music"
                    
                    # Duration
                    dur_text = v.get("lengthText", {}).get("simpleText", "3:30")
                    dur_parts = dur_text.split(":")
                    dur_sec = 0
                    for p in dur_parts:
                        dur_sec = dur_sec * 60 + (int(p) if p.isdigit() else 0)
                    if dur_sec <= 0:
                        dur_sec = 210

                    songs.append({
                        "id": video_id,
                        "title": title,
                        "artist": artist,
                        "album": "YouTube Music",
                        "durationText": dur_text,
                        "durationSec": dur_sec,
                        "thumbnailUrl": f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"
                    })
            return songs
    except Exception as e:
        print(f"[InnerTube Error] {e}", file=sys.stderr)
        return []

def query_suggestions(query):
    try:
        encoded = urllib.parse.quote(query)
        url = f"https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q={encoded}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if len(data) > 1 and isinstance(data[1], list):
                return data[1][:8]
    except Exception:
        pass
    return []

class AuraHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=PUBLIC_DIR, **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query_params = urllib.parse.parse_qs(parsed.query)

        if path == "/api/trending":
            songs = query_youtube_innertube("Top Global Music Hits 2026")
            if not songs:
                songs = query_youtube_innertube("Trending Music Charts")
            self.send_json_response(songs)
            return

        if path == "/api/search":
            q = query_params.get("q", [""])[0].strip()
            if not q:
                songs = query_youtube_innertube("Top Global Music Hits 2026")
            else:
                songs = query_youtube_innertube(q)
            self.send_json_response(songs)
            return

        if path == "/api/suggest":
            q = query_params.get("q", [""])[0].strip()
            suggestions = query_suggestions(q)
            self.send_json_response(suggestions)
            return

        super().do_GET()

    def send_json_response(self, data):
        body = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == "__main__":
    print(f"🎵 Aura Music Server running on http://localhost:{PORT}")
    print(f"📁 Serving static assets from: {PUBLIC_DIR}")
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), AuraHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
