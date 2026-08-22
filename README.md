# Omarchy Backrooms

A full-screen 3D liminal space horror plugin for [Omarchy](https://github.com/basecamp/omarchy) / [Quickshell](https://quickshell.outfoxxed.me).

You clipped out of reality. Now you're here. The fluorescent lights buzz. The yellow wallpaper peels. The carpet is damp. You are not alone.

## Screenshot

*It's better experienced than screenshotted.*

## Features

- **Ray-marched 3D environment** — infinite procedural Backrooms rendered in a real-time GLSL fragment shader. No game engine, no 3D library, just math.
- **Pillar maze** — randomly generated office pillars, cross-walls, and corridors. No two playthroughs are the same.
- **WASD + mouse controls** — standard FPS movement with sprint (Shift), head bob, and footsteps.
- **Sanity system** — your sanity drains in darkness and during flicker events. Reach zero and you never leave.
- **Jumpscare entity** — a dark figure with glowing red eyes that lunges at you with screen shake and a piercing sting.
- **Scare director** — randomly timed events that escalate over time: fluorescent flicker, distant thuds, whispered voices, total darkness, and jumpscares.
- **Procedural audio** — all 13 sound effects and music tracks generated from scratch with pure Python (no samples, no dependencies).
- **Ambient horror** — drone soundtrack, fluorescent hum, footsteps, heartbeat at low sanity, and more.

## Controls

| Key | Action |
|-----|--------|
| W/A/S/D | Move |
| Mouse | Look around |
| Shift | Sprint |
| P | Pause |
| ESC | Exit |
| Click | Start / interact |

## Installation

### Option 1: Clone into plugins directory

```bash
git clone https://github.com/Boboloboramba/omarchy-backrooms.git \
  ~/.config/omarchy/plugins/local.backrooms
```

### Option 2: Clone anywhere and symlink

```bash
git clone https://github.com/Boboloboramba/omarchy-backrooms.git \
  ~/omarchy-backrooms

ln -s ~/omarchy-backrooms ~/.config/omarchy/plugins/local.backrooms
```

### Launch

- Click the **home icon** in your Omarchy bar
- Or run: `omarchy-shell shell toggle local.backrooms`

## Requirements

- [Omarchy](https://github.com/basecamp/omarchy) with Quickshell
- Qt 6 with QtMultimedia and QtQuick
- `qsb` (Qt Shader Tools) — only if modifying the shader source
- `hyprctl` — for cursor recentering during mouse look (gracefully degrades if absent)

## Regenerating Sounds

All audio is procedurally generated. To regenerate:

```bash
python3 generate-sounds.py
```

This overwrites everything in `sounds/` using pure stdlib Python (wave + math). No numpy, no external dependencies.

## Regenerating the Shader

The fragment shader is written in GLSL 440 and baked to `.qsb` with:

```bash
/usr/lib/qt6/bin/qsb --qt6 shaders/backrooms.frag -o shaders/backrooms.frag.qsb
```

Edit `shaders/backrooms.frag` to change the maze layout, lighting, textures, or jumpscare entity.

## How It Works

### Rendering

The entire 3D scene is rendered in a single fullscreen `ShaderEffect` using **ray marching** (signed distance fields). The fragment shader:

1. Casts a ray from the camera through each pixel
2. Steps along the ray checking distance to the nearest surface (pillars, walls, floor, ceiling)
3. Computes lighting from overhead fluorescent panels with soft shadows
4. Applies fog, film grain, scanlines, and vignette
5. Overlays the jumpscare entity in screen space when triggered

No vertex geometry is rendered. Everything is one quad with a very loud shader.

### Maze Generation

The maze uses a hash function on grid cells to deterministically place:
- **Pillars** (55% of cells) — offset randomly within their cell
- **Cross-walls** (22% of cells) — span the full cell in a random orientation

The same hash function is mirrored in JavaScript for collision detection.

### Audio

All sounds are synthesized in `generate-sounds.py` using pure Python stdlib:
- **Drone** — layered detuned saw/sine chords with slow LFO amplitude modulation
- **Fluorescent buzz** — 120Hz harmonic stack with noise hiss
- **Footsteps** — filtered brown noise bursts with sub-thump
- **Jumpscare sting** — dissonant saw cluster with bandpass noise scream
- **Heartbeat** — dual low-frequency pulses
- **Whispers** — randomized bandpass noise chunks

## File Structure

```
omarchy-backrooms/
├── Backrooms.qml          # Entry point (panel + IPC)
├── BarWidget.qml          # Bar launcher button
├── Game.qml               # Game logic, controls, HUD, sounds
├── manifest.json          # Plugin metadata
├── generate-sounds.py     # Procedural audio generator
├── shaders/
│   ├── backrooms.frag     # GLSL 440 ray-march shader
│   └── backrooms.frag.qsb # Baked shader (compiled)
└── sounds/
    ├── drone.wav          # Ambient soundtrack loop
    ├── buzz.wav           # Fluorescent hum loop
    ├── footstep[1-4].wav  # Footstep variants
    ├── sting.wav          # Jumpscare sound
    ├── thud.wav           # Distant impact
    ├── whisper.wav        # Eerie whisper
    ├── heartbeat.wav      # Low sanity heartbeat
    ├── switch.wav         # Light switch click
    ├── death.wav          # Game over sound
    └── enter.wav          # Game start riser
```

## License

MIT
