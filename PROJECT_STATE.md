# PROJECT_STATE.md — Oddtunes

> Generated: 2026-05-03 | Flutter 3.x + Dart 3.11.5 | Zero compile warnings

---

# 1. PROJECT OVERVIEW

**Oddtunes** is a music downloader app. The user pastes a Spotify URL (track, album, or playlist), the app scrapes the metadata directly from the Spotify web page (no API keys), finds matching audio on YouTube Music, downloads it, converts it to MP3 with embedded metadata, and saves it locally.

**Target platforms:** Android (primary), Windows (secondary).

**Core pipeline (planned, in order):**

1. User pastes a Spotify URL into the app.
2. `SpotifyService` scrapes `open.spotify.com` with a mobile User-Agent, extracts the Base64-encoded `<script id="initialState">` blob, decodes it, and parses the JSON to build `Track` objects.
3. `YtMusicService` searches YouTube Music for the best matching audio by title + artist + duration. *(not yet implemented)*
4. `DownloaderService` downloads the audio stream via yt-dlp / Dio with progress reporting. *(not yet implemented)*
5. `FfmpegService` converts M4A → MP3, normalises loudness, and embeds ID3 tags + cover art. *(not yet implemented)*
6. `DownloadProvider` orchestrates steps 2–5 with a parallel queue (max 3), manages state, and feeds the UI. *(not yet implemented)*
7. `HomeScreen` displays URL input, download queue, and library. *(stub only)*

---

# 2. TECH STACK

## pubspec.yaml dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter` | SDK | UI framework |
| `cupertino_icons` | ^1.0.8 | iOS-style icons (unused so far) |
| `http` | ^1.2.1 | HTTP client used by SpotifyService for scraping |
| `dio` | ^5.4.3 | Planned for download pipeline with progress/cancel support |
| `provider` | ^6.1.2 | State management (declared but unused — Riverpod planned instead) |
| `flutter_riverpod` | ^2.5.1 | Planned state management for download queue |
| `path_provider` | ^2.1.3 | Planned for resolving platform-specific download directories |
| `permission_handler` | ^11.3.1 | Planned for requesting storage permissions on Android |
| `crypto` | ^3.0.3 | MD5 hashing in `AppUtils.md5Hex()` for cache keys |

## dev_dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Widget testing framework |
| `flutter_lints` | ^6.0.0 | Lint rules |

## Bundled binaries

**None yet.** The plan calls for:
- `yt-dlp` — ARM64 binary for Android, `.exe` for Windows
- `ffmpeg` — via `ffmpeg_kit_flutter_audio` on Android, `ffmpeg.exe` on Windows

These have not been added to the project.

---

# 3. FOLDER STRUCTURE

```
oddtunes_app/
├── android/
│   └── app/
│       ├── build.gradle.kts          — Android build config (minSdk 21, namespace com.oddtunes.oddtunes_app)
│       └── src/main/
│           └── AndroidManifest.xml   — Permissions: INTERNET, READ/WRITE/MANAGE_EXTERNAL_STORAGE
├── lib/
│   ├── main.dart                     — App entry point, Material 3 dark theme, routes to HomeScreen
│   ├── core/
│   │   ├── constants.dart            — App-wide constants (URLs, timeouts, file names, audio extensions)
│   │   └── utils.dart                — Helpers: sanitizeFilename, formatDuration, md5Hex, tryParseJson, clamp
│   ├── models/
│   │   ├── track.dart                — Track data model with JSON serialisation (Spotify API + scraper compatible)
│   │   └── download_state.dart       — DownloadStatus enum + DownloadState model with copyWith
│   ├── services/
│   │   ├── spotify_service.dart      — ✅ FULLY IMPLEMENTED — Scrapes track/album/playlist from open.spotify.com
│   │   ├── ytmusic_service.dart      — ❌ STUB — Empty class, no methods
│   │   ├── downloader_service.dart   — ❌ STUB — Empty class, no methods
│   │   └── ffmpeg_service.dart       — ❌ STUB — Empty class, no methods
│   ├── providers/
│   │   └── download_provider.dart    — ❌ STUB — Empty class, no methods
│   └── screens/
│       └── home_screen.dart          — ❌ STUB — Shows "Oddtunes – Coming Soon" text
├── test/
│   └── widget_test.dart              — Smoke test: verifies "Coming Soon" text renders
├── tool/
│   ├── test_spotify.dart             — CLI tool to test SpotifyService against live URLs
│   ├── debug_spotify_html.dart       — CLI tool to dump raw HTML from Spotify for debugging
│   └── spotify_debug.html            — Last saved HTML dump (gitignore candidate)
├── pubspec.yaml                      — Project metadata and dependencies
├── pubspec.lock                      — Locked dependency versions
├── analysis_options.yaml             — Lint config using flutter_lints
└── README.md                         — Default Flutter README
```

---

# 4. EVERY FILE — DETAILED BREAKDOWN

---

## `lib/main.dart` (27 lines)

**Purpose:** App entry point.

**Functions:**
| Name | Return | Description |
|------|--------|-------------|
| `main()` | `void` | Calls `runApp(OddtunesApp())` |

**Classes:**
| Class | Extends | Description |
|-------|---------|-------------|
| `OddtunesApp` | `StatelessWidget` | Root widget. Creates a `MaterialApp` with dark theme, seed color `#1DB954`, Material 3, and `HomeScreen` as home. |

**Constants:** None. **TODOs:** None.

---

## `lib/core/constants.dart` (37 lines)

**Purpose:** App-wide constants.

**Class: `AppConstants`** (private constructor — non-instantiable)

| Constant | Type | Value | Notes |
|----------|------|-------|-------|
| `appName` | `String` | `'Oddtunes'` | |
| `appVersion` | `String` | `'1.0.0'` | |
| `spotifyApiBaseUrl` | `String` | `'https://api.spotify.com/v1'` | **Unused** — scraper doesn't use the API |
| `spotifyTokenUrl` | `String` | `'https://accounts.spotify.com/api/token'` | **Unused** — scraper doesn't use the API |
| `ytDlpDefaultFormat` | `String` | `'bestaudio[ext=m4a]/bestaudio/best'` | Planned yt-dlp format string |
| `downloadsDirName` | `String` | `'Oddtunes'` | Planned download folder name |
| `metadataDirName` | `String` | `'metadata'` | Planned metadata folder |
| `trackDbFileName` | `String` | `'tracks.json'` | Planned track database file |
| `defaultTimeout` | `Duration` | 30 seconds | |
| `maxRetries` | `int` | `3` | |
| `supportedAudioExtensions` | `List<String>` | `.mp3, .m4a, .flac, .ogg, .opus` | |

**TODOs:** None explicit, but `spotifyApiBaseUrl` and `spotifyTokenUrl` are dead constants.

---

## `lib/core/utils.dart` (55 lines)

**Purpose:** Utility helpers.

**Class: `AppUtils`** (private constructor — non-instantiable)

| Method | Parameters | Return | Description |
|--------|-----------|--------|-------------|
| `sanitizeFilename` | `String input` | `String` | Replaces filesystem-unsafe chars (`<>:"/\|?*`) with underscores, collapses whitespace |
| `formatDuration` | `int ms` | `String` | Converts milliseconds → `"M:SS"` string (e.g. `213573` → `"3:33"`) |
| `md5Hex` | `String input` | `String` | Returns MD5 hex digest of input using `crypto` package |
| `tryParseJson` | `String raw` | `Map<String, dynamic>?` | Safe JSON parse, returns `null` on error |
| `clamp<T extends num>` | `T value, T min, T max` | `T` | Clamps a numeric value to [min, max] |

**TODOs:** None.

---

## `lib/models/track.dart` (114 lines)

**Purpose:** Core data model for a music track.

**Class: `Track`**

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Spotify track ID |
| `title` | `String` | Track name |
| `artists` | `List<String>` | Artist names |
| `album` | `String` | Album name |
| `coverArtUrl` | `String` | URL of album cover artwork (640px preferred) |
| `durationMs` | `int` | Duration in milliseconds |
| `trackNumber` | `int` | Position in album (1-based) |
| `discNumber` | `int` | Disc number (1-based) |

| Method/Getter | Return | Description |
|--------------|--------|-------------|
| `artistString` | `String` | All artists joined with `", "` |
| `Track.fromJson(Map)` | `Track` | Factory constructor. Handles both Spotify API format (`duration_ms`, `track_number`, `album.images`) and flat format (`durationMs`, `trackNumber`, `coverArtUrl`) |
| `toJson()` | `Map<String, dynamic>` | Serialises to JSON with both API-style and flat fields for storage flexibility |
| `operator ==` | `bool` | Equality by `id` |
| `hashCode` | `int` | Based on `id` |
| `toString()` | `String` | Debug representation |

**TODOs:** None.

---

## `lib/models/download_state.dart` (96 lines)

**Purpose:** Tracks the lifecycle of a single download.

**Enum: `DownloadStatus`**

| Value | Meaning |
|-------|---------|
| `idle` | Not yet queued |
| `queued` | Waiting to start |
| `downloading` | Actively downloading audio |
| `processing` | FFmpeg post-processing |
| `completed` | Done successfully |
| `failed` | Error occurred |
| `cancelled` | User cancelled |

**Class: `DownloadState`**

| Field | Type | Description |
|-------|------|-------------|
| `track` | `Track` | The track this state belongs to |
| `status` | `DownloadStatus` | Current lifecycle stage |
| `progress` | `double` | Download progress 0.0–1.0 |
| `errorMessage` | `String?` | Error message when failed |
| `localPath` | `String?` | Path to downloaded file when completed |

| Method/Getter | Return | Description |
|--------------|--------|-------------|
| `isIdle` | `bool` | `status == idle` |
| `isQueued` | `bool` | `status == queued` |
| `isDownloading` | `bool` | `status == downloading` |
| `isProcessing` | `bool` | `status == processing` |
| `isCompleted` | `bool` | `status == completed` |
| `isFailed` | `bool` | `status == failed` |
| `isCancelled` | `bool` | `status == cancelled` |
| `isActive` | `bool` | True if queued, downloading, or processing |
| `copyWith(...)` | `DownloadState` | Immutable update — returns new instance with overridden fields |
| `toString()` | `String` | Debug representation with percentage |

**TODOs:** None.

---

## `lib/services/spotify_service.dart` (421 lines) — ✅ FULLY IMPLEMENTED

**Purpose:** Scrapes track metadata from `open.spotify.com` without API keys.

**Class: `SpotifyService`**

### Constants

| Constant | Type | Value |
|----------|------|-------|
| `_headers` | `Map<String, String>` | Mobile Chrome UA on Android 14, Accept HTML, Accept-Language en-US |
| `_requestDelay` | `Duration` | 500ms politeness delay before each request |

### Public methods

| Method | Parameters | Return | Description |
|--------|-----------|--------|-------------|
| `detectUrlType` | `String url` | `String` | Parses URL path to return `"track"`, `"album"`, or `"playlist"`. Throws on unknown type. |
| `fetchFromUrl` | `String url` | `Future<List<Track>>` | Master entry point. Detects type, delegates to `fetchTrack`/`fetchAlbum`/`fetchPlaylist`. |
| `fetchTrack` | `String spotifyTrackUrl` | `Future<Track>` | Fetches HTML, extracts initialState, parses first track. |
| `fetchAlbum` | `String spotifyAlbumUrl` | `Future<List<Track>>` | Returns all tracks from an album page. |
| `fetchPlaylist` | `String spotifyPlaylistUrl` | `Future<List<Track>>` | Returns up to 30 tracks from a playlist page. |

### Private methods

| Method | Parameters | Return | Description |
|--------|-----------|--------|-------------|
| `_fetchHtml` | `String url` | `Future<String>` | GETs URL with mobile UA headers. Auto-strips query params (`?si=...`) to avoid Branch.io redirects. |
| `_extractInitialState` | `String html` | `Map<String, dynamic>` | Finds `<script id="initialState" type="text/plain">`, Base64-decodes content, JSON-parses to Map. |
| `_parseTracksFromEntities` | `Map<String, dynamic> data` | `List<Track>` | Routes to correct parser based on `__typename`: `Track` → direct parse + album siblings, `Album` → `tracksV2.items`, `Playlist` → `content.items[].itemV2.data`. Deduplicates by ID. Sorts by disc/track number. Falls back to legacy `entities.tracks` shape. |
| `_enrichSiblingTrack` | `Map trackNode, Map? albumObj` | `Map<String, dynamic>` | Injects album name + coverArt into a sibling track node so `_trackFromModernEntry` can build a complete Track. |
| `_trackFromModernEntry` | `Map<String, dynamic> d` | `Track?` | Builds Track from modern initialState shape. Extracts `id` (or `uri` fallback), `name`, `duration.totalMilliseconds`, `trackNumber`, `discNumber`. Reads artists from `firstArtist`+`otherArtists` (Shape A) or `artists.items[].profile.name` (Shape B). Gets album/coverArt from `albumOfTrack`. Picks largest cover image. Returns null on error. |
| `_trackFromLegacyEntry` | `Map<String, dynamic> d` | `Track?` | Delegates to `Track.fromJson()` for legacy Spotify API-shaped entries. |

### JSON shapes handled (verified against live data)

| Page type | Entity `__typename` | Track location | Artist location |
|-----------|---------------------|---------------|-----------------|
| `/track/` | `Track` | Direct entity | `firstArtist.items[].profile.name` + `otherArtists` |
| `/album/` | `Album` | `tracksV2.items[].track` | `artists.items[].profile.name` |
| `/playlist/` | `Playlist` | `content.items[].itemV2.data` | `artists.items[].profile.name` |

**TODOs:** None.

---

## `lib/services/ytmusic_service.dart` (16 lines) — ❌ STUB

**Purpose:** Planned YouTube Music search integration.

**Class: `YtMusicService`** — Empty. Constructor only.

**TODO (from comments):**
- Search YouTube Music by title + artist string
- Return ranked list of candidate video IDs / URLs
- Extract best-matching audio stream URL

---

## `lib/services/downloader_service.dart` (18 lines) — ❌ STUB

**Purpose:** Planned audio download pipeline.

**Class: `DownloaderService`** — Empty. Constructor only.

**TODO (from comments):**
- Receive Track + audio URL
- Download via Dio with progress callback
- Move finished file to permanent downloads directory
- Persist metadata JSON alongside audio file
- Support pause, resume, cancellation via CancelToken

---

## `lib/services/ffmpeg_service.dart` (18 lines) — ❌ STUB

**Purpose:** Planned FFmpeg audio processing.

**Class: `FfmpegService`** — Empty. Constructor only.

**TODO (from comments):**
- Convert audio to target format (MP3, M4A)
- Embed ID3/MP4 metadata tags (title, artist, album, artwork)
- Normalise audio loudness (ReplayGain / EBU R 128)
- Trim silence from start/end (optional)
- Progress reporting via stream/callback

---

## `lib/providers/download_provider.dart` (18 lines) — ❌ STUB

**Purpose:** Planned state management for download queue.

**Class: `DownloadProvider`** — Empty. Constructor only.

**TODO (from comments):**
- Expose list of `DownloadState` objects
- Methods: `enqueue(Track)`, `cancel(String trackId)`, `clearCompleted()`
- Coordinate: SpotifyService → YtMusicService → DownloaderService → FfmpegService
- Persist queue state across app restarts
- Emit progress updates for UI

---

## `lib/screens/home_screen.dart` (32 lines) — ❌ STUB

**Purpose:** Main app UI screen.

**Class: `HomeScreen`** extends `StatelessWidget` — Shows `Scaffold` with `AppBar` title "Oddtunes" and centered text "Oddtunes – Coming Soon".

**TODO (from comments):**
- URL / search input field for Spotify links
- Active download queue list with progress indicators
- Navigation to local music library
- Settings access (credentials, output format, download path)

---

## `tool/test_spotify.dart` (109 lines)

**Purpose:** CLI test tool for verifying SpotifyService against live Spotify URLs.

**Usage:** `dart run tool/test_spotify.dart <spotify_url>`

**Functions:**
| Name | Parameters | Return | Description |
|------|-----------|--------|-------------|
| `main` | `List<String> args` | `Future<void>` | Parses URL arg, calls `SpotifyService.fetchFromUrl()`, prints results in formatted table |
| `_header` | `String text` | `void` | Prints boxed section header |
| `_divider` | — | `void` | Prints horizontal rule |
| `_kv` | `String key, String value` | `void` | Prints key-value pair, right-padded |
| `_fmtMs` | `int ms` | `String` | Converts milliseconds to `M:SS` |

---

## `tool/debug_spotify_html.dart` (80 lines)

**Purpose:** Debug inspector — fetches a Spotify page and dumps raw HTML for manual analysis.

**Functions:**
| Name | Parameters | Return | Description |
|------|-----------|--------|-------------|
| `main` | `List<String> args` | `Future<void>` | Fetches URL, enumerates all `<script>` tags, shows any containing "state", checks for `__NEXT_DATA__`, saves full HTML to `tool/spotify_debug.html` |

---

## `test/widget_test.dart` (11 lines)

**Purpose:** Single smoke test — verifies "Oddtunes – Coming Soon" text renders.

---

## `android/app/build.gradle.kts` (45 lines)

**Key settings:** `namespace = "com.oddtunes.oddtunes_app"`, `minSdk = 21`, `targetSdk = flutter.targetSdkVersion`, Java 17, release build uses debug signing.

**TODOs (from comments):**
- Specify unique Application ID
- Add release signing config

---

## `android/app/src/main/AndroidManifest.xml` (52 lines)

**Permissions declared:**
- `INTERNET`
- `WRITE_EXTERNAL_STORAGE`
- `READ_EXTERNAL_STORAGE`
- `MANAGE_EXTERNAL_STORAGE`

---

# 5. DATA FLOW

### Current flow (working):

```
User pastes Spotify URL
        │
        ▼
SpotifyService.fetchFromUrl(url)
        │
        ├─► detectUrlType(url) → "track" | "album" | "playlist"
        │
        ├─► _fetchHtml(url)
        │     └─ Strips ?si= params
        │     └─ HTTP GET with mobile Chrome UA
        │     └─ Returns raw HTML string
        │
        ├─► _extractInitialState(html)
        │     └─ Regex finds <script id="initialState" type="text/plain">
        │     └─ Extracts Base64 content between tags
        │     └─ base64Decode → utf8.decode → jsonDecode
        │     └─ Returns Map<String, dynamic>
        │
        └─► _parseTracksFromEntities(data)
              └─ Iterates entities.items, switches on __typename
              └─ Track: reads firstArtist/otherArtists + albumOfTrack
              └─ Album: reads tracksV2.items[].track, injects album coverArt
              └─ Playlist: reads content.items[].itemV2.data
              └─ Deduplicates by ID, sorts by disc/track number
              └─ Returns List<Track>
```

### Planned flow (not yet built):

```
List<Track> from SpotifyService
        │
        ▼
DownloadProvider.enqueue(track)
        │
        ├─► YtMusicService.search(title, artist, durationMs)
        │     └─ Returns best-matching YouTube video URL
        │
        ├─► DownloaderService.download(videoUrl, tempPath, onProgress)
        │     └─ Uses yt-dlp or Dio to fetch audio stream
        │     └─ Reports progress via callback
        │
        └─► FfmpegService.process(inputPath, outputPath, track)
              └─ Converts to MP3
              └─ Embeds ID3 tags + cover art
              └─ Normalises loudness
              └─ Returns final file path
```

---

# 6. WHAT IS COMPLETE

| Feature | Status | Verified |
|---------|--------|----------|
| Flutter project scaffold (Android + Windows) | ✅ | Builds without errors |
| `Track` data model with full JSON serialisation | ✅ | Used by SpotifyService |
| `DownloadState` model with enum + copyWith | ✅ | Ready for provider |
| `AppConstants` with all planned constants | ✅ | — |
| `AppUtils` with 5 utility methods | ✅ | — |
| `SpotifyService` — track page scraping | ✅ | Tested: "Never Gonna Give You Up" |
| `SpotifyService` — album page scraping | ✅ | Tested: "Global Warming" (18 tracks) |
| `SpotifyService` — playlist page scraping | ✅ | Tested: "Today's Top Hits" (30 tracks) |
| `SpotifyService` — ?si= share link handling | ✅ | Auto-strips query params |
| `SpotifyService` — dual artist parser (firstArtist + artists.items) | ✅ | Both shapes verified |
| `SpotifyService` — legacy JSON fallback | ✅ | Code present, untriggered |
| CLI test tool (`tool/test_spotify.dart`) | ✅ | Used for all verification |
| HTML debug tool (`tool/debug_spotify_html.dart`) | ✅ | Used for structure analysis |
| Widget smoke test | ✅ | Passes |
| Android permissions (Internet + Storage) | ✅ | In manifest |
| `flutter analyze` — zero warnings | ✅ | Clean |

---

# 7. WHAT IS INCOMPLETE OR MISSING

## Stub files (empty classes, no methods)

| File | Class | What it needs |
|------|-------|---------------|
| `ytmusic_service.dart` | `YtMusicService` | YouTube Music search via HTTP POST to `youtubei/v1/search`, result scoring by title/artist/duration similarity |
| `downloader_service.dart` | `DownloaderService` | Audio download via yt-dlp binary or Dio, progress callbacks, pause/resume/cancel |
| `ffmpeg_service.dart` | `FfmpegService` | M4A→MP3 conversion, ID3 tagging, cover art embedding, loudness normalisation |
| `download_provider.dart` | `DownloadProvider` | Riverpod state management, download queue (max 3 parallel), orchestration of all services |
| `home_screen.dart` | `HomeScreen` | URL input field, download queue UI, progress bars, library navigation, settings |

## Missing files (planned but not created)

| File | Purpose |
|------|---------|
| Library/player screen | Browse and play downloaded tracks |
| Settings screen | Configure output format, download path, quality |
| Riverpod providers file | `ProviderScope` wrapping, provider definitions |

## Missing infrastructure

| Item | Details |
|------|---------|
| yt-dlp binary | Not bundled — needed for Android (ARM64) and Windows (x86_64) |
| ffmpeg binary | Not bundled — `ffmpeg_kit_flutter_audio` not in pubspec yet |
| `cached_network_image` | Not in pubspec — planned for cover art display |
| `ProviderScope` | `main.dart` doesn't wrap with Riverpod's `ProviderScope` |
| App icon | Using default Flutter icon |
| Release signing | Using debug keys |

## Dead constants

| Constant | Issue |
|----------|-------|
| `AppConstants.spotifyApiBaseUrl` | Never used — scraper bypasses the API |
| `AppConstants.spotifyTokenUrl` | Never used — no OAuth flow exists |

---

# 8. KNOWN ISSUES OR WARNINGS

| Issue | Severity | Details |
|-------|----------|---------|
| `flutter analyze` | ✅ Clean | Zero warnings or errors as of last run |
| Spotify may change HTML structure | ⚠️ Medium | The `initialState` JSON shape has already changed once during development. Use `debug_spotify_html.dart` to inspect if parsing breaks. |
| Playlist limit: 30 tracks | ⚠️ Low | Spotify's mobile page only embeds ~30 tracks in the initial state. Longer playlists are truncated. |
| Private playlists | ⚠️ Low | Private or unlisted playlists may not return the full `initialState` payload. |
| `?si=` param stripping | ✅ Fixed | Query params are now auto-stripped. However, if Spotify changes their redirect behaviour this may need updating. |
| `provider` + `flutter_riverpod` both declared | ⚠️ Low | Both are in pubspec but neither is used yet. Pick one and remove the other. |
| `dart` not in PATH on user's machine | ℹ️ Info | Must use full path `C:\flutterr\flutter\bin\dart.bat` to run CLI tools. |
| Android release signing | ⚠️ Low | Currently using debug keys for release builds. |
| `MANAGE_EXTERNAL_STORAGE` | ⚠️ Medium | This permission triggers extra Play Store review. May not be needed if scoped storage is used. |

---

# 9. WHAT TO BUILD NEXT

In dependency order:

| Step | What | Why |
|------|------|-----|
| **1** | `YtMusicService` | Without this, we have metadata but no audio source. Implement HTTP POST to `music.youtube.com/youtubei/v1/search` with InnerTube client context. Score results by Levenshtein distance on title + artist and duration delta. |
| **2** | `DownloaderService` | With a YouTube URL from step 1, download the audio. Either shell out to a bundled yt-dlp binary, or use the `piped.video` API as a proxy. Use Dio for progress reporting and CancelToken support. |
| **3** | `FfmpegService` | Convert downloaded M4A/WEBM to MP3 @ 192kbps. Embed ID3 tags (title, artist, album, track number) and cover art. Normalise loudness to -14 LUFS. Use `ffmpeg_kit_flutter_audio` on Android, `ffmpeg.exe` on Windows. |
| **4** | `DownloadProvider` (Riverpod) | Wire everything together. Expose `List<DownloadState>`, implement `enqueue()`, `cancel()`, `clearCompleted()`. Max 3 concurrent downloads. Persist queue to disk. Wrap app in `ProviderScope`. |
| **5** | `HomeScreen` UI | URL input field with paste-from-clipboard button. Track list from SpotifyService. Download queue with per-track progress bars. Pull-to-refresh. Error states. |
| **6** | Library screen | Browse downloaded tracks by album/artist. Playback with `just_audio` or `audioplayers`. Cover art display with `cached_network_image`. |
| **7** | Polish | App icon, splash screen, settings page, proper release signing, remove dead constants, remove unused `provider` dependency. |
