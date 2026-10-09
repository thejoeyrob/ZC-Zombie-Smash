ZOMBIE SMASH 7.10 — HOLD THE LINE

FLAT PWA / DEPLOY
Extract this ZIP and upload ALL files together to your HTTPS website root.
Keep index.html, sw.js, scripts, artwork, fonts and audio beside each other.
No build command, npm install, login or database migration is needed.
For GitHub Pages, publish the branch root (.nojekyll included).
For Vercel: framework Other, no build command, output directory '.' (root).
This package is host-neutral. It does not change your domain configuration.

CURRENT REPOSITORY
https://github.com/thejoeyrob/ZC-Zombie-Smash
This build includes and enhances the 7.9.0 main revision 954f31a.
ZC2-Zombie-Smash and ZC2-SS are old deleted repositories.

INSTALL
On iPhone/iPad: open your hosted game in Safari, Share, Add to Home Screen.
On Android: browser menu, Install app / Add to Home screen.
Wait for Menu > Install Game to show offline readiness after the first load.
Do not open index.html directly as file://; a web host is required for the PWA.

UPDATES
The installed app checks for updates on start, foreground return and every ten
minutes. It switches to a fully downloaded release on pause/menu, so a live run
is not interrupted. Existing player names, local scores and saves are retained.

WHAT'S NEW IN 7.10
- One fixed console geometry across all 12 skins, based on the current correctly
  configured Toxic game screen and control sizes. Artwork adapts to the layout.
- Rustyard, Void Reactor and Warzone: three new free rendered skins.
- All skin sources 900x1600. Gallery selection preserves scroll and focus.
- More progressive zombie pressure, paired attacks and tougher late specials.
- Faster boss attacks, selected later-form follow-ups, existing weapons/forms.
- Bigger barrels. Debo's throw now 1.08 seconds, with synchronised D-chain strike
  and a fixed landing warning. Ground blast remains 20% of arena width.
- Transition cleanup and swept enemy projectile collision.
- Existing floating joystick/no slide, retro title, rare drops, speed pickup,
  rendered mini Mantises, ten-heart cheat and automatic updates all retained.

PLAY
Move left/right with the joystick. Hold FIRE. Tap the centre grenade button to
throw straight along Joey's current lane. No player auto aim.
Collect special guns, then tap their HUD slots to use one stored ammo run each.
Switching weapons preserves remaining ammo. All skins are unlocked, no login.
Type your username once; it is remembered until you change it.
Original leaderboard records and the existing server-checked admin code remain.
Admin cheats/boss jumps make a run practice-only and exclude its score.

DETAILS / VERIFICATION
CHANGES-SINCE-UPLOAD.md preserves the intentional improvement history.
BUILD-REPORT.md states what was checked and the browser/device testing limits.
ARTWORK-NOTES.md records the new skin prompts and output filenames.
SHA256SUMS.txt verifies all included files; the ZIP contains root files only.
