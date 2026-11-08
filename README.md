# One-on-One

A one-on-one 3D fighting game for phones, built with **Godot 4.3**: real animated 3D fighters on a
3D stage, fighting along a 2D line, controlled with touch gestures.

## Status: milestone 1 (look test)
`main.tscn` plays a scripted exchange between two fighters on the village stage. It shows the
characters, animations, hit reactions, impact effects, fight camera, hitstop, slow motion and a
K.O. **There are no controls yet.** Gameplay (gesture controls, CPU opponent, rounds) is
milestone 2, once the look is approved.

## Builds
- **Web preview:** https://ravic906.github.io/One-on-one/
- **Android APK:** every push builds one. Open the repository's **Actions** tab, pick the latest
  "Build web + Android" run, and download the `one-on-one-apk` artifact. To install it on your phone,
  allow "Install unknown apps" for your browser or file manager.

## Layout
- `view/fighter_model.gd`: assembles a fighter (outfit + head + hair on one skeleton) and plays the UAL animations
- `view/stage.gd`: village street built from modular kit pieces, lighting and shadows
- `view/camera_rig.gd`, `view/fx.gd`: fight camera; sparks, flashes, dust, energy blast
- `ui/hud.gd`: health bars, timer, announcements
- `data/roster.gd`: fighters (look and stats)
- `tools/`: developer scripts (head cutting, look-dev renders, impact-frame measurement)

## Developer commands
```bash
godot --headless --import
# render a still or record a video (needs a display; xvfb-run works)
xvfb-run godot --rendering-driver opengl3 --script res://tools/stage_shot.gd -- out.png
xvfb-run godot --rendering-driver opengl3 --write-movie out.avi --fixed-fps 30 -- --movie-seconds=15
godot --headless --export-release "Web" build/web/index.html
```

Art: Quaternius, CC0. See `assets/CREDITS.md`.
