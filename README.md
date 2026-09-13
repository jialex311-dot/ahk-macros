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

## Roblox / Dungeon Quest

### DQCycler

Auto-cycles your two spell slots for carrying lower dungeons.

The point is the spacing. Run the same carry spell in both slots and the macro
holds slot 2 back until it is **half a cycle** behind slot 1, so a spell goes out
every 2.5s instead of two landing together and leaving the rest of the cycle
dead. That keeps a timed effect — Pulse Waves' and Arrow Rain's speed boost, for
instance — permanently up. Once the offset is set, both keys just get spammed;
presses that land on cooldown do nothing, so the rotation holds itself together
without you tracking it.

Measured on the Mage preset: casts at 0.1s, 2.6s, 5.2s, 7.7s, 10.3s, 12.8s — a
worst-case gap of 2.6s. Warrior comes out at 2.4s. Any buff lasting longer than
that never drops.

The spam is deliberate. It costs about 2.5 keypresses per cast instead of 1, and
buys back the fact that a single dropped input would otherwise cost a whole cast.
Cast timing is identical either way.

#### Keybinds
- `F6` — Start/stop
- `F7` — Next profile (Mage / Warrior)
- `F4` — Settings window
- `F10` — Show/hide the panel
- `Shift+Esc` — Exit

#### Settings (`F4`)
Everything is editable in the settings window — no need to open the script.
Changes are saved to `DQCycler.ini` next to the file and reloaded on startup.

| Section | What's in it |
| --- | --- |
| Spell | Profile preset, plus the key, activation time and cooldown for each slot |
| Connection | Your ping |
| Behaviour | Chat guard, focus guard, click-after-cast, show panel |
| Advanced | hold / lead / gap keypress timing |

Presets:

| Profile | Spell | Activation | Listed CD | Full cycle |
| --- | --- | --- | --- | --- |
| Mage | Pulse Waves | 1.0s | 4s | 5.0s |
| Warrior | Arrow Rain | 0.5s | 4s | 4.5s |

Both slots default to the same spell, which is the normal carry setup. Give the
two slots different values and the scheduler handles the uneven cooldowns fine —
the profile just shows as "Custom setup".

#### Set your ping
This is the one setting worth tuning. Find it in Roblox under **Esc > Settings >
Performance Stats** (or `Shift+F3`) while you are in a dungeon.

The macro cannot see your real cooldowns, so it pads every one by this much
before pressing. Too low and the press lands before the server agrees the spell
is up, and gets eaten. Too high and you donate uptime. If casts still get
swallowed, add 30-50 to whatever your ping reads. The pad never drops below 25ms,
because Roblox only ticks at 60Hz.

#### Chat guard
Opening Roblox chat pauses the macro, so your spell keys never end up in the chat
box. It watches `/` and `Enter` to catch chat opening and `Enter` or `Esc` to
catch it closing, then resumes shortly after. Nothing is swallowed — those keys
still reach Roblox normally, the macro only listens. A 20s failsafe force-resumes
if a close is ever missed.

Cooldowns are tracked as absolute timestamps, so pausing never desyncs the
rotation. If you type long enough for both spells to come up, the scheduler
re-establishes the stagger by itself on the next cast.

#### Panel
An always-on-top panel shows run state, the active profile, your ping, and a live
cooldown bar per slot. Drag it anywhere — the position is remembered. `F10` hides
it. It never takes focus, so it will not knock you out of Roblox.

The state line is the thing to watch:
- `STOPPED` — idle, press `F6`.
- `RUNNING` — actively casting.
- `TYPING` — chat is open, paused until you are done.
- `WAITING` — running, but Roblox is not the focused window so nothing is being
  sent. This is what you will see if you tab out.

#### Notes
- The panel needs Roblox in **windowed or borderless** mode; exclusive fullscreen
  will draw over it.
- Press `F6` with both spells off cooldown. The macro times blind — if you start
  it mid-cooldown it will believe a phantom cast fired and stay out of sync.
- If Roblox ignores the keys entirely, change `SendMode("Input")` near the top to
  `SendMode("Event")` and run AutoHotkey as administrator.
- Your ping pad and the key hold time mean each cycle runs slightly longer than
  the spell's true cooldown. That is deliberate slack, not drift — it does not
  accumulate.

---

## Requirements
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

## Roblox / Dungeon Quest

### AbilityCycle

Auto-cycles your two spell slots (`Q` and `E`) for carrying lower dungeons.

The point is the stagger. Run the same carry spell in both slots and the macro
times the opener off the spell's activation animation — slot 2 goes out the
instant slot 1 finishes casting — so the two cooldowns stay permanently offset
and one spell is always going out. Once that offset is set, the keys just get
spammed; presses that land on cooldown do nothing, so the rotation holds itself
together without you tracking it.

The spam is deliberate. It costs about 2.5 keypresses per cast instead of 1, and
buys back the fact that a single dropped input would otherwise cost a whole cast.
Cast timing is identical either way.

#### Default Keybinds
- `F6` — Start/stop
- `F7` — Next profile (Mage / Warrior)
- `F10` — Show/hide the status panel
- `Shift+Esc` — Exit script

#### Profiles

| Profile | Spell | Activation | Listed CD | Full cycle |
| --- | --- | --- | --- | --- |
| Mage | Pulse Waves | 1.0s | 4s | 5.0s |
| Warrior | Arrow Rain | 0.5s | 4s | 4.5s |

Both slots default to the same spell, which is the normal carry setup. To run
two different spells, just give `q` and `e` their own `cast` / `cd` values in
the `PROFILES` block — the scheduler handles uneven cooldowns fine.

#### Set your ping
`PING_MS` is the one setting worth touching. Find your ping in Roblox under
**Esc > Settings > Performance Stats** (or `Shift+F3`) while you are in a
dungeon, and put that number in.

The macro cannot see your real cooldowns, so it pads every one by this much
before pressing. Too low and the press lands before the server agrees the spell
is up, and gets eaten. Too high and you donate uptime. If casts still get
swallowed, add 30-50 to whatever your ping reads. The pad never drops below
`MARGIN_FLOOR` (25ms), because Roblox only ticks at 60Hz.

#### Chat guard
Opening Roblox chat pauses the macro, so your spell keys never end up in the
chat box. It watches `/` and `Enter` to catch chat opening and `Enter` or `Esc`
to catch it closing, then resumes after `RESUME_MS`.

Nothing is swallowed — those keys still reach Roblox normally, the macro only
listens. `CHAT_TIMEOUT` force-resumes after 20s in case a close is ever missed.
Set `CHAT_GUARD := false` to turn the whole thing off.

Cooldowns are tracked as absolute timestamps, so pausing never desyncs the
rotation. If you type long enough for both spells to come up, the scheduler
re-establishes the stagger by itself on the next cast.

#### Status panel
An always-on-top panel shows whether it is running, the active profile, your
ping, and a live cooldown readout per slot. Drag it anywhere; `F10` hides it. It
never takes focus, so it will not knock you out of Roblox.

The state line is the thing to watch:
- `STOPPED` — idle, press `F6`.
- `RUNNING` — actively casting.
- `TYPING` — chat is open, paused until you are done.
- `WAITING` — running, but Roblox is not the focused window so nothing is being
  sent. This is what you will see if you tab out.

Set `SHOW_PANEL := false` to turn it off, or move `PANEL_X` / `PANEL_Y` to change
where it opens.

#### Other settings
- `GAME_WINDOW` — only fires while Roblox is focused. Set to `""` to disable the
  check if the script does nothing on your setup.
- `LEAD_MS` / `GAP_MS` — how early and how often the spam taps. These change the
  number of keypresses, never the cast timing.
- `HOLD_MS` (40) — key hold duration. Raise it if Roblox drops inputs.
- `CLICK_AFTER_CAST` — adds a left-click after each cast, for spells that need
  a placement click.
- If Roblox ignores the keys entirely, change `SendMode("Input")` near the top to
  `SendMode("Event")` and run AutoHotkey as administrator.

#### Notes
- The panel needs Roblox in **windowed or borderless** mode; exclusive fullscreen
  will draw over it.
- Press `F6` with both spells off cooldown. The macro times blind — if you start
  it mid-cooldown it will believe a phantom cast fired and stay out of sync.
- Your ping pad and `HOLD_MS` mean each cycle runs slightly longer than the
  spell's true cooldown. That is deliberate slack, not drift — it does not
  accumulate.

---

## Requirements
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

## Roblox / Dungeon Quest

### AbilityCycle

Auto-cycles your two spell slots (`Q` and `E`) for carrying lower dungeons.

The point is the stagger. Run the same carry spell in both slots and the macro
times the opener off the spell's activation animation — slot 2 goes out the
instant slot 1 finishes casting — so the two cooldowns stay permanently offset
and one spell is always going out. Once that offset is set, the keys just get
spammed; presses that land on cooldown do nothing, so the rotation holds itself
together without you tracking it.

#### Default Keybinds
- `F6` — Toggle on/off
- `F7` — Next profile (Mage / Warrior)
- `F8` — Next mode (cycle / spam / mash)
- `F10` — Show/hide the status panel
- `Shift+Esc` — Exit script

#### Profiles

| Profile | Spell | Activation | Listed CD | Full cycle |
| --- | --- | --- | --- | --- |
| Mage | Pulse Waves | 1.0s | 4s | 5.0s |
| Warrior | Arrow Rain | 0.5s | 4s | 4.5s |

Both slots default to the same spell, which is the normal carry setup. To run
two different spells, just give `q` and `e` their own `cast` / `cd` values in
the `PROFILES` block — the scheduler handles uneven cooldowns fine.

#### Modes
- `cycle` — one press per spell, fired exactly on cooldown. Tightest, but a
  single dropped input costs you that cast.
- `spam` — timed opener, then taps in a burst starting 300ms before each spell
  comes up. Same cast timing as `cycle`, just forgiving about dropped inputs.
  **Default.**
- `mash` — timed opener, then blind `Q`/`E` alternation forever. Use only if
  the other two misbehave.

#### Settings
Inside `AbilityCycle.ahk`:
- `GAME_WINDOW` — only fires while Roblox is focused. Set to `""` to disable the
  check if the script does nothing on your setup.
- `MARGIN_MS` (70) — pad added to every cooldown to cover ping and server tick.
  Lower it on good ping to tighten the rotation; raise it if casts get eaten.
- `LEAD_MS` / `GAP_MS` — how early and how often `spam` mode taps.
- `HOLD_MS` (40) — key hold duration. Raise it if Roblox drops inputs.
- `CLICK_AFTER_CAST` — adds a left-click after each cast, for spells that need
  a placement click.
- If Roblox ignores the keys entirely, change `SendMode("Input")` near the top to
  `SendMode("Event")` and run AutoHotkey as administrator.

#### Status panel
An always-on-top panel shows whether it is running, the active profile and mode,
and a live cooldown readout per slot. Drag it anywhere; `F10` hides it. It never
takes focus, so it will not knock you out of Roblox.

The state line is the thing to watch:
- `STOPPED` — idle, press `F6`.
- `WAITING` — running, but Roblox is not the focused window so nothing is being
  sent. This is what you will see if you tab out.
- `RUNNING` — actively casting.

Set `SHOW_PANEL := false` to turn it off, or move `PANEL_X` / `PANEL_Y` to change
where it opens.

#### Notes
- The panel needs Roblox in **windowed or borderless** mode; exclusive fullscreen
  will draw over it.
- `MARGIN_MS` and `HOLD_MS` mean each cycle runs ~110ms longer than the spell's
  true cooldown. That is deliberate slack, not drift — it does not accumulate.

## Requirements

### General
- AutoHotkey v1 — `PressureJump`, `Clip`
- AutoHotkey v2 — `PressureJumpV2`, `DQCycler`

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
