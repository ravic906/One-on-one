# One-on-One

A pure one-on-one 2D fighting game for phones, built with **Godot 4.3**. Two fighters, one rooftop, best of three rounds against the CPU.

**Play in your browser / on your phone:** https://ravic906.github.io/One-on-one/ (after GitHub Pages is enabled, see below). Turn the phone sideways; on Android use "Add to Home screen" for full screen.

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

## Graphics
Everything is drawn in code, so there are no image files to load:
- **Fighters:** shaded, tapered body parts with a warm sunset rim light, plus gloves, boots and trailing headbands.
- **Motion and impact:** swoosh trails on attacks and after-images on dashes and supers. Impact stars, sparks, rings and energy blasts glow (additive blending). Supers dim the screen behind speed lines, and big hits and K.O.s flash the screen.
- **Camera:** frames both fighters, zooms in as they close the gap, and punches in on a K.O.
- **Stage:** background layers move at different speeds (sky, stars, sun, clouds, two skyline layers), with floating dust, a sun reflection on the roof and a darkened screen edge.

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
Developer flags (pass after `--`): `--showcase` runs a CPU-vs-CPU match with the HUD, and `--slowmo=0.2` slows the game down, which helps for trailers and screenshots.

### Phone link (GitHub Pages)
`.github/workflows/web.yml` runs the tests and exports the web build on every push. To publish it, turn Pages on once: **Settings → Pages → Build and deployment → Source: GitHub Actions**. Then re-run the workflow, or push again.

For Android, install the Android SDK and set it in Godot's editor settings, then export the "Android" preset.
