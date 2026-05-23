# Oddtunes — Project Bible

> **Version:** 1.0.0 · **Last Updated:** 2026-05-07 · **Platform:** Android (arm64) + Windows (x64)

---

## 1. Vision & Goals

Oddtunes is a **cross-platform music acquisition and playback application** built with Flutter. It allows users to import playlists from Spotify, YouTube Music, and Gaana, resolve each track to a YouTube audio stream, download the audio, tag it with metadata, and play it locally — all in a retro-hardware-inspired UI.

### Core Value Proposition
- **Playlist portability** — Import playlists from any supported platform, download the audio, and own your music files locally.
- **Offline-first** — Once downloaded, music plays without any internet connection.
- **Cross-platform** — Runs on Android phones and Windows desktops from a single codebase.

---

## 2. Architecture Overview

```mermaid
graph TD
    subgraph Flutter UI
        A[MainScreen] --> B[HomeScreen]
        A --> C[SearchScreen]
        A --> D[ImportScreen]
        A --> E[SettingsScreen]
        B --> F[PlaylistDetailScreen]
        B --> G[NowPlayingScreen]
        B --> H[QueueScreen]
        D --> I[ConvertScreen]
    end

    subgraph State Management
        J[DownloadProvider] --> K[LibraryProvider]
    end

    subgraph Services
        L[MetadataService] --> M[SpotifyService]
        L --> N[YtMusicMetadataService]
        L --> O[GaanaService]
        P[YtMusicService] --> Q[YouTube Music API]
        R[DownloaderService] --> S{Platform?}
        S -->|Android| T[MethodChannel → YtDlpBridge.kt → Python yt-dlp]
        S -->|Windows| U[Process → yt-dlp.exe]
        V[FfmpegService] --> W[ffmpeg_kit_flutter]
        X[AudioService] --> Y[just_audio]
        Z[LibraryService] --> AA[Local filesystem]
    end
```

### Layer Breakdown

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI** | Flutter + Riverpod + Provider | Retro-hardware-styled screens |
| **State** | `ChangeNotifierProvider` | Download queue, library, playback |
| **Services** | Pure Dart + Platform Channels | Business logic, API calls, I/O |
| **Android Native** | Kotlin + Chaquopy (Python 3.14) | yt-dlp execution via embedded Python |
| **Windows Native** | Dart `Process` | Direct yt-dlp.exe execution |

---

## 3. Project Structure

```
oddtunes_app/
├── lib/
│   ├── main.dart                          # App entry, theme, providers
│   ├── core/
│   │   ├── constants.dart                 # Brand colors, sizes
│   │   ├── paths.dart                     # Platform output directory
│   │   ├── search_index.dart              # In-memory fuzzy search
│   │   └── utils.dart                     # Shared helpers
│   ├── models/
│   │   ├── track.dart                     # Track data model (id, title, artists, album, etc.)
│   │   ├── download_state.dart            # DownloadStatus enum + TrackDownloadState
│   │   └── saved_playlist.dart            # Persisted playlist model
│   ├── providers/
│   │   ├── download_provider.dart         # Download queue orchestration (parallel, pause/resume/stop)
│   │   └── library_provider.dart          # Scanned library + playlists state
│   ├── services/
│   │   ├── metadata_service.dart          # URL router → Spotify/YTMusic/Gaana
│   │   ├── spotify_service.dart           # Spotify HTML scraper (no API key needed)
│   │   ├── ytmusic_metadata_service.dart  # YouTube Music playlist/album metadata
│   │   ├── ytmusic_service.dart           # YouTube Music search + scoring algorithm
│   │   ├── gaana_service.dart             # Gaana.com HTML scraper
│   │   ├── downloader_service.dart        # Platform-aware download dispatcher
│   │   ├── ffmpeg_service.dart            # Audio tagging via FFmpeg (stream-copy + metadata)
│   │   ├── audio_service.dart             # Playback via just_audio
│   │   ├── library_service.dart           # File scanning + playlist persistence
│   │   └── feedback_service.dart          # Haptic feedback
│   ├── screens/
│   │   ├── main_screen.dart               # Bottom nav shell
│   │   ├── home_screen.dart               # Library browser (playlists, tracks, search)
│   │   ├── import_screen.dart             # URL input + fetch + download UI
│   │   ├── convert_screen.dart            # Batch conversion interface
│   │   ├── search_screen.dart             # Global search
│   │   ├── settings_screen.dart           # App configuration
│   │   ├── now_playing_screen.dart        # Full-screen player
│   │   ├── playlist_detail_screen.dart    # Playlist track listing
│   │   └── queue_screen.dart              # Playback queue
│   └── widgets/
│       ├── bottom_nav.dart                # Hardware-style bottom navigation
│       ├── hw_button.dart                 # Physical button component
│       ├── lcd_display.dart               # LCD text display widget
│       ├── mini_player.dart               # Persistent mini player bar
│       ├── panel.dart                     # Embossed panel container
│       └── track_download_tile.dart       # Download progress tile
│
├── android/
│   ├── build.gradle.kts                   # Root build (mavenCentral)
│   ├── settings.gradle.kts                # Chaquopy 17.0.0, AGP 8.11.1, Kotlin 2.2.20
│   └── app/
│       ├── build.gradle.kts               # Chaquopy config, Python 3.14, pip: yt-dlp
│       └── src/main/
│           ├── kotlin/.../
│           │   ├── MainActivity.kt        # Python init + MethodChannel registration
│           │   └── YtDlpBridge.kt         # Flutter↔Python bridge (thread-safe)
│           └── python/
│               └── ytdlp_bridge.py        # yt-dlp download function (called from Kotlin)
│
├── assets/
│   ├── binaries/                          # yt-dlp.exe (Windows only)
│   └── sounds/                            # UI feedback sounds
│
└── pubspec.yaml                           # Flutter dependencies
```

---

## 4. Download Pipeline — Step by Step

This is the core feature. Here's exactly what happens when a user pastes a playlist URL and taps download:

### Phase 1: Metadata Fetch
```
User pastes URL → MetadataService.fetchFromUrl(url)
    ↓
URL is inspected:
  • spotify.com   → SpotifyService (scrapes HTML, extracts __PRELOADED_STATE__)
  • music.youtube → YtMusicMetadataService (Innertube browsing API)
  • gaana.com     → GaanaService (scrapes HTML, extracts JSON-LD)
    ↓
Returns List<Track> with: title, artists, album, albumArt, durationMs
```

### Phase 2: YouTube Search (per track)
```
Track → YtMusicService.findYouTubeId(track)
    ↓
Constructs query: "{title} {artist} -remix -cover -live -karaoke"
    ↓
POST to music.youtube.com/youtubei/v1/search (WEB_REMIX client)
    ↓
Scoring algorithm (max 115 points):
  • Title similarity:   40 pts
  • Artist match:       30 pts
  • Duration match:     20 pts (±2s=20, ±5s=15, ±10s=8)
  • View count:         10 pts (log-scaled)
  • Video type bonus:   +15 (ATC) / -30 (UGC)
  • Blacklist penalty:  -60 per keyword (remix, cover, live, etc.)
    ↓
Returns: YouTube video ID (11 chars) or null if score ≤ 30
```

### Phase 3: Audio Download
```
                        ┌─── Android ───┐              ┌─── Windows ───┐
                        │               │              │               │
videoId ─→ DownloaderService._downloadAndroid()    DownloaderService._downloadWindows()
                        │               │              │               │
                 MethodChannel           │       Process.start(yt-dlp.exe)
                 'com.oddtunes/ytdlp'    │              │
                        │               │              │
                 YtDlpBridge.kt          │       stdout → progress regex
                 (background thread)     │              │
                        │               │              │
                 Python.getInstance()    │       --audio-format m4a
                 .getModule("ytdlp_bridge")      --audio-quality 0
                 .callAttr("download_audio")            │
                        │               │              │
                 yt-dlp (Python 3.14)    │       exit code → find .m4a
                 format: 140/bestaudio   │              │
                        │               │              │
                 Returns .m4a path       │       Returns .m4a path
                        └───────────────┘              └───────────────┘
```

### Phase 4: Tagging & Filing
```
Raw .m4a → FfmpegService.processAudio()
    ↓
FFmpeg stream-copy + metadata injection:
  -metadata title="..."
  -metadata artist="..."
  -metadata album="..."
  -metadata album_artist="..."
    ↓
Moved to final output directory (Oddtunes/ on device)
    ↓
LibraryService.refresh() → scans directory, updates UI
    ↓
Auto-creates playlist from the batch
```

---

## 5. Android Native Stack (Chaquopy)

### Why Chaquopy?

| Approach | Result |
|----------|--------|
| ~~Raw `libytdlp.so` binary~~ | ❌ Android blocks `exec()` on internal storage (`noexec` mount) |
| ~~`youtubedl-android` 0.14.0~~ | ❌ Bundles Python 3.8 + old yt-dlp; can't parse YouTube 2026 |
| ~~Update yt-dlp inside youtubedl-android~~ | ❌ New yt-dlp needs Python 3.10+, library has 3.8 → `ImportError` |
| ~~Direct Innertube API from Dart~~ | ❌ YouTube requires `po_token` for ANDROID/IOS clients |
| **✅ Chaquopy 17.0** | Python 3.14 + `pip install yt-dlp` → always current, always works |

### Build Configuration

```kotlin
// android/settings.gradle.kts
plugins {
    id("com.chaquo.python") version "17.0.0" apply false
}

// android/app/build.gradle.kts
plugins {
    id("com.chaquo.python")
}

chaquopy {
    defaultConfig {
        version = "3.14"
        pip { install("yt-dlp") }
        extractPackages("yt_dlp")
    }
}
```

### Thread Safety Contract
```
Flutter UI Thread ──MethodChannel──→ YtDlpBridge.onMethodCall()
                                        │
                                    Thread { ... }  ← background thread
                                        │
                                    Python.getInstance().getModule(...)
                                        │
                                    mainHandler.post { result.success() }
                                        │                    ↑
                                        └── MUST be on main looper
```

> [!CAUTION]
> **Never call `result.success()` or `result.error()` from a background thread.**
> Flutter's MethodChannel crashes if callbacks aren't on the main looper.

---

## 6. Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter` | SDK 3.11.5 | Framework |
| `flutter_riverpod` | 2.5.1 | State management (providers) |
| `provider` | 6.1.2 | Legacy ChangeNotifier support |
| `http` | 1.2.1 | HTTP client (metadata APIs) |
| `dio` | 5.4.3 | Extended HTTP (Spotify scraping) |
| `just_audio` | 0.9.40 | Audio playback engine |
| `audio_session` | 0.1.25 | Audio focus management |
| `ffmpeg_kit_flutter_new_audio` | 2.0.0 | Audio metadata tagging |
| `audio_metadata_reader` | 1.6.0 | ID3/M4A tag reading |
| `google_fonts` | 6.2.1 | Typography (retro monospace) |
| `phosphor_flutter` | 2.1.0 | Icon set |
| `permission_handler` | 11.3.1 | Storage permissions |
| `path_provider` | 2.1.3 | Platform-specific directories |
| `crypto` | 3.0.3 | Hash functions |
| `url_launcher` | 6.3.2 | External links |
| **Chaquopy** | **17.0.0** | **Embedded Python 3.14 runtime** |
| **yt-dlp** | **latest (pip)** | **YouTube audio extraction** |

---

## 7. Errors Encountered & Resolutions

### 7.1 `noexec` Mount Restriction
```
Error: Permission denied — cannot execute libytdlp.so
```
**Root Cause:** Android mounts internal storage with `noexec` flag. You cannot run ELF binaries from app data directories.
**Resolution:** Abandoned native binary approach entirely. Moved to library-based execution (first youtubedl-android, then Chaquopy).

### 7.2 `Requested format is not available`
```
ERROR: [youtube] IN-PeAZDi7g: Requested format is not available.
Use --list-formats for a list of available formats
```
**Root Cause:** youtubedl-android 0.14.0 bundles a yt-dlp from ~2023 that cannot parse YouTube's 2026 API responses. YouTube changes format negotiation frequently.
**Resolution:** Replaced with Chaquopy + latest yt-dlp via pip.

### 7.3 `ImportError: Python 3.10+ required`
```
ImportError: You are using an unsupported version of Python.
Only Python versions 3.10 and above are supported by yt-dlp
```
**Root Cause:** Called `YoutubeDL.getInstance().updateYoutubeDL(context)` which downloaded the latest yt-dlp (needs Python 3.10+), but youtubedl-android only bundles Python 3.8. The updated yt-dlp crashed on import.
**Resolution:** This confirmed youtubedl-android is a dead end. Migrated to Chaquopy which bundles Python 3.14.

### 7.4 `Unresolved reference: UpdateChannel`
```
Too many arguments for 'fun updateYoutubeDL(p0: Context!)'
```
**Root Cause:** The `UpdateChannel` enum doesn't exist in youtubedl-android 0.14.0's API (was added in a later unreleased version).
**Resolution:** Removed the argument. Later removed the entire library.

### 7.5 `Unresolved reference: yausername` (after removing dependency)
```
Unresolved reference 'yausername'
```
**Root Cause:** `YtDlpService.kt` still existed on disk importing `com.yausername.*` classes after the Gradle dependency was removed.
**Resolution:** Deleted the orphaned `YtDlpService.kt` file.

### 7.6 `Could not extract audio stream URL`
```
Exception: Could not extract audio stream URL for LwkrXybZ1uo
```
**Root Cause:** An intermediate Dart-only approach tried calling YouTube's Innertube player API directly, but YouTube now requires proof-of-origin tokens (`po_token`) for ANDROID/IOS client identities.
**Resolution:** Abandoned the direct API approach. Replaced with Chaquopy + yt-dlp which handles all of YouTube's anti-bot measures internally.

### 7.7 `libffmpeg.zip.so: not recognized as valid object file`
```
llvm-strip.exe: error: 'libffmpeg.zip.so': not recognized as valid object file
```
**Root Cause:** The youtubedl-android `:ffmpeg` module ships a ZIP disguised as an `.so` file. The NDK's `llvm-strip` couldn't process it. This is a warning, not a fatal error.
**Resolution:** Removed the youtubedl-android dependency entirely.

---

## 8. Known Vulnerabilities & Risks

### 🔴 Critical

| Risk | Details | Mitigation |
|------|---------|------------|
| **No release signing** | APK is signed with debug keys (`signingConfigs.getByName("debug")`) | Create a keystore and configure `release` signing before publishing |
| **Spotify scraping fragility** | `SpotifyService` scrapes HTML and parses `__PRELOADED_STATE__` JSON. Spotify can change this at any time. | Monitor for breakage; consider adding a fallback metadata source |

### 🟡 Medium

| Risk | Details | Mitigation |
|------|---------|------------|
| **yt-dlp version pinning** | `pip { install("yt-dlp") }` always installs latest. A breaking yt-dlp release could break builds. | Pin to a specific version: `install("yt-dlp==2026.3.17")` |
| **No SSL certificate pinning** | HTTP calls to YouTube/Spotify use default cert validation. MITM possible on compromised networks. | Consider cert pinning for sensitive API calls |
| **Parallel downloads unbounded** | `_maxParallel = 7` — on slow networks, 7 concurrent downloads may overwhelm the connection | Already configurable (5/7/8/10 setting exists) |
| **No crash reporting** | Unhandled exceptions are only logged to `debugPrint` | Integrate Sentry or Firebase Crashlytics |
| **YouTube API key hardcoded** | `AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30` in `ytmusic_service.dart` | This is a public YouTube key used by the web client; no real risk, but could be rotated |
| **Dual state management** | Uses both `flutter_riverpod` and `provider` | Consider migrating fully to one system |

### 🟢 Low

| Risk | Details | Mitigation |
|------|---------|------------|
| **No unit tests** | Zero test coverage | Add tests for scoring algorithm, metadata parsing |
| **`extractPackages("yt_dlp")`** | Extracts ~40MB of Python files to filesystem on first run | Acceptable for the use case; warn user about first-launch delay |
| **Single ABI (`arm64-v8a`)** | Won't run on older 32-bit ARM devices | Add `armeabi-v7a` if needed (but Python 3.14 only supports 64-bit) |

---

## 9. Data Flow Diagram

```mermaid
sequenceDiagram
    participant U as User
    participant UI as Flutter UI
    participant DP as DownloadProvider
    participant MS as MetadataService
    participant YT as YtMusicService
    participant DL as DownloaderService
    participant KB as YtDlpBridge.kt
    participant PY as ytdlp_bridge.py
    participant FF as FfmpegService
    participant LS as LibraryService

    U->>UI: Paste playlist URL
    UI->>DP: fetchTracks(url)
    DP->>MS: fetchFromUrl(url)
    MS-->>DP: List<Track>
    DP-->>UI: Show track list

    U->>UI: Tap "Download"
    UI->>DP: startDownloading()
    
    loop For each track (max 7 parallel)
        DP->>YT: findYouTubeId(track)
        YT-->>DP: videoId
        DP->>DL: downloadAudio(videoId, dir, name)
        DL->>KB: MethodChannel.invokeMethod("download")
        KB->>PY: download_audio(videoId, dir, name)
        PY-->>KB: JSON {status: "ok", path: "..."}
        KB-->>DL: result.success(path)
        DL-->>DP: filePath
        DP->>FF: processAudio(rawPath, track, outputDir)
        FF-->>DP: taggedFilePath
    end

    DP->>LS: savePlaylist() + refresh()
    LS-->>UI: Updated library
```

---

## 10. Build & Run Instructions

### Prerequisites
- Flutter SDK ≥ 3.11.5
- Android SDK with NDK 28.x
- Python 3.14 (on build machine, for Chaquopy `.pyc` compilation)
- Java 17

### Android
```bash
# First build (downloads Python + yt-dlp, takes ~5-10 minutes)
flutter clean
flutter run -d <device-id>

# Subsequent builds (fast, cached)
flutter run -d <device-id>
```

### Windows
```bash
# Requires yt-dlp.exe in assets/binaries/
flutter run -d windows
```

### Updating yt-dlp
```bash
# Just rebuild — pip always fetches the latest yt-dlp
flutter clean
flutter run -d <device-id>

# Or pin a specific version in android/app/build.gradle.kts:
# pip { install("yt-dlp==2026.3.17") }
```

---

## 11. Design Language

The UI follows a **retro-hardware aesthetic** inspired by vintage audio equipment:

- **Color palette:** Deep browns (`#1A0E0A`), warm reds (`#8B2252`), cream (`#F5E6D3`)
- **Typography:** Monospace fonts (VT323, Space Mono) for LCD displays
- **Components:** Embossed panels, physical-style buttons with press animations, LED indicators
- **Feedback:** Haptic vibration on button press, sound effects for actions

---

## 12. Future Roadmap

| Priority | Feature | Status |
|----------|---------|--------|
| P0 | ✅ Android download via Chaquopy + yt-dlp | **Done** |
| P0 | ✅ Spotify playlist import | **Done** |
| P0 | ✅ YouTube Music playlist import | **Done** |
| P0 | ✅ Audio playback with just_audio | **Done** |
| P0 | ✅ Library management + playlist persistence | **Done** |
| P1 | Release signing + Play Store preparation | Pending |
| P1 | Pin yt-dlp version for build reproducibility | Pending |
| P1 | Error retry UI improvements | Pending |
| P2 | iOS support | Not started |
| P2 | Lyrics display | Not started |
| P2 | Equalizer | Not started |
| P3 | Background download notifications | Not started |
| P3 | Cloud sync (playlists) | Not started |

---

## 13. Session Log — Debugging Timeline

| Time | Issue | Action | Result |
|------|-------|--------|--------|
| T+0 | App won't run on Android | Analyzed codebase | Found `libytdlp.so` binary execution blocked by `noexec` |
| T+1 | `noexec` blocks native binary | Integrated `youtubedl-android` 0.14.0 via JitPack | Build succeeded |
| T+2 | `Requested format not available` | Added FFmpeg module dependency | Still failed — bundled yt-dlp too old |
| T+3 | Format still unavailable | Changed format to `140/bestaudio` fallback chain | Still failed — yt-dlp can't parse YouTube 2026 |
| T+4 | Tried updating yt-dlp | Called `updateYoutubeDL()` | `ImportError: Python 3.10+ required` |
| T+5 | Python 3.8 vs 3.10 deadlock | Realized youtubedl-android is a dead end | Explored alternatives |
| T+6 | Tried direct Innertube API | Implemented Dart HTTP stream download | `Could not extract audio stream URL` — YouTube blocks non-authenticated clients |
| T+7 | User suggested yt-dlp is best | Agreed — integrated **Chaquopy 17.0** + Python 3.14 + pip yt-dlp | **✅ Downloads working** |

---

> [!IMPORTANT]
> **This document should be updated when significant architectural changes are made.**
> Keep the vulnerability table current and review yt-dlp compatibility periodically.
