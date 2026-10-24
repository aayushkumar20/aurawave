# Aura Music: Dual-Native Ad-Free YouTube Music Player & Chat Rooms

Aura Music is a dual-native music streaming and real-time chat application built natively in **Kotlin + Jetpack Compose** for Android and **Swift + SwiftUI** for iOS. It streams raw, high-fidelity audio directly from YouTube Music with **100% ad-blocking (zero video or audio ads)**, requiring **no Google sign-in**.

---

## 🚀 Key Features

- **100% Real-Time Live YouTube Music Streaming**:
  - Direct Piped/Innertube bitstream extraction (Opus/AAC audio).
  - No hardcoded lists or placeholder images: live trending charts and high-res YouTube artwork (`i.ytimg.com`).
  - **Zero Ads**: completely filters out video ads, sponsor banners, and Google tracking.
- **Live Search Auto-Complete & Recommendations**:
  - Live search suggestions as you type directly from YouTube's autocomplete engine.
- **Queue Controls**:
  - **Play Next**: Inserts the selected song immediately after the current playing track.
  - **Play Last**: Appends the selected song to the end of your playback queue.
  - Full playback queue reordering and shuffle/repeat modes.
- **Custom Playlists & Favorites**:
  - Save songs to offline-first local favorites and create custom playlists.
- **Real-Time Music Chat Rooms (Google Firebase Database)**:
  - **Zero Login Friction**: Join instantly just by entering your **Name** and **Date of Birth (DOB)**.
  - Chat rooms (`#Global Music Lounge`, `#Late Night Vibes`, `#Bass & Electronic`).
  - **Emoji Reactions**: React to any message with emojis (❤️, 🔥, 🎧, 👏, 😂, 🚀).
  - **Live Song Sharing Cards**: Share your currently playing song into the room with an interactive "▶ Play Now" and "Play Next" card.
- **Background Playback & Lock-Screen Integration**:
  - Android: `MediaSessionService` + Notification controls.
  - iOS: `AVPlayer` + `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`.

---

## 📱 Installation & Distribution

### 1. Android (Ready-to-Install APK)
The compiled standalone APK is ready in the repository:
```
build-artifacts/AuraMusic-Android.apk (19 MB)
```
**To install on any Android phone:**
1. Transfer `build-artifacts/AuraMusic-Android.apk` to your phone via USB cable, WhatsApp, Telegram, or Google Drive.
2. Tap the file on your phone and click **Install** (enable *"Install unknown apps"* if prompted).
3. Open **Aura Music** and enjoy ad-free music!

**To re-build the APK:**
```bash
cd android
./gradlew assembleDebug
```

---

### 2. iOS (Install on Any iPhone)
Because Apple restricts direct `.ipa` installation without code-signing, you can install the native Swift/SwiftUI app on **any iPhone** using one of the following methods (no paid developer account required):

#### Method A: Sideloadly or AltStore (Recommended, 2 Minutes)
1. Download **[Sideloadly](https://sideloadly.io/)** or **[AltStore](https://altstore.io/)** on your Mac/PC.
2. Connect your iPhone to your Mac via USB cable.
3. Open `ios/Package.swift` in Xcode or export an `.ipa`, drag it into Sideloadly, enter your Apple ID, and click **Start**.
4. The app installs directly onto your iPhone! (Go to *Settings > General > VPN & Device Management* and tap *Trust*).

#### Method B: Direct Xcode Run (Immediate on Mac)
1. Open the project in Xcode:
   ```bash
   open ios/Package.swift
   ```
2. Connect your iPhone via USB, select your device in the top device toolbar, and hit **Cmd + R (Run)**.
3. The native app will install and launch instantly on your iPhone.

---

## 🔥 Google Firebase Database Setup

Aura Music connects seamlessly to Google Firebase Realtime Database for live room chat and emoji reactions.

1. Create a project at [Firebase Console](https://console.firebase.google.com/).
2. Enable **Realtime Database** under *Build > Realtime Database*.
3. Deploy the included security rules:
   ```bash
   cd firebase
   firebase deploy --only database
   ```
4. Update the database URL in:
   - Android: `ChatManager.firebaseDatabaseUrl`
   - iOS: `ChatService.shared.firebaseDatabaseUrl`

---

## 📂 Repository Structure

```
├── android/               # Native Android (Kotlin + Jetpack Compose + Media3)
│   ├── app/src/main/
│   │   ├── AndroidManifest.xml
│   │   └── java/com/auramusic/app/
│   │       ├── MainActivity.kt
│   │       ├── data/api/YouTubeMusicEngine.kt
│   │       ├── player/PlaybackManager.kt
│   │       ├── repository/ChatManager.kt
│   │       └── ui/screens/ (HomeScreen, SearchScreen, LibraryScreen, ChatScreen, NowPlayingSheet)
├── ios/                   # Native iOS (Swift + SwiftUI + AVPlayer)
│   ├── Package.swift
│   └── AuraMusic/
│       ├── AuraMusicApp.swift
│       ├── Info.plist
│       ├── Services/ (YouTubeMusicEngine.swift, AudioPlayerService.swift, ChatService.swift)
│       └── Views/ (HomeView, SearchView, LibraryView, ChatView, NowPlayingView)
├── firebase/              # Firebase Database Rules & Configuration
│   ├── database.rules.json
│   ├── google-services.json
│   └── GoogleService-Info.plist
└── build-artifacts/
    └── AuraMusic-Android.apk  # Ready-to-transfer Android APK
```

---

## 📄 License
MIT
