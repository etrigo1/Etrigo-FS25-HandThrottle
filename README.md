[🇵🇹 Ler em Português](README.pt.md) | 🇺🇸 English

# 🚜 Hand Throttle (FS25_HandThrottle)
**Current Version:** 1.7.0.2  |  **Farming Simulator 25**  |  **Multiplayer:** supported

A real hand throttle for every tractor. With a manual gearbox, set the throttle or the RPM and just work the gears; with a CVT, set the speed like the drive lever of modern tractors; and with any gearbox, cap the engine's maximum RPM. It never works together with the cruise control, so both can share the same buttons, and with CVT Addon it drives its hand throttle with buttons.

---

## 🌟 Modes

The mode key only cycles through the modes that fit the tractor's gearbox (and are enabled in the settings):
- **Manual gearbox:** system off → % → RPM → Limit → system off
- **CVT / automatic gearbox:** system off → km/h → Limit → system off
- **CVT with [CVT Addon](https://github.com/SbSh-DNA-ModDing/FS25_CVT_Addon_Dev):** system off → % → km/h → Limit → system off

| Mode | Gearboxes | What it does |
|---|---|---|
| **%** | Manual (CVT with CVT Addon) | Fixes the **throttle position** (0–100 %), like the hand lever of an older tractor. In neutral the engine revs freely; in gear it is the same as pressing the pedal. Uphill, the RPM drops. On a CVT with CVT Addon it sets the **CVT Addon hand throttle** instead (see below). |
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

### Idle creep (manual with clutch)
With the game's gearbox setting **"manual with clutch"**, a gear engaged and the clutch released (or slipping), the tractor **creeps along at idle without throttle**, like a real tractor. The engine pulls with the torque it has at idle but never revs above idle (downhill it acts as engine brake). Releasing the clutch too fast under load can still stall the engine, as in the base game.
- Does nothing with the clutch pressed, in neutral, while shifting, braking, with the handbrake, with cruise control, with AI or with nobody driving.
- The strength builds up with the clutch travel: almost nothing when you just lift it, all of it with the clutch released (tune the curve with `clutchCurve`).
- With your foot on the throttle the higher of the two wins, like a tractor with a governor: press more than the creep and your foot takes over.
- The hand throttle wins: % above 0 and RPM mode work as before; with the RPM limit the lower of the two caps applies.
- On by default; switch it off with `<idleCreep enabled="false"/>` in the settings file. Switches itself off when **More Realistic** is loaded (it does the same).

### CVT Addon hand throttle with buttons
[CVT Addon](https://github.com/SbSh-DNA-ModDing/FS25_CVT_Addon_Dev) has its own hand throttle (more engine RPM, e.g. faster hydraulics on loaders and excavators), but only on an analog axis. With CVT Addon installed, the **%** mode is also available on CVT vehicles and drives that hand throttle with the increase/decrease buttons, so no throttle lever is needed.
- Pausing, switching the system off, stopping the engine or leaving the vehicle sets it back to 0.
- If you also use an analog lever on the CVT Addon axis, the last one moved wins. With the hand throttle off, this mod never touches the lever's value.
- Without CVT Addon nothing changes: in the base game the hydraulics do not depend on engine RPM.

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

## ⚙️ Settings (`modSettings/HandThrottle.xml`)
Created automatically on first start (an older `Etrigo_HandThrottle.xml` is picked up once). Edit it with the game closed; missing or invalid values fall back to the default. Each player has their own.

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
    <idleCreep enabled="true" torque="1" clutchCurve="1"/>
    <debug enabled="false"/>
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
| `idleCreep enabled` | Idle creep on/off (manual with clutch) |
| `idleCreep torque` | Idle creep strength, 0.1–1 (1 = all the torque the engine has at idle) |
| `idleCreep clutchCurve` | How the strength builds up as you release the clutch, 0.3–3. `1` = linear (half-way through the travel, half the strength); below 1 it bites earlier (e.g. `0.5`); above 1 it is softer at first and only pulls hard at the end (e.g. `2`) |
| `debug enabled` | Diagnostic log in the game's `log.txt` (lines starting with `[HandThrottle DEBUG]`), to help find problems. Leave it off for normal play. It can also be switched during the game with the console command `ethtDebug [on\|off]` |

---

## 🔧 Compatibility
- Works on every vehicle type with an engine that can be driven (base game, DLCs and mods), except locomotives.
- km/h mode in reverse needs the manual shuttle (the game's direction change setting); without it, km/h mode is forward only.
- **Vehicle Inspector**: its cruise control keys are blocked while the hand throttle is on or paused, like the game's cruise control.
- **CVT Addon**: the % mode controls its hand throttle on CVT vehicles (see above).
- **Advanced Damage System (ADS)**: with a clutch worn by ADS, idle creep slips instead of stalling; with a failed clutch it does nothing. ADS is in charge of the clutch (this mod only reads it).
- **FS25_RPMResponsiveSpeeds** also changes RPM behaviour. Both can be loaded, but disable one of them if you want to test the other in isolation.
- No savegame data is written.

## 📦 Installation
Download `FS25_HandThrottle.zip` from the [Releases](../../releases) page and place it in your `Documents/My Games/FarmingSimulator2025/mods` folder. Don't unzip it.

> Up to 1.7.0.1 the file was called `Etrigo_HandThrottle.zip`: delete it from the mods folder, so the game doesn't load the mod twice. Your settings are kept.

## 📜 Changelog
See [CHANGELOG.md](CHANGELOG.md).

---
**Author:** Etrigo
