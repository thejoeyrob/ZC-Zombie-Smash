ZOMBIE SMASH 7.6 — HOLD THE LINE

INSTALL / DEPLOY
Extract this ZIP and upload ALL files together to your HTTPS website root.
index.html, sw.js, scripts, artwork and audio must stay beside each other.
No build command, npm install, login, or additional database migration is needed.
Do not open index.html as file://: use an HTTPS host or a local HTTP server.
For GitHub Pages, publish the root of the chosen branch. .nojekyll is included.
For Vercel, use Other / no build command / output directory '.' (root).

On iPhone/iPad: open in Safari, Share, Add to Home Screen.
Let the first download finish. Menu > Install Game shows offline readiness.
For an existing installation, reopen the app after the new worker downloads.
The new release is cached atomically; it does not erase your player name or scores.

WHAT CHANGED IN 7.6
- Larger zombie sprites: regular 42 -> 60 units; other classes scaled to match.
- Body hitboxes enlarged fairly, and large enemies stay inside the arena sides.
- Wave 1 walking speed reduced 16%, spawns about 17% farther apart, fewer runners.
- Speed and spawn pressure increase gradually; enemy health is unchanged.
- Saved runs receive the new zombie scale and pace without resetting progress.
- Welcome/install panels feature large complete character art, not a tiny screenshot.

FEATURES RETAINED
- Standalone classic portrait game. No login or community screens.
- Fixed 375 x 667 console; 343 x 412 arena. Every element scales together.
- Longer playfield extends down; top/left/right gameplay positions stay fixed.
- Analogue joystick without arrow overlays. Hold fire and move simultaneously.
- Grenades travel straight along the lane where thrown. No player auto aim.
- 1–5 shootable barrels per wave, 20% arena-width blast radius, chain reactions.
- Rarer gun pickups. Tap SMG / SCAT / DMR / PULSE to use stored ammo.
- One magazine per special gun; switching preserves the ammo left in each.
- All ten zombie types used; toxic zombies spit visible slime projectiles.
- Seven bosses / sixteen forms. Powerful hits cannot skip a form.
- Real boss weapon sprites, including Debo's gold diamond D chain pendant.
- Full refined character sprites, readable comic dialogue and mutation reveals.
- Joey reacts on boss arrival and final third-form transformations.
- Three-panel comic intro: Mantis, brainwashed comrades, Joey's last stand.
- Player name remembered; returning players go straight from Play into the game.
- Nine unlocked console skins, including new Toxic, Splatter, Hazard, Electro, Circuit.
- Darker main and boss music from the later build, dedicated Disco Man music,
  transition stinger, individual gun and impact effects, separate mix controls.
- Existing leaderboard records and existing server-checked admin code retained.
- Admin menu can choose every boss form. Cheats/jumps make a run practice-only.

SCORING
Kills chained within seven seconds earn x2 at 10, x4 at 20, x10 at 30.
Damage or camp breaches break the chain. Saved offline games can be continued.
Offline runs without a server ticket remain on this device. Ticketed runs queue
for reconnection; a rejected score is never reported as an online success.

VERIFICATION
See BUILD-REPORT.md for tests and known platform limits.
All ZIP files are at root. SHA256SUMS.txt verifies every included file.
