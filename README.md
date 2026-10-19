# GraveDash

Horror endless runner (Subway Surfers–style) built with **Godot 4.3 / 4.4**, GDScript, 3D, Mobile renderer — targeted at Android landscape @ 60 FPS.

This repo contains the **MVP slice through step 7**: project structure, player + chunks, obstacles, collectibles/HUD, Ghost Form, Graveyard biome, and chasing ghosts.

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
│   ├── powerups/      Souls + Ghost Form
│   └── ui/            HUD, GameOverUI
├── scripts/           Controllers, generators, enemy AI
├── assets/            models, textures, audio, particles (placeholders)
└── resources/biomes/  Graveyard environment + ground materials
```

## Autoloads

| Name | Role |
|------|------|
| `GameManager` | Menu / Playing / Paused / GameOver |
| `ScoreManager` | Score, distance, highscore |
| `ObjectPool` | Generic scene pooling (chunks, obstacles, chasers) |
| `AudioManager` | Stub (`play_sfx` no-ops until streams are wired) |
| `BiomeManager` | Applies Graveyard atmosphere at run start |
| `SaveSystem` | ConfigFile highscore persistence |

## What’s in this slice

- 3-lane auto-runner with jump, slide (hitbox shrink), speed ramp 13 → 30
- SpringArm camera + dust particles on the player
- Chunk length 45, 5 ahead, rear recycle via `ObjectPool`
- Pooled obstacles: open pit, fallen gravestone, side-incoming sweeper
- Collectibles: Soul orb (1), Big Soul (5), Golden Coffin (25) via ObjectPool
- **Ghost Form** power-up (~9s): phase through hazards + chaser catch, purple trail + HUD timer
- **Graveyard biome**: heavy fog, cold blue/purple moonlight, muddy track, roadside props, torches, falling leaves
- **Chaser ghosts** (default pack of 2, range 1–3): stay behind the player, match/slightly exceed run speed, close in if you camp a lane; catch distance 2.2 → Game Over via `Player.die` / `GameManager.trigger_game_over`
- **Almost Caught** UX: screen-edge darken + vignette + “ALMOST CAUGHT” label when gap &lt; 7; suppressed during Ghost Form
- Live HUD (Score / Distance m / Best / Ghost) + Game Over overlay with Restart
- High score persisted through SaveSystem (`user://gravedash_save.cfg`)

## Not yet (later MVP steps)

Additional biomes, more enemy types, shop UI, touch swipe gestures, Android export presets, real audio beds.

## License

Project files are yours to iterate on; add a license when you publish.
