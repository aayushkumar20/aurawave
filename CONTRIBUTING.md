# Contributing to AuraWave 🌊

Development requirements, architecture constraints, and contribution workflow for the AuraWave project.

---

## 📜 Core Project Principles & Rules

1. **🚫 Zero Google Sign-In & Zero User Tracking**:
   - Never add dependencies or SDKs that require Google accounts, third-party authentication, tracking analytics, or telemetry.
   - The user must always be able to launch the app and listen without signing in.

2. **🛡️ 100% Ad-Free Guarantee**:
   - Commercial ads (audio, video, banners, or popups) are strictly prohibited.
   - Direct audio bitstream extraction (Opus/AAC) must remain clean without loading tracking scripts or ad networks.

3. **🔒 Zero Inbound Listening Ports / Strict Sandbox**:
   - The app operates purely as a client over outbound HTTPS/TLS (port 443).
   - Never introduce `ServerSocket`, local HTTP servers, open ports, or dangerous Android/iOS permissions.

4. **📱 Dual-Native Fidelity**:
   - **Android**: Maintain modern Kotlin + Jetpack Compose with Google's Media3 / ExoPlayer foreground `MediaSessionService`.
   - **iOS**: Maintain native Swift + SwiftUI with AVFoundation (`AVPlayer`) and `MPNowPlayingInfoCenter`.
   - Keep cross-platform sync packets (`GroupSyncPacket`) standardized and lenient with number serialization (`Int64` / Kotlin `Long`).

---

## 🛠️ Development & Git Workflow

### 1. Branching Strategy
- The `main` branch is protected against direct force-pushes and accidental deletions.
- Always branch off `main` for new features or bug fixes:
  ```bash
  git checkout -b feature/your-feature-name
  # or
  git checkout -b fix/your-bugfix-name
  ```

### 2. Commit Message Guidelines
Keep commit messages descriptive and concise:
- `feat: add sleep timer to player controls`
- `fix: resolve iOS-to-Android timestamp deserialization`
- `docs: update architecture flowcharts in README`

### 3. Submitting a Pull Request (PR)
1. Push your branch to GitHub:
   ```bash
   git push -u origin feature/your-feature-name
   ```
2. Open a Pull Request pointing to `main`.
3. Provide a clear description of your changes, testing steps, and device/simulator platforms tested.
4. Once verified, merge via standard or squash merge and delete the feature branch.

---

## 🧪 Testing Before Submitting

### Android
Verify compilation and debug APK build:
```bash
cd android
./gradlew assembleDebug
```

### iOS
Verify compilation with `xcodebuild`:
```bash
xcodebuild -project ios/AuraMusic.xcodeproj -scheme AuraMusic -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

### Web
Test local hosting:
```bash
npx serve firebase/public
```

---

## 📄 License
By contributing to AuraWave, you agree that your contributions will be licensed under the [MIT License](LICENSE).
