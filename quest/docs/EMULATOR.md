# Emulator and game files on the JW EDS machine

## How it works
- **Game files**: the player puts their own files on the headset. Two ways:
  1. **Over Wi-Fi (no cable)**: at the JW EDS machine press **C**. The screen shows an address and a 4-digit PIN. Open the address in a browser on a phone or computer on the same Wi-Fi, type the PIN, drop the files on the page. Files are saved in the app's own folder. Only machines on the same private network can connect, every change needs the PIN, only game file types are accepted, and it switches off when you leave the screen (`scripts/rom_server.gd`, tested by `tests/rom_server_test.gd`).
  2. **By cable**: copy to `Android/data/com.thejoeyrob.fattysgameshack/files/roms`.
- **Running games**: `native/retro` is a small libretro front end (a Godot GDExtension, `RetroCore`). It loads an open-source emulator core, runs the game, and hands the picture, sound and save data to `scripts/emu_session.gd`. Saves go to `user://saves`. The pause menu (MENU button) has resume, reset, select, save state, load state, exit.
- **Controls**: stick = D-pad, A/B/C/D = the four face buttons (A = B, B = A, C = Y, D = X on a pad), START = start. On Super NES, hold START and press A or B for the L and R shoulder buttons.

## Cores (all built from source in CI at pinned commits, `native/build-cores.sh`)
| System | Core | Licence |
|---|---|---|
| NES | fceumm | GPL v2 |
| Super NES | snes9x2010 | Snes9x licence (non-commercial) |
| Mega Drive / Master System / Game Gear | Genesis Plus GX | Non-commercial licence |
| Game Boy / Game Boy Color | gambatte | GPL v2 |

## Two versions of the app
- `FattysGameShack-Quest.apk`: the **store-safe** build. The game-file menu is switched off (`ENABLED := false` in `emu_launcher.gd`) and no cores are included. Use this for Meta uploads.
- `FattysGameShack-Quest-Emulator.apk`: the **sideload** build with the plug-in and cores. Do not upload it to the store: the cores' licences (GPL, non-commercial) and Meta's content rules for apps that load game files make it unsuitable for a commercial store release.

## Not included, on purpose
No game files, BIOS files or console firmware are in the app. Only play files you have the right to use (your own dumps, homebrew, public-domain games).
