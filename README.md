# AutoHotkey Macros

Collection of AutoHotkey macros/scripts for various games and utilities.

## Current Scripts

### Roblox / Prison Life

#### PressureJump

Automates the "Pressure Jump" movement glitch in Roblox Prison Life.

How it works:
1. Crawl under an object so your head is partially blocked.
2. Press the activation keybind.
3. The script crouches, jumps, and rapidly spins to generate upward velocity/fling.

This can be done manually, but the macro provides more consistent timing.

##### Default Keybinds
- `Q` — Activate script
- `F3` — Exit script

##### Recommended Settings
Currently tuned for:
- `800 DPI`
- `0.36` Roblox camera sensitivity
- `240+ FPS` recommended

These values can be changed inside `PressureJump.ahk`.

##### FPS Notes
- Tested at:
  - `60 FPS`
  - `240 FPS`
- Works significantly better at higher FPS.
- FPS values between 60 and 240 have not been thoroughly tested.

---

#### Clip

Automates a wall clip glitch in Roblox Prison Life.

How it works:
1. Crouch against a wall.
2. Press the activation keybind.
3. The script times the uncrouch/freeze sequence so your head partially enters the wall collision, allowing clipping.

##### Requirements
- Spencer Macro Utilities
- Freeze keybind set to `Middle Mouse Button`
- `240+ FPS` recommended

##### Default Keybinds
- `F1` — Activate script
- `F4` — Exit script

##### FPS Notes
- Tested at:
  - `60 FPS`
  - `240 FPS`
- Works significantly better at higher FPS.
- FPS values between 60 and 240 have not been thoroughly tested.

---

## Utilities

### Homework Reminders (iPhone)

An automated school homework capture system for iPhone. Canvas assignments sync
themselves into Apple Reminders, and a daily class checklist catches the homework
teachers only announce out loud. Runs entirely on the phone — no PC, no server,
no Canvas access token.

See `HomeworkReminders/README.md` for the full setup guide.

---

## Requirements

### General
- AutoHotkey v1

### Additional Requirements
- Spencer Macro Utilities (required for `Clip`)

---

## Releases

Current release:
- `v1.0.0-alpha` (pre-release)

Release files currently include compiled executables only.

---

## Notes

- Scripts may require timing adjustments depending on FPS, DPI, sensitivity, or Roblox updates.
- More scripts/macros for other games may be added in future releases.
