# One-on-One

A pure one-on-one 2D fighting game for phones, built with **Godot 4.3**. Two fighters, one rooftop, best of three rounds against the CPU.

## Play
- **Stick (left thumb):** drag anywhere on the left half. Up = jump, down = crouch, flick forward twice = dash, **hold away = block**.
- **PUNCH** fast · **KICK** strong (down+KICK = sweep) · **SPECIAL** energy blast (full meter = **SUPER** rush) · **THROW** beats blocking.
- Combos: a landed hit cancels into the next button, e.g. `PUNCH > PUNCH > KICK > SPECIAL`.
- Keyboard: arrows/WASD, J punch, K kick, L special, I throw, P pause.

## Fighters
| | Style | Speed | Power | HP |
|---|---|---|---|---|
| KADE | balanced | 1.0 | 1.0 | 1000 |
| VEXA | fast, fragile | 1.22 | 0.86 | 920 |
| GORR | slow, heavy | 0.82 | 1.25 | 1120 |

## Frame data (60 fps)
| Move | Startup | Active | Recovery | Dmg | Level |
|---|---|---|---|---|---|
| Punch | 4 | 3 | 9 | 35 | mid |
| Kick | 9 | 4 | 17 | 85 | mid |
| Crouch punch | 4 | 3 | 9 | 30 | mid |
| Sweep | 8 | 4 | 20 | 70 | low, knockdown |
| Jump kick | 5 | 9 | 6 | 65 | high |
| Throw | 5 | 2 | 26 | 110 | unblockable |
| Super | 16 | 24 | 22 | 250 | mid, knockdown |

All tuning lives in `scripts/game_data.gd`.

## Project layout
- `scripts/fighter.gd`: state machine, physics, hit reactions, procedural body drawing
- `scripts/arena.gd`: 60 Hz simulation, rounds, hit detection, projectiles, effects, stage
- `scripts/fighter_ai.gd`: CPU opponent (Easy / Normal / Hard)
- `scripts/touch_controls.gd`, `scripts/hud.gd`, `scripts/main.gd`, `scripts/sfx.gd` (synthesized audio)
- `tests/run_tests.gd`: headless rules tests

## Run, test, export
```bash
godot --headless --import
godot --headless --script res://tests/run_tests.gd          # rules tests
godot --headless --export-release "Web" build/web/index.html  # web build
cd build/web && python3 -m http.server 8000                    # open http://localhost:8000
```
For Android, install the Android SDK and set it in Godot's editor settings, then export the "Android" preset.
