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
| Game Boy Advance | gpSP | GPL v2 |
| PC Engine / TurboGrafx-16 | Beetle PCE Fast | GPL v2 |
| Atari 2600 | stella2014 | GPL v2 |
| Atari 7800 | ProSystem | GPL v2 |
| Atari Lynx | Handy | zlib-style licence |

## One app, emulators inside
The owner decided (November 2026) to put the emulators in the same app that goes to the Meta store and deal with it if a review flags them.
- `FattysGameShack-Quest.apk` (what the Upload to Meta workflow sends): the game with the emulator plug-in and every core that built. If the emulator step fails in CI the app is still built, with the game-file menu switched off.
- `FattysGameShack-Quest-NoEmulator.apk`: the same game with no emulator at all (`ENABLED := false`, no plug-in, no cores). It is built every time and kept ready: if a store review objects to the emulators, upload this one instead. **The cores' licences (GPL, non-commercial) and Meta's content rules for apps that load game files are the risk to know about.**

## Playing the host's games in a room (remote play)
Players put their own game files on their own headset. In a room the **host** can let guests play the host's collection, like "remote play together":
- The host's headset runs the game. The picture (JPEG, about 30 a second) and the sound (22 kHz, one byte a sample) are streamed to that one guest through the room server; the guest sends back only their buttons.
- **Game files never leave the host's headset.** Guests receive a picture and sound, keep nothing, and can only play while they are in the host's room. The server relays the host's game list (names only).
- The host's list is published when the host has a room; the host can turn it off (FRIENDS page: GUESTS CAN PLAY MY GAMES). At most two guest games run at once.
- A guest sees the host's games in the JW EDS machine's menu, marked with an @, and opens them like their own (`scripts/social/remote_play.gd`, `remote_guest_session.gd`; server side in `server/server.mjs`; tests `tests/upgrade/remote_play_test.gd` and `server/tests/remote_play.test.mjs`).

## Not included, on purpose
No game files, BIOS files or console firmware are in the app. Only play files you have the right to use (your own dumps, homebrew, public-domain games).
