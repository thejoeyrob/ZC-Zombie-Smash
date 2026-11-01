# Game cartridges

Every arcade machine runs a **cartridge**: one game that follows a small, fixed interface (`scripts/cartridge.gd`).
The machine never talks to a game directly. This is what lets a machine offer a game list later, and what lets an
emulator mode be one more cartridge type.

## What a cartridge must do

| Method | Purpose |
| --- | --- |
| `build(host)` | Create the game's screen and anything it needs. |
| `screen_texture()` | The live picture shown on the monitor. |
| `attract_texture()` | The picture shown while nobody is playing. |
| `start()` / `stop()` / `pause(on)` | Run, end and pause the game. |
| `set_input(input)` | Joystick and buttons: `axis`, `stick`, `fire`, `alt`, `menu`. |
| `tick(delta)` | Advance the game. |
| `control_names()` | Labels for the controls, so another game can rename them. |

Signals: `sound`, `haptic`, `finished(result)`.

## Adding a game

1. Write a script that extends `Cartridge`.
2. Add one entry to `Cartridges.catalogue()` and one case to `Cartridges.create()` in `scripts/cartridges.gd`.
3. Nothing else changes.

## Where things stand

Zombie Smash is registered as the first cartridge. Its engine, screen and intro still run from `vr_main.gd`; the next step
moves them into `zs_cartridge.gd`. The emulator is listed as a disabled entry so the idea is on record.

## Rules for imported game files

The emulator mode will only ever load files the player brings from their own Quest. The app never ships, stores or shares
game files, and room sharing will only ever share our own cartridges.
