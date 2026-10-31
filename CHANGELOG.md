# Changelog

The versions before 1.3.0.0 were developed and tested locally before the repository existed. Their commits and tags were **reconstructed** from the development history: every change was replayed in order from the very first version, and the result matches the 1.3.0.0 files byte for byte. Only 1.3.0.0 and later have a downloadable release; 1.0.0.0 and 1.0.0.1 do not work in game (see below).

## 1.5.0.0 — 2026-10-31
- **Hand throttle or cruise control, never both** (like the cruise control and speed limiter of a car). New "system off" state (no HUD) where the cruise control works normally; with a mode on or paused, the cruise control is blocked: its keys are disabled and it is switched off if anything turns it on. Works with the game's cruise control and with Vehicle Inspector. The same buttons can now be bound to both.
- The mode key is the selector: system off → modes → system off. While paused it continues the cycle from the paused mode.
- On/off does nothing while the system is off (that button belongs to the cruise control).
- The RPM limit mode follows the same rule (it no longer runs together with the cruise control).
- **Increase/decrease merged into one action** that accepts keys, buttons and analog axes. The separate "lever" action is gone.
- Action names changed (`HT_*` → `ETHT_*`, to avoid clashing with another mod): **key bindings must be set again** (the defaults come back automatically).

## 1.4.0.0 — 2026-10-24
- New **km/h mode** for CVT / automatic gearboxes: keeps the current speed when switched on (1 km/h when standing still), 1 km/h per step, separate forward/reverse memory, the pedal wins and pauses the mode 5 km/h above the target, braking pauses it. Does not touch the game's cruise control speed.
- New **RPM limit mode** for every gearbox: full throttle allowed, but the engine never goes above the set RPM. Starts at the engine's maximum RPM.
- The mode key now depends on the gearbox: manual OFF → % → RPM → Limit → OFF, CVT/automatic OFF → km/h → Limit → OFF.
- **Settings file** `modSettings/Etrigo_HandThrottle.xml` (per player): enable/disable each mode, brake behaviour and step per mode, km/h pedal difference, HUD text size and position, per-tractor memory, key repeat timing.
- New optional **lever (analog axis)** action, unbound by default.
- Multiplayer state now includes the RPM limit and both speed memories.

## 1.3.0.0 — 2026-10-24 (first public release)
- Per-tractor memory: leaving a tractor or switching the engine off pauses the hand throttle and remembers its mode and value for that tractor. Press on/off to resume; it never resumes on its own.
- The paused state is synchronised in multiplayer (event and join stream).

## 1.2.0.0 — 2026-10-24
- New **on/off** action (`Right Ctrl + Numpad .`): pauses without losing the mode and value; the HUD shows `OFF` while paused.
- Smaller HUD text (0.016 → 0.013).
- "(inactive)" replaced by the shorter `OFF`.

## 1.1.0.0 — 2026-10-22
- **Move HUD** action (`Right Ctrl + Numpad 0`): drag the HUD with the mouse, right-click to reset, position saved in `modSettings/Etrigo_HandThrottle.xml`.

## 1.0.0.2 — 2026-10-22
- Fix: the specialization was registered with the wrong name, so it never reached any vehicle ("unknown specialization"). Now follows the standard FS25 mod pattern.

## 1.0.0.1 — 2026-10-22
- Failed attempt at the registration fix (not working).

## 1.0.0.0 — 2026-10-22
- First version: % and RPM modes, mode/increase/decrease actions, HUD, multiplayer event. Did not load in game because of the registration bug fixed in 1.0.0.2.
