# Test on the Quest, then upload to the Meta dashboard

## 1. Install the newest build
Download: https://github.com/thejoeyrob/ZC-Zombie-Smash/releases/download/quest-latest/FattysGameShack-Quest.apk
Install over the old copy (same package name, same release key). The app name is Fatty's Game Shack.

## 2. What to check in the headset (about 10 minutes)
- Frame rate smooth in the middle of the room and at the back wall (two pinball machines, the Hall of Fame).
- Point at a machine and pull the trigger: PLAY word brightens, you step up to it.
- Zombie Smash machine (left wall, nearest the door): LEFT stick left/right to move, RIGHT stick push away to fire, pull toward you for a grenade. Debo's machine works the same way. The other machines have one stick that only goes left and right; fire and grenade are the buttons. Your hand stays on the stick until you open your fingers.
- JW EDS machine (right wall, middle): the four coloured buttons and START press; the stick moves the highlight; A opens a file.
- Two pinball machines play independently. Grip the sides beside the flipper buttons: your hands stay there, and the trigger flips. Pull the plunger back with your hand; RESET button.
- Bar stools: point at a stool and pull the trigger to sit. You take over that stool's piece mid-game (green, red, amber, purple). Push the left stick to stand; the computer carries on with your piece. Sit again and you get your old piece back if that stool is free.
- Board game on the tall table: point at the table when it says ROLL.

## 3. Upload to Meta (Distribution -> Builds)
1. Choose the Alpha channel, upload the .apk above. Only builds from 94 onwards: they are signed with the release key, are not debuggable,
   and target Android 14 (API 34), which Meta requires for apps created after 1 March 2026. "App is debuggable" means an older test build was uploaded.
2. Add the age rating and privacy policy link if it asks.
3. Add yourself as a tester.

## Before a public store release
- Decide whether the JW EDS game menu stays in. Meta may not accept an app that loads players' own game files. It is one switch: set `ENABLED := false` at the top of `scripts/emu_launcher.gd`; the machine then shows a plain notice and never looks at any files.
- Keep real-game artwork out of the app (the retro machines have been removed for this reason).
