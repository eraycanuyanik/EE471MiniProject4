# robomunch_app — RoboMunch Flutter mobile app

Mobile front-end for Mini Project #4. Talks to two backends:

- **Backend Server 1** (Flask, your computer): chat + text-to-image.
- **Backend Server 2** (Django, cloud VM): `/get/resolution` + `/convert/grayscale`.

## What it does

| Button | What happens |
|--------|--------------|
| 🎤 Mic | Records your voice, converts to text on-device (`speech_to_text`), drops the transcript into the chat input box. |
| ➤ Send | Posts the chat input to Backend Server 1 → reply appears in the Chat output box. |
| 🖌 Paint | Posts the prompt to Backend Server 1 → generated image appears in the Image output box. |
| 🌗 colorize | Posts the current image to Backend Server 2 — first `/get/resolution` (shows e.g. *Original: 1024 × 1024*), then `/convert/grayscale` (replaces the image with its grayscale version). |
| ⚙️ Settings | Edit both backend URLs at runtime (saved in `SharedPreferences`). |

## First-time setup

Flutter project skeleton was created with `flutter create`. After cloning this repo, regenerate the platform folders once:

```bash
flutter create .                  # adds android/, ios/, etc. without touching lib/
flutter pub get
```

> If you already have those folders, just `flutter pub get`.

## Configure backend URLs

Either edit defaults in [`lib/config.dart`](lib/config.dart) **or** open the app, tap ⚙️ in the top-right, paste both URLs, hit *Save*.

```dart
class AppConfig {
  static const String defaultLocalhostBackend = "http://192.168.1.100:5000"; // your laptop's LAN IP
  static const String defaultCloudBackend     = "http://YOUR-VM-IP:8000";    // your cloud VM
}
```

> Find your laptop IP with `ipconfig getifaddr en0` (macOS) / `ipconfig` (Windows).
> The **phone and the laptop must be on the same Wi-Fi**. Eduroam / university Wi-Fi
> may block phone↔laptop traffic — use a phone hotspot or your home Wi-Fi instead.

## Run on a physical Android phone (recommended)

```bash
# 1) enable USB debugging on the phone, plug it in, accept the prompt
flutter devices                   # confirm the phone shows up
flutter run                       # builds and installs in debug mode
```

The first launch will request **microphone permission** (for `speech_to_text`).
Grant it, otherwise the mic button will show "Speech recognition not available".

## Run on iOS

`flutter create .` will generate the `ios/` folder. Open `ios/Runner.xcworkspace` in Xcode once, set your team for signing, then `flutter run`.
You'll also need to add the following entries to `ios/Runner/Info.plist` (if missing):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used to dictate chat messages.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Used to transcribe your voice into text.</string>
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsArbitraryLoads</key><true/></dict>
```

## Project structure

```
lib/
├── main.dart                       # full UI: art studio + chat studio
├── config.dart                     # default URLs
├── models/chat_turn.dart           # ChatRole, ChatTurn
├── services/
│   ├── local_backend.dart          # talks to Flask (chat + paint)
│   └── cloud_backend.dart          # talks to Django (resolution + grayscale)
└── widgets/settings_dialog.dart    # URL editor

android/app/src/main/
├── AndroidManifest.xml             # INTERNET + RECORD_AUDIO + speech queries
└── network_security_config.xml     # allow plain HTTP to LAN + VM
```

## Dependencies

| Package | Why |
|---------|-----|
| `http` | Talks to both backends. |
| `speech_to_text` | On-device voice input → text. |
| `permission_handler` | Mic permission helper. |
| `shared_preferences` | Persist edited backend URLs across launches. |

## Troubleshooting

- **"Connection refused" → Backend 1**: make sure Flask is listening on `0.0.0.0:5000` (it is in this fork) and your firewall allows inbound 5000 from your phone's IP.
- **"Connection refused" → Backend 2**: open port 8000 in the cloud VM's security group; verify `curl http://<VM-IP>:8000/health` works from your laptop first.
- **Mic does nothing**: revoke + re-grant microphone permission for the app in Android Settings; on Eduroam/restricted Wi-Fi, on-device STT still works but the chat send call won't.
