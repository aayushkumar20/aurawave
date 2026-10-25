# 🌊 AuraWave: Ad-Free Music Streaming & Real-Time Collaborative Lounges

[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web-blue.svg)](https://github.com/aayushkumar20/aurawave)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ads](https://img.shields.io/badge/Ads-Zero%20(100%25%20Ad--Blocked)-brightgreen.svg)](#)
[![Google Sign-In](https://img.shields.io/badge/Google%20Sign--In-None%20Required-success.svg)](#)
[![Sync](https://img.shields.io/badge/Real--Time%20Sync-Android%20%E2%87%84%20iOS%20%E2%87%84%20Web-purple.svg)](#)

**AuraWave** is a high-performance, cross-platform music streaming and real-time collaborative party listening player built natively in **Kotlin + Jetpack Compose** for Android, **Swift + SwiftUI** for iOS, and a progressive **Web Player**. It streams high-fidelity audio directly from YouTube Music with **100% ad-blocking (zero audio or video ads)**, requiring **no Google sign-in**, accounts, or tracking.

---

## 🌟 Core Benefits & Why Use This?

| Benefit | How It Helps You |
| :--- | :--- |
| **🚫 Zero Google Sign-In** | No Google account, email, or credentials required. You are never tracked, profiled, or locked into proprietary ecosystem accounts. |
| **🛡️ 100% Ad-Free (Zero Ads)** | Completely blocks all pre-roll video ads, mid-roll audio ads, popups, and sponsored banners. Uninterrupted music streaming from start to finish. |
| **🔒 Safe, Private & Sandboxed** | Operates strictly as a client. **No open ports, no listening background servers, and no dangerous permissions**. Runs securely inside native mobile OS sandboxes. |
| **🎧 Full Background & Lock-Screen Playback** | Keep listening with full notification drawer and lock-screen media controls (play, pause, skip, seek, artwork) on both Android and iOS while your screen is off or you are using other apps. |
| **👥 Collaborative Group Playlists & Live Chat** | Create or join live music lounges via a simple code (e.g., `AURA-1024`). Any group member can search and add songs in real time to build a shared queue with synced playback. |
| **⚡ Fast Live Autocomplete Search** | Instant query suggestions and track search straight from YouTube Music's high-speed catalog without lag. |
| **💾 Completely Free & Open Source** | Zero subscription fees, zero premium paywalls, zero in-app purchases. MIT licensed for full transparency. |

---

## ⚙️ How It Works (Under the Hood)

### 1. Direct Audio Bitstream Extraction (Ad-Bypass Architecture)
Traditional YouTube clients load video advertisements, tracking telemetry, and heavy UI scripts before playing media. 
- **Direct Querying**: The player queries YouTube's production **InnerTube API** and privacy-preserving extraction engines directly.
- **Pure Audio Bitstream**: It extracts the raw high-bitrate audio streams (such as **Opus 160kbps** or **AAC 128kbps**) and streams them directly into native platform audio decoders:
  - **Android**: Uses Google's **Jetpack Media3 / ExoPlayer** running within an independent foreground `MediaSessionService`.
  - **iOS**: Uses Apple's **AVFoundation (`AVPlayer`)** registered with `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`.
  - **Web**: Uses an embedded background playback coordinator with custom visualizer controls.
- **Result**: Because ad servers and video tracking URLs are completely bypassed, you get instant playback with zero commercial interruptions.

### 2. Real-Time Cross-Platform Synchronization
Cross-platform synchronization (between Android, iOS, and Web) operates via a lightweight, zero-latency streaming pipeline:
- **Zero-Friction Rooms**: Rooms are identified by human-readable names or codes (e.g. `room_global` or `AURA-4921`).
- **Persistent Server-Sent Events (SSE)**: Devices connect to an active real-time pub/sub stream with an open HTTP keep-alive connection (`readTimeout = 0`).
- **Standardized Sync Packets (`GroupSyncPacket`)**:
  - `CHAT_MSG`: Real-time text messages and emoji reactions.
  - `PLAYLIST_ADD`: Broadcasts when any user adds a track to the collaborative playlist, updating the queue on all room members' screens immediately.
  - `SYNC_PLAYBACK`: Synchronizes play/pause state and playback position (timestamps) across devices.
- **Lenient Cross-Platform Deserialization**: Swift and Kotlin handle timestamps and numbers resiliently through custom adapters, ensuring fractional and whole-millisecond epoch timestamps communicate without serialization crashes.

---

## 📂 Repository & Project Structure

```
aurawave/
│
├── AuraMusic-latest.apk       # Pre-compiled latest Android standalone APK (Ready to install)
├── LICENSE                    # MIT Open Source License
├── README.md                  # Comprehensive Documentation & Architecture Guide
│
├── android/                   # Native Android Project (Kotlin + Jetpack Compose)
│   ├── app/
│   │   ├── build.gradle.kts   # Android dependencies (Media3, Compose, Coil, Gson, OkHttp)
│   │   └── src/main/
│   │       ├── AndroidManifest.xml # Standard permissions (Internet, Media Playback Foreground Service)
│   │       └── java/com/auramusic/app/
│   │           ├── MainActivity.kt               # Main entry point & Jetpack Compose navigation
│   │           ├── AuraApplication.kt           # App lifecycle container
│   │           ├── data/
│   │           │   ├── models/Models.kt          # Song, ChatMessage, GroupSyncPacket data classes
│   │           │   ├── api/YouTubeMusicEngine.kt # Live search, suggestions & trending track parser
│   │           │   └── repository/ChatManager.kt # Real-time streaming, rooms & collaborative playlist
│   │           ├── player/
│   │           │   ├── PlaybackManager.kt        # Audio state machine, queues (Play Next/Last)
│   │           │   ├── PlaybackService.kt        # Background MediaSessionService for lock-screen
│   │           │   └── YouTubeAudioEngine.kt     # Direct stream URL extractor
│   │           └── ui/
│   │               ├── screens/
│   │               │   ├── HomeScreen.kt         # Trending charts & quick recommendations
│   │               │   ├── SearchScreen.kt       # Live autocomplete & filter chips
│   │               │   ├── LibraryScreen.kt      # Offline-first custom playlists & favorites
│   │               │   ├── ChatScreen.kt         # Real-time room chat, in-group song search & queue
│   │               │   └── NowPlayingSheet.kt    # Full-screen player with lyrics & visualizer
│   │               └── theme/                    # Futuristic dark-mode design system
│
├── ios/                       # Native iOS Project (Swift + SwiftUI + AVFoundation)
│   ├── AuraMusic.xcodeproj   # Xcode Project configuration
│   ├── Package.swift          # Swift Package Manager definitions
│   └── AuraMusic/
│       ├── AuraMusicApp.swift                    # iOS App Entry Point
│       ├── Info.plist                            # Background audio mode configuration
│       ├── Models/
│       │   └── Models.swift                      # Strongly-typed Codable Song, Room & Packet structs
│       ├── Services/
│       │   ├── AudioPlayerService.swift          # AVPlayer + Lock-Screen NowPlaying & Remote Commands
│       │   ├── YouTubeMusicEngine.swift          # Live InnerTube YouTube search & stream engine
│       │   └── ChatService.swift                 # Real-time room SSE streaming & sync manager
│       └── Views/
│           ├── HomeView.swift                    # iOS Trending music view
│           ├── SearchView.swift                  # Autocomplete search & discovery
│           ├── LibraryView.swift                 # Local playlists & favorited songs
│           ├── ChatView.swift                    # Live room chat, collaborative playlist & search drawer
│           └── NowPlayingView.swift              # iOS Now Playing sheet & playback controls
│
└── firebase/                  # Web Client & Cloud Configuration
    ├── database.rules.json    # Realtime Database security rules
    ├── firebase.json          # Hosting & deployment configuration
    └── public/                # Full Web Player Client
        ├── index.html         # Responsive web UI layout
        ├── style.css          # Glassmorphism dark-mode CSS styles
        └── app.js             # Web audio player, background YouTube engine, room chat & SSE sync
```

---

## 📱 Installation & Getting Started

### 1. Android Installation

#### Option A: Install Ready APK via USB (ADB)
If your Android phone is connected to your computer:
```bash
adb install -r "AuraMusic-latest.apk"
```

#### Option B: Direct Phone Download / Transfer
1. Transfer [`AuraMusic-latest.apk`](file:///Users/aayushkumar/Desktop/Music%20player/AuraMusic-latest.apk) to your Android device via USB, Google Drive, WhatsApp, or local share.
2. Tap the APK file and select **Install** (enable *"Install from unknown sources"* if prompted).
3. Open **Aura Music** and start listening immediately without signing in!

#### Option C: Build from Source
```bash
cd android
./gradlew assembleDebug
```
The compiled APK will be located at `android/app/build/outputs/apk/debug/app-debug.apk`.

---

### 2. iOS Installation

Because Apple requires code-signing on physical iOS devices, you can install the native app on **any iPhone** using one of the following methods:

#### Method A: Xcode Direct Install (Free)
1. Open the project in Xcode:
   ```bash
   open ios/AuraMusic.xcodeproj
   ```
2. Connect your iPhone via USB.
3. Select your iPhone as the build target in Xcode's top bar.
4. Under `Signing & Capabilities`, choose your free personal Apple ID Team.
5. Press `Cmd + R` to build and run. The app will install directly onto your iPhone.

#### Method B: Sideloading (AltStore or Sideloadly)
1. Download [Sideloadly](https://sideloadly.io/) or [AltStore](https://altstore.io/).
2. Build the `.ipa` or load the Xcode project file.
3. Sideload the app using your Apple ID (valid for 7 days on free developer accounts).

---

### 3. Web Player (Any Browser)
To run the web player locally:
```bash
npx serve firebase/public
```
Or open `firebase/public/index.html` in your web browser.

---

## 🔒 Security & Privacy Policy

- **No Inbound Open Ports**: The application functions 100% as an outbound client. It never listens on network sockets or binds local web servers.
- **No Dangerous Permissions**: It does not access your location, contacts, camera, photos, SMS, or phone state.
- **No Tracking Telemetry**: Built without advertising trackers, analytics SDKs, or commercial spyware.

---

## 📄 License
This project is open-source under the [MIT License](LICENSE).
Feel free to contribute, fork, and enhance the experience!
