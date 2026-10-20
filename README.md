# GraveDash

Horror endless runner (Subway Surfers–style) built with **Godot 4.3 / 4.4**, GDScript, 3D, Mobile renderer — targeted at Android landscape @ 60 FPS.

MVP includes menus, gameplay systems, Haunted Castle biome transition, and **Android export project setup** (presets + touch input).

## Requirements

- [Godot 4.3 or 4.4](https://godotengine.org/download) (Standard build is fine)
- For device builds: **Android Export Templates** matching your Godot version + Android SDK / JDK (install via Editor → Editor Settings → Export → Android, or Godot’s docs)

## Open & run

1. Launch Godot 4.3/4.4 → **Import** → select this folder’s `project.godot`
2. Press **F5** — boots into **Main Menu** (`scenes/ui/MainMenu.tscn`)
3. **Start Game** loads `scenes/levels/Main.tscn` via GameManager

### Desktop controls (for testing)

| Action | Keys |
|--------|------|
| Lane left / right | `A` / `D` or `←` / `→` |
| Jump | `Space` or `↑` |
| Slide | `Ctrl` or `S` or `↓` |
| Pause | `Esc` |

### Touch (Android / emulated)

`TouchSwipeDetector` autoload maps screen swipes → `swipe_left` / `swipe_right` / `swipe_up` / `swipe_down`.  
On desktop, **Project Settings → emulate touch from mouse** is enabled so you can click-drag to test swipes.

## Scene flow

```
MainMenu  --Start-->  Main (gameplay)
   ^                      |
   |                   Game Over / Pause → Main Menu
   +-------- Retry reloads Main --------+
```

## Android export

### Preset (in repo)

| Item | Value |
|------|--------|
| File | `export_presets.cfg` — preset **"Android"** |
| Package | `com.gravedash.app` |
| App name | GraveDash |
| Orientation | Landscape (`window/handheld/orientation` = sensor landscape) |
| Architectures | **arm64-v8a only** (preferred; enable armeabi-v7a in the preset only if you must ship a fat APK for very old devices) |
| Min SDK | **24** |
| Target SDK | **34** |
| Permission | **Internet** (future ads / leaderboard) |
| Output path | `build/android/GraveDash.apk` (created on export) |

Renderer is already **Mobile** with **ETC2/ASTC** import compression (`textures/vram_compression/import_etc2_astc=true`) for Android GPU textures.

### Export APK / AAB from the Godot Editor

1. Install **Export Templates** for your exact Godot version (Editor → Manage Export Templates).
2. Configure Android SDK paths (Editor Settings → Export → Android): SDK, JDK, `adb`, etc.
3. **Project → Export…** → select **Android**.
4. Debug builds can use Godot’s debug keystore. For store release, create a release keystore and fill **Keystore** fields in the preset (never commit `*.keystore` / passwords).
5. Export **APK** (preset default) or enable Gradle build + AAB when you need Play Store App Bundles.
6. Install via `adb install build/android/GraveDash.apk`.

### Known gaps (this environment)

- No Android SDK / Godot binary in the cloud agent VM — **no APK was built here**.
- No CI signing pipeline in this temporary repo — sign locally.
- Ads / leaderboards are not wired yet; Internet permission is declared ahead of that work.

### Performance checklist

- **Object pooling** — chunks, obstacles, collectibles, power-ups, and chaser ghosts go through `ObjectPool` (acquire/release); pools clear on restart.
- Mobile renderer + ETC2/ASTC — avoid shipping uncompressed desktop textures to device.
- Keep draw calls modest (simple meshes / shared materials); MSAA 3D is set to 1× for mobile cost.

## Shared UI theme

`resources/ui/GraveDashTheme.tres` — dark gothic StyleBoxes for panels/buttons across Menu, Settings, HUD, Pause, Game Over.

## Score, missions & multiplier

**Formula:** `final score = (distance points + soul points) × multiplier`  
Distance converts 1:1 into raw points; soul collectibles add to raw via `ScoreManager.add_score` and also bank into the soul wallet.

| Piece | Behavior |
|-------|----------|
| Multiplier | Starts at **×1**; **+1** every **3** completed missions; cap **×30**; persists across launches |
| Missions | Exactly **3** active slots; completing one refills from the pool |
| Pool types | `distance`, `souls`, `dodge`, `powerups` |

### SaveSystem keys (`user://gravedash_save.cfg`)

| Key | Meaning |
|-----|---------|
| `music_muted` | Music bus / flag |
| `sfx_muted` | SFX bus / flag |
| `highscore` | Best **multiplied** run score |
| `total_souls` | Persistent soul wallet |
| `score_multiplier` | Long-term score multiplier (1–30) |
| `missions_completed` | Lifetime mission completions (drives multiplier) |
| `active_missions` | JSON array of the 3 active mission slots |

Autoload: `MissionManager` (`autoload/MissionManager.gd`) — separate from `ScoreManager`.

### UI surfaces

- **HUD** — score, multiplier, distance, best, 3 missions, power-ups
- **Main Menu** — high score, multiplier, 3 active missions + progress
- **Pause / Game Over** — multiplier + mission progress

Headless check: `godot --headless --path . --script res://tools/validate_missions.gd`

## Audio

Buses: **Master → Music / SFX** (`default_bus_layout.tres`).

| Save key | Meaning |
|----------|---------|
| `music_muted` / `sfx_muted` | Mute flags (Settings toggles) |
| `music_volume` / `sfx_volume` | Linear 0–1 bus levels (Settings sliders) |

Placeholder WAV loops/SFX live under:

```
assets/audio/music/   menu_loop.wav, gameplay_loop.wav
assets/audio/sfx/     footstep, jump, slide, soul_pickup, powerup_*, almost_caught, death, ui_click, chaser_approach
```

Replace those files with final assets (keep filenames) — no code change needed. Headless: `godot --headless --path . --script res://tools/validate_audio.gd`

## What’s in this slice

- Main Menu: Start, soul wallet, shop stub, high score, multiplier, missions, Settings, Quit
- Game Over: distance, run score, multiplier, missions, high score, Retry, Main Menu, disabled “Watch Ad” stub
- Pause overlay (Esc): Resume / Main Menu + multiplier & missions
- HUD: score, multiplier, distance, best, missions, power-up icons/timers
- Full gameplay: lanes, obstacles, collectibles, power-ups, chasers
- **Biomes:** Graveyard → **Haunted Castle** after ~1200–1500 m
- **Android:** export preset, landscape, Internet permission, arm64, touch swipes

## License

Project files are yours to iterate on; add a license when you publish.
