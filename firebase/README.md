# Google Firebase Database Setup for Aura Music

Aura Music uses **Google Firebase Realtime Database** for instant, zero-login music chat rooms, live message broadcasting, emoji reactions, and real-time song sharing.

## 1. Quick Setup in Firebase Console (1 Minute)

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project (e.g. `aura-music`).
2. Navigate to **Build > Realtime Database** and click **Create Database**.
3. Select your location and choose **Start in test mode** (or import `database.rules.json`).
4. Copy your Realtime Database URL (e.g., `https://your-project-default-rtdb.firebaseio.com`).
5. In the app:
   - Android: `ChatManager.firebaseDatabaseUrl = "https://your-project-default-rtdb.firebaseio.com"`
   - iOS: `ChatService.shared.firebaseDatabaseUrl = "https://your-project-default-rtdb.firebaseio.com"`

## 2. Deploy Database Rules via Firebase CLI

```bash
cd firebase
npm install -g firebase-tools
firebase login
firebase init database
firebase deploy --only database
```

## 3. Data Structure

```json
{
  "rooms": {
    "room_global": {
      "messages": {
        "msg_1710000000": {
          "id": "msg_1710000000",
          "senderId": "user_alex_14052002",
          "senderName": "Alex",
          "text": "Check out this song live!",
          "timestamp": 1710000000,
          "reactions": { "🔥": 3, "❤️": 2 }
        }
      }
    }
  }
}
```
