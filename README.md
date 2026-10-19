# GraveDash

Horror endless runner (Subway Surfers–style) built with **Godot 4.3 / 4.4**, GDScript, 3D, Mobile renderer — targeted at Android landscape @ 60 FPS.

This repo currently contains the **MVP slice 1–2**: project structure, core autoloads, full 3-lane player, and a simple chunk-based level generator.

## Requirements

- [Godot 4.3 or 4.4](https://godotengine.org/download) (Standard build is fine)
- Optional: Android export templates when you reach device builds

## Open & run

1. Launch Godot 4.3/4.4 → **Import** → select this folder’s `project.godot`
2. Open `scenes/levels/Main.tscn` (already set as the main scene)
3. Press **F5** (Play Project) or **F6** (Play Current Scene)

### Desktop controls (for testing)

| Action | Keys |
|--------|------|
| Lane left / right | `A` / `D` or `←` / `→` |
| Jump | `Space` or `↑` |
| Slide | `Ctrl` or `S` or `↓` |
| Pause | `Esc` |

Swipe actions (`swipe_left`, `swipe_right`, `swipe_up`, `swipe_down`) are defined in Project Settings → Input Map for later mobile gesture wiring.

## Project layout

```
res://
├── autoload/          GameManager, ScoreManager, ObjectPool (+ stubs)
├── scenes/
│   ├── player/        Player.tscn
│   ├── levels/        Main.tscn, Chunk_Graveyard_01.tscn
│   └── …              obstacles, enemies, powerups, ui, managers (placeholders)
├── scripts/           PlayerController, LevelGenerator, Chunk
├── assets/            models, textures, audio, particles
└── resources/
```

## Autoloads

| Name | Role |
|------|------|
| `GameManager` | Menu / Playing / Paused / GameOver |
| `ScoreManager` | Score, distance, highscore |
| `ObjectPool` | Generic scene pooling (chunks use this) |
| `AudioManager` | Stub |
| `BiomeManager` | Stub (`graveyard` default) |
| `SaveSystem` | Stub ConfigFile highscore persistence |

## What’s in this slice

- 3-lane auto-runner with jump, slide (hitbox shrink), speed ramp 13 → 30
- SpringArm camera + dust particles on the player
- Chunk length 45, 5 ahead, rear recycle via `ObjectPool`
- Placeholder Graveyard ground chunk + night fog lighting

## Not yet (later MVP steps)

Biomes beyond placeholder Graveyard, obstacles/enemies, power-ups, HUD/shop UI, touch swipe gestures, Android export presets, audio beds.

## License

Project files are yours to iterate on; add a license when you publish.
