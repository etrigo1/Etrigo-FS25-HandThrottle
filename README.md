[🇵🇹 Ler em Português](README.pt.md) | 🇺🇸 English

# 🚜 Hand Throttle (Etrigo_HandThrottle)
**Current Version:** 1.3.0.0  |  **Farming Simulator 25**  |  **Multiplayer:** supported

A real hand throttle for tractors with a **manual gearbox**. No more holding the pedal down on a long, heavy climb: set the throttle or the engine RPM once and just work the gearbox.

---

## 🌟 Features

### Two modes
| Mode | Simulates | Behaviour |
|---|---|---|
| **%** | Hand lever of an older tractor, linked to the pedal | Fixes the **throttle position** (0–100 %). In neutral the engine revs freely; in gear it is the same as pressing the pedal. Uphill, the RPM drops. |
| **RPM** | Engine with an RPM governor | Fixes the **target RPM** (e.g. 1800). The throttle is adjusted automatically to hold it uphill and downhill, up to the engine's power limit. If even full throttle isn't enough, shift down. |

### Driving rules
- **The pedal always wins**: press it further than the hand throttle and the higher value is used. Release it and the hand value comes back.
- **Braking suspends** the hand throttle while you brake.
- **Cruise control on** → the hand throttle stays out of the way.
- Only acts with **manual gear shifting** (gears + manual shifting). CVT and automatic gearboxes are left to the game; the HUD shows `OFF` and a warning is shown.

### On/off without losing the setting
- The **on/off** key pauses the hand throttle and keeps its mode and value (handy at the headland). Press it again to resume exactly where you were.
- **Per-tractor memory**: leaving a tractor or switching the engine off pauses it and remembers the setting of *that* tractor. When you come back, the HUD shows `OFF`; press on/off to resume. It never resumes on its own (so the tractor never moves off by itself). The memory lasts for the game session.

### Movable HUD
- A small line on screen, e.g. `Hand throttle: 1800 RPM`.
- **Move HUD** key: the mouse cursor appears, drag the HUD with the left button, right-click it to reset, press the key again to save.
- The position is saved per player in `modSettings/Etrigo_HandThrottle.xml`.

---

## 🎮 Controls (all can be changed in Options → Controls)
| Action | Default key |
|---|---|
| Change mode (OFF → % → RPM → OFF) | `Left Ctrl + H` |
| On/off (keeps mode and value) | `Right Ctrl + Numpad .` |
| Increase (5 % / 50 RPM) | `Left Ctrl + Page Up` |
| Decrease (5 % / 50 RPM) | `Left Ctrl + Page Down` |
| Move HUD | `Right Ctrl + Numpad 0` |

Holding increase/decrease repeats the step.

> ⚠️ Bind the mode and on/off actions to **buttons**, not to an analog axis. An axis crossing its centre triggers them repeatedly.

---

## 🔧 Compatibility
- Works on every vehicle type with an engine that can be driven (base game, DLCs and mods), except locomotives.
- **FS25_RPMResponsiveSpeeds** also changes RPM behaviour. Both can be loaded, but disable one of them if you want to test the other in isolation.
- No savegame data is written.

## 📦 Installation
Download `Etrigo_HandThrottle.zip` from the [Releases](../../releases) page and place it in your `Documents/My Games/FarmingSimulator2025/mods` folder. Don't unzip it.

## 📜 Changelog
See [CHANGELOG.md](CHANGELOG.md).

---
**Author:** Etrigo
