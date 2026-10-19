# GraveDash

Horror endless runner (Subway Surfers–style) built with **Godot 4.3 / 4.4**, GDScript, 3D, Mobile renderer — targeted at Android landscape @ 60 FPS.

MVP through **step 10 (UI)** and **step 9 Haunted Castle biome**: menus plus Graveyard → Castle distance transition.

## Requirements

- [Godot 4.3 or 4.4](https://godotengine.org/download) (Standard build is fine)
- Optional: Android export templates when you reach device builds

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

## Scene flow

```
MainMenu  --Start-->  Main (gameplay)
   ^                      |
   |                   Game Over / Pause → Main Menu
   +-------- Retry reloads Main --------+
```

## Shared UI theme

`resources/ui/GraveDashTheme.tres` — dark gothic StyleBoxes for panels/buttons across Menu, Settings, HUD, Pause, Game Over.

## Settings persistence

Audio mute prefs via `AudioManager` → `SaveSystem` (`user://gravedash_save.cfg`):

| Key | Meaning |
|-----|---------|
| `music_muted` | Music bus / flag |
| `sfx_muted` | SFX bus / flag |
| `highscore` | Best score (ScoreManager) |

## What’s in this slice

- Main Menu: Start, High Score, Settings (music/SFX mute), Quit
- Game Over: distance, souls/score, high score, Retry, Main Menu, disabled “Watch Ad” stub
- Pause overlay (Esc): Resume / Main Menu
- HUD: score, distance, best, power-up icons/timers (Ghost Form + others)
- Full gameplay: lanes, obstacles, collectibles, power-ups, chasers
- **Biomes:** Graveyard start → **Haunted Castle** after ~1200–1500 m (black fog fade; corridor chunks with walls/chandeliers/curtains)

## License

Project files are yours to iterate on; add a license when you publish.
