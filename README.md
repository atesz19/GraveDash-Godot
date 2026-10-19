# GraveDash

Horror endless runner (Subway Surfers–style) built with **Godot 4.3 / 4.4**, GDScript, 3D, Mobile renderer — targeted at Android landscape @ 60 FPS.

This repo contains the **MVP slice through step 8**: structure, player + chunks, obstacles, collectibles/HUD, Ghost Form, Graveyard biome, chasing ghosts, and the full power-up set.

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
├── autoload/          GameManager, ScoreManager, ObjectPool, BiomeManager, …
├── scenes/
│   ├── player/        Player.tscn
│   ├── levels/        Main.tscn, Chunk_Graveyard_01.tscn, atmosphere + props
│   ├── obstacles/     Pit, Gravestone, SideIncoming
│   ├── enemies/       ChaserGhost, ChaserSpawner
│   ├── powerups/      Souls + Ghost Form, Magnet, Holy Light, Second Chance, Cursed Speed
│   └── ui/            HUD, GameOverUI
├── scripts/           Controllers, generators, enemy AI, collectibles
├── assets/            models, textures, audio, particles (placeholders)
└── resources/biomes/  Graveyard environment + ground materials
```

## Autoloads

| Name | Role |
|------|------|
| `GameManager` | Menu / Playing / Paused / GameOver |
| `ScoreManager` | Score, distance, highscore |
| `ObjectPool` | Generic scene pooling (chunks, obstacles, chasers, pickups) |
| `AudioManager` | Stub (`play_sfx` no-ops until streams are wired) |
| `BiomeManager` | Applies Graveyard atmosphere at run start |
| `SaveSystem` | ConfigFile highscore persistence |

## What’s in this slice

- 3-lane auto-runner with jump, slide, speed ramp 13 → 30
- Pooled obstacles + soul collectibles + Game Over / Restart
- **Power-ups** (ObjectPool + LevelGenerator, ~22% ability chance / chunk after intro):
  - **Ghost Form** (~9s) — phase through hazards; protects from chaser catch
  - **Soul Magnet** (~11s) — pulls nearby souls toward the player
  - **Holy Light** (~7s) — radius blast recycles obstacles + banishes chasers
  - **Second Chance** (1 charge) — one lethal hit → hover escape instead of Game Over
  - **Cursed Speed** (~6s) — big speed boost, sluggish/overshoot lane changes
- HUD icons + timers (and Second Chance charge indicator)
- Chaser ghosts with Almost Caught vignette
- Graveyard biome atmosphere

## Not yet (later MVP steps)

Additional biomes, more enemy types, shop UI, touch swipe gestures, Android export presets, real audio beds.

## License

Project files are yours to iterate on; add a license when you publish.
