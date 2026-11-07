# GraveDash

Horror endless runner (Subway Surfers–style) built with **Godot 4.4+** (tested on **4.7.2**), GDScript, 3D, Mobile renderer — targeted at Android landscape @ 60 FPS.

MVP includes menus, gameplay systems, Haunted Castle biome transition, and **Android export project setup** (presets + touch input).

## Requirements

- [Godot 4.4 or newer](https://godotengine.org/download) — tested on 4.7.2 (Standard build is fine)
- For device builds: **Android Export Templates** matching your Godot version + Android SDK / JDK (install via Editor → Editor Settings → Export → Android, or Godot’s docs)

## Open & run

1. Launch Godot 4.4+ → **Import** → select this folder’s `project.godot`
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
| Version | code **1** / name **1.0.0** — bump `version/code` for every Play upload |
| Orientation | Landscape (`window/handheld/orientation` = sensor landscape) |
| Architectures | **arm64-v8a only** (enable armeabi-v7a only if you must support very old 32-bit devices) |
| Min / Target SDK | Template defaults (Godot 4.7.2: **24 / 36**). Overrides are only allowed with Gradle build on. |
| Permissions | **None** — nothing in the game uses the network yet. Re-enable `permissions/internet` when ads / leaderboards land. |
| Icons | `assets/icons/icon_192.png` + adaptive `icon_adaptive_fg_432.png` / `icon_adaptive_bg_432.png` (regenerate from `icon.svg` with `tools/gen_textures.gd`) |
| Excluded | `tools/*`, `build/*` (dev validators never ship) |
| Output | `build/android/GraveDash.apk` (gitignored) |

Rendering is **Mobile** with ETC2/ASTC textures, 2× MSAA, `rendering_device/fallback_to_opengl3=true` (devices without Vulkan boot the Compatibility renderer instead of failing), and a 2048 mobile shadow atlas.

### One-time setup

1. **Editor → Manage Export Templates** → install templates for your exact Godot version.
2. Install **JDK 17** and the **Android SDK** (platform-tools, build-tools 35+, a platform ≥ 35). Android Studio's SDK manager is easiest.
3. **Editor Settings → Export → Android**: set *Java SDK Path* and *Android SDK Path*.

### Debug build (sideload / testing)

Godot signs debug builds with its debug keystore (auto-created, or set *Editor Settings → Export → Android → Debug Keystore*).

```bash
godot --headless --path . --export-debug "Android" build/android/GraveDash-debug.apk
adb install -r build/android/GraveDash-debug.apk
```

### Release build (store)

1. Create a release keystore **once** and back it up outside the repo — losing it means you can never update the Play listing:

   ```bash
   keytool -genkeypair -v -keystore ~/keys/gravedash-release.keystore -alias gravedash \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Give Godot the keystore **without** writing it into the repo — either *Project → Export → Android → Keystore → Release* (stored in `.godot/export_credentials.cfg`, gitignored) or environment variables:

   ```bash
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/gravedash-release.keystore
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=gravedash
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='…'
   godot --headless --path . --export-release "Android" build/android/GraveDash.apk
   ```

3. **Google Play needs an AAB**: *Project → Install Android Build Template…*, then in the preset set **Use Gradle Build = on** and **Export Format = AAB**, and export to `build/android/GraveDash.aab`. Gradle builds may set Min/Target SDK explicitly.

Never commit `*.keystore`, `*.jks`, passwords or `export_credentials.cfg` (all covered by `.gitignore`).

### Verified

On Godot 4.7.2 headless, `--export-debug` and `--export-release` (throwaway keystore via the env vars above) both produce signed arm64 APKs (~48 MB); `apksigner verify` passes and the manifest reports `minSdk 24`, `targetSdk 36`, no permissions, adaptive icon. Ads / leaderboards and a CI signing pipeline are not set up yet.

### Performance checklist

- **Object pooling** — chunks, obstacles, collectibles, and power-ups go through `ObjectPool` (acquire/release); pools clear on restart. Pickups release deferred (never inside a physics callback).
- **Lights** — the Mobile renderer shades at most 8 omni lights per mesh, so chunks keep ≤ 4 real torch lights; the rest are `cast_light = false` torches / lanterns that only show the additive halo + ground light pool. Torch lights distance-fade past ~50 m. No omni/spot shadows in gameplay.
- **Shadows** — only the moon casts (orthogonal, 50 m). Decor never casts shadows.
- **Culling** — `Chunk.gd` sets `visibility_range_end` on decor by size (clutter 70 m, medium 95 m, large 115 m graveyard / 130 m castle); fog hides the cut.
- **Geometry** — pickup sphere/capsule meshes use low segment counts (SoulOrb 18.9k → 1.7k tris). Measured on the VM: ~650–750 draw calls and ~60k–120k triangles per gameplay frame (was ~1,300 draw calls / ~660k triangles).

## Shared UI theme

| Theme | Used by |
|-------|---------|
| `resources/ui/MainMenuTheme.tres` | Main Menu runner chrome (Fredoka / Exo 2, neon StyleBoxes) |
| `resources/ui/GraveDashTheme.tres` | HUD, Pause, Game Over (dark gothic panels) |

Main Menu keeps a live `MenuWorld` 3D backdrop; UI is layered chips, mission cards with progress bars, and a pulsing **START RUN** CTA.

## Witch model textures

FBX ships with an external albedo path `assets/models/Textures_export/M_witch_Base_color.png`.  
A neutral white PNG is committed there so Godot import does not error; mesh **vertex colors** drive the look (`WitchRunner`). Swap in the authored albedo using the same filename when available.

## Biome visuals

Both biomes share `scripts/Chunk.gd`. Each chunk has baked `Props` plus an `EdgeScatter` that is built once per pooled instance and **re-rolled on every spawn** (visibility, jitter, yaw, scale, field placement), so recycled chunks never look identical. Variants never repeat back-to-back (`BiomeManager.pick_chunk_pool_id`).

| Biome | Chunk variants | Look |
|-------|----------------|------|
| Graveyard | `Chunk_Graveyard_01` (classic rows), `_02` (cemetery gate, mausoleums, iron fences), `_03` (dead woods, fallen logs) | Moonlit sky with a fog-free moon + halo, church silhouette, open field past the shoulders with scattered graves / obelisks / trees, ground-mist billboards, soul-glimmer fireflies |
| Haunted Castle | `Chunk_Castle_01` (vaulted corridor), `_02` (open courtyard, battlements, arches), `_03` (great-hall colonnade) | Brick walls + flagstone floor (generated textures), red carpet runner, pillars, moonlit gothic windows, banners, wall torches, braziers, candelabras, suits of armor, chandeliers above the jump apex |

| Resource | Role |
|----------|------|
| `resources/biomes/graveyard_environment.tres` / `haunted_castle_environment.tres` | Sky / fog / glow / tonemap per biome |
| `resources/biomes/graveyard_{ground,shoulder,field}.tres` | Track, shoulder and open-field ground |
| `resources/biomes/haunted_castle_{ground,wall}.tres` | Flagstone floor, brick walls (triplanar) |
| `resources/materials/props/*.tres` | Shared prop materials (stone, iron, wood, cloth, gold, flame, window) |
| `resources/fx/*.tres` | Additive glow materials: torch halos, ground light pools, window glow, mist, glimmers |
| `scenes/levels/props/` | Decor props; everything stays at `|x| >= 5.2` (lanes are at -2.5 / 0 / 2.5) |

Regenerate castle textures, the glow sprite and launcher icons: `godot --headless --path . --script res://tools/gen_textures.gd`

```bash
godot --headless --path . --script res://tools/validate_graveyard_visuals.gd
godot --headless --path . --script res://tools/smoke_run.gd   # 1.9 km run through the castle switch; checks pools don't leak
godot --path . --script res://tools/capture_gameplay.gd -- /tmp/captures   # screenshots (needs a display)
```

## Run balance knobs

| Knob | Where | Current |
|------|-------|---------|
| `START_SPEED` / `MAX_SPEED` / `SPEED_RAMP_PER_SECOND` | `scripts/PlayerController.gd` | **10.5** / **25.0** / **0.17** (`CURSED_SPEED_MULT` 1.48 unchanged) |
| Pattern weights + soul lines | `scripts/levels/ChunkPatterns.gd` | Breath `open_line_*` / `breath_open_wide`; lines typically **5–6** orbs; `BEAT_GAP` 11.0 |
| Intro souls / soul pool | `scripts/LevelGenerator.gd` | Intro line **6** orbs; `POOL_SOUL` initial size **64**; `SOUL_CLEARANCE_Z` 5.0 |

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
| `upgrade_levels` | Dictionary of Soul Shop upgrade id → level (0–5) |
| `skins_owned` / `skin_equipped` | Owned skin ids / equipped skin |

Autoload: `MissionManager` (`autoload/MissionManager.gd`) — separate from `ScoreManager`.

### UI surfaces

- **HUD** — score, multiplier, distance, best, 3 missions, power-ups
- **Main Menu** — high score, multiplier, 3 active missions + progress
- **Pause / Game Over** — multiplier + mission progress

Headless check: `godot --headless --path . --script res://tools/validate_missions.gd`

## Soul economy & shop

All prices and values live in `scripts/economy/EconomyConfig.gd`: pickup values, per-mission
soul rewards, multiplier soul bonus (+5% of collected souls per step above x1, max +100%),
the 8 leveled upgrades (5 levels each) and skin prices.

- **Run payout** = collected souls + mission rewards + multiplier bonus, banked once on Game Over.
- **Soul Shop** (main menu) has **Skins** and **Upgrades** tabs. `UpgradeManager` autoload owns levels.
- Balance model and targets: `godot --headless --path . --script res://tools/validate_economy.gd`
  (typical 2.5 min run ≈ 390 souls; cheap level 125–225; maxing one upgrade ≈ 26 runs; Mage ≈ 31 runs).

## Audio

Buses: **Master → Music / SFX** (`default_bus_layout.tres`).

| Save key | Meaning |
|----------|---------|
| `music_muted` / `sfx_muted` | Mute flags (Settings toggles) |
| `music_volume` / `sfx_volume` | Linear 0–1 bus levels (Settings sliders) |

Placeholder WAV loops/SFX live under:

```
assets/audio/music/   menu_loop.wav, gameplay_loop.wav
assets/audio/sfx/     footstep, jump, slide, soul_pickup, powerup_*, death, ui_click
```

Replace those files with final assets (keep filenames) — no code change needed. Headless: `godot --headless --path . --script res://tools/validate_audio.gd`

## What’s in this slice

- Main Menu: Start, soul wallet, shop stub, high score, multiplier, missions, Settings, Quit
- Game Over: distance, run score, multiplier, missions, high score, Retry, Main Menu, disabled “Watch Ad” stub
- Pause overlay (Esc): Resume / Main Menu + multiplier & missions
- HUD: score, multiplier, distance, best, missions, power-up icons/timers
- Full gameplay: lanes, obstacles (low/high/platform), collectibles, power-ups
- **Biomes:** Graveyard → **Haunted Castle** after ~1200–1500 m
- **Android:** export preset (no permissions, arm64, adaptive icon), landscape, touch swipes, verified debug + release APK export

## License

Project files are yours to iterate on; add a license when you publish.
