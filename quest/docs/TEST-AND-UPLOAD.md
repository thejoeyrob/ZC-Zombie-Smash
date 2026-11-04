# Test on the Quest, then upload to the Meta dashboard

## 1. Install the newest build
Download: https://github.com/thejoeyrob/ZC-Zombie-Smash/releases/download/quest-latest/FattysGameShack-Quest.apk
Install over the old copy (same package name, same release key). The app name is Fatty's Game Shack.

## 2. What to check in the headset (about 10 minutes)
- Frame rate smooth in the middle of the room and at the back wall (two pinball machines, the Hall of Fame).
- Point at a machine and pull the trigger: PLAY word brightens, you step up to it.
- Zombie Smash machine (left wall, nearest the door): LEFT stick left/right to move, RIGHT stick push away to fire, pull toward you for a grenade. Debo's machine works the same way. The other machines have one stick: left/right moves, push away fires, pull toward you throws a grenade (buttons still work).
- JW EDS machine (right wall, middle): the four coloured buttons and START press; the stick moves the highlight; A opens a file.
- Two pinball machines play independently (flippers, plunger pulled back with your hand, RESET button).
- Bar stools: point at a stool and pull the trigger to sit; push the left stick to stand.
- Board game on the tall table: point at the table when it says ROLL.

## 3. Upload to Meta (Distribution -> Builds)
1. Choose the Alpha channel, upload the .apk above.
2. Add the age rating and privacy policy link if it asks.
3. Add yourself as a tester.

## Before a public store release
- Decide whether the JW EDS game menu stays in. Meta may not accept an app that loads players' own game files. It is one switch: set `ENABLED := false` at the top of `scripts/emu_launcher.gd`; the machine then shows a plain notice and never looks at any files.
- Keep real-game artwork out of the app (the retro machines have been removed for this reason).
