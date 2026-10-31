[🇵🇹 Ler em Português](README.pt.md) | 🇺🇸 English

# 🚜 Hand Throttle (Etrigo_HandThrottle)
**Current Version:** 1.4.0.0  |  **Farming Simulator 25**  |  **Multiplayer:** supported

A real hand throttle for every tractor. With a manual gearbox, set the throttle or the RPM and just work the gears; with a CVT, set the speed like the drive lever of modern tractors; and with any gearbox, cap the engine's maximum RPM.

---

## 🌟 Modes

The mode key only cycles through the modes that fit the tractor's gearbox (and are enabled in the settings):
- **Manual gearbox:** system off → % → RPM → Limit → system off
- **CVT / automatic gearbox:** system off → km/h → Limit → system off

| Mode | Gearboxes | What it does |
|---|---|---|
| **%** | Manual | Fixes the **throttle position** (0–100 %), like the hand lever of an older tractor. In neutral the engine revs freely; in gear it is the same as pressing the pedal. Uphill, the RPM drops. |
| **RPM** | Manual | Fixes the **target RPM** (e.g. 1800). The throttle is adjusted automatically to hold it uphill and downhill, up to the engine's power limit. If even full throttle isn't enough, shift down. |
| **km/h** | CVT / automatic | Like the drive lever of modern CVT tractors: switching it on **keeps the current speed** (standing still: 1 km/h), increase/decrease change it by 1 km/h. **Separate memory for forward and reverse** (with the manual shuttle). The game's cruise control speed is left untouched. |
| **Limit** | All | The engine "governor": full throttle is allowed, but the RPM **never goes above** the set value. Starts at the maximum RPM; lower it from there. |

### Driving rules
- **The pedal always wins**: press it further and your foot counts. In km/h mode, going **5 km/h** above the target with the pedal pauses the mode.
- **Braking**: in %, RPM and Limit modes it only suspends the hand throttle while braking; in km/h mode it pauses the mode. Configurable per mode.

### Hand throttle or cruise control, never both
Like the cruise control and speed limiter of a car, which share the same buttons:

| State | HUD | Cruise control |
|---|---|---|
| **System off** | hidden | works normally |
| **Paused** | `… OFF` | blocked |
| **Mode on** | shown | blocked |

- Switching a mode on turns the cruise control off. While the hand throttle is on or paused, the cruise control keys are disabled and, if something else switches it on, it is switched off at once.
- So you can **bind the same buttons** (on/off, increase, decrease) to the cruise control and to the hand throttle: the mode key decides which one they control. Only the mode key must stay on a button of its own.
- Works with the game's cruise control and with **Vehicle Inspector**.

### On/off without losing the setting
- The **on/off** key pauses and keeps the mode and value (handy at the headland). Press it again to resume: %, RPM and Limit come back to the same value; km/h mode resumes at **your current speed**.
- **Per-tractor memory**: leaving a tractor or switching the engine off pauses it and remembers the setting of *that* tractor. It never resumes on its own. Lasts for the game session.

### Movable HUD
- A small line on screen, e.g. `Hand throttle: 1800 RPM`, `Hand throttle: 12 km/h R` (R = reverse), `Hand throttle: max 1600 RPM`.
- **Move HUD** key: the mouse cursor appears, drag with the left button, right-click to reset, press the key again to save.

---

## 🎮 Controls (all can be changed in Options → Controls)
| Action | Default key |
|---|---|
| Change mode | `Left Ctrl + H` |
| On/off (keeps mode and value) | `Right Ctrl + Numpad .` |
| Increase (5 % / 50 RPM / 1 km/h / 50 RPM) | `Left Ctrl + Page Up` |
| Decrease | `Left Ctrl + Page Down` |
| Move HUD | `Right Ctrl + Numpad 0` |

Increase/decrease accept keys, buttons **or an analog axis**: with an axis, push further = changes faster, centre = hold.

> ⚠️ Bind the mode and on/off actions to **buttons**, not to an analog axis. An axis crossing its centre triggers them repeatedly.

---

## ⚙️ Settings (`modSettings/Etrigo_HandThrottle.xml`)
Created automatically on first start. Edit it with the game closed; missing or invalid values fall back to the default. Each player has their own.

```xml
<handThrottle>
    <hud x="0.985" y="0.30" textSize="0.013"/>
    <modes>
        <percent  enabled="true" brakeOff="false" step="5"/>
        <rpm      enabled="true" brakeOff="false" step="50"/>
        <rpmLimit enabled="true" brakeOff="false" step="50"/>
        <speed    enabled="true" brakeOff="true"  step="1" pedalOffDifference="5"/>
    </modes>
    <general rememberPerVehicle="true" keyRepeatDelay="400" keyRepeatInterval="100"/>
</handThrottle>
```

| Option | What it does |
|---|---|
| `enabled` | Turns the mode on/off (a disabled mode is skipped by the mode key) |
| `brakeOff` | Braking pauses that mode (instead of only suspending it while braking) |
| `step` | Increase/decrease step |
| `pedalOffDifference` | km/h above the target, with the pedal, that pause km/h mode |
| `textSize` | HUD text size |
| `rememberPerVehicle` | Per-tractor memory when leaving/stopping the engine |
| `keyRepeatDelay` / `keyRepeatInterval` | Held key: ms before repeating / ms between repeats |

---

## 🔧 Compatibility
- Works on every vehicle type with an engine that can be driven (base game, DLCs and mods), except locomotives.
- km/h mode in reverse needs the manual shuttle (the game's direction change setting); without it, km/h mode is forward only.
- **FS25_RPMResponsiveSpeeds** also changes RPM behaviour. Both can be loaded, but disable one of them if you want to test the other in isolation.
- No savegame data is written.

## 📦 Installation
Download `Etrigo_HandThrottle.zip` from the [Releases](../../releases) page and place it in your `Documents/My Games/FarmingSimulator2025/mods` folder. Don't unzip it.

## 📜 Changelog
See [CHANGELOG.md](CHANGELOG.md).

---
**Author:** Etrigo
