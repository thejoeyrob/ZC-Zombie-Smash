# Changes made since your last upload

Baseline: commit `a826f4e` ("Add files via upload", 2026-10-04, JW E.D.S.) = Zombie Smash 7.5.0.
Current: version **7.9.0** (`VERSION.txt`, cache `zombie-smash-v7.9.0-retro-title`).
Everything below was made by Claude Code in `main` commits (list below). To see the exact diff:

    git diff a826f4e HEAD                 # everything
    git diff a826f4e HEAD -- engine.js    # one file

`changes-since-upload.patch` in this repo is the same diff for all text files (images and `SHA256SUMS.txt` excluded).

Files **not touched**: `audio.js`, `scores.js`, `legacy-board.json`, fonts, icons, console skins, boss and zombie art, music, sfx, `vercel.json`, `404.html`.
Release routine used each time (no build step exists): edit files, bump `?v=` in `index.html` and `manifest.webmanifest`, change the `CACHE` name in `sw.js`, add new files to `ASSETS` in `sw.js`, update `VERSION.txt`, regenerate `SHA256SUMS.txt`.

---

## Commits, oldest first

### 7.6 - `c0d295a` Fit the game to each skin, cheat, welcome picture
- **Per-skin screen fit.** The nine console skins have different screen windows, so each window was measured from the artwork and stored as `"win":[left,top,right,bottom]` (pixels in the 900x1600 art) on every entry of `SKINS` in `game-data.js`.
  `fitSkin(skin)` in `game.js` (called from `applySkin`) turns that into CSS variables on `<body>`: `--wx --wy --ww --wh` (window in the 375x667 cabinet), `--ss` (uniform scale of the 343x486 game screen), `--sx --sy` (its position), `--dy --sd` (control-deck top and scale), `--hh` (header height).
  A new `/* v7.6 */` block at the end of `game.css` uses them for `.screen`, `.overlay` (menus/welcome now sit exactly in the window), `#toast`, `.control-deck` (scale capped at .94), `.console-header` (inset 36px, clears the corner screws) and `.top-button`.
- **Cheat: 10 hearts (5 red + 5 gold).** `engine.js`: new `maxLives` (default 5), `setTenHearts(on)`, heart pickups and `skipBoss` respect `maxLives`. `game.js`: new checkbox in the admin "Bosses & Cheats" panel (`data-cheat="tenHearts"`); the HUD hearts are now `<span class="heart [gold] [empty]">` elements (two rows of five when 10). Practice-only like the other cheats.
- **Welcome/install picture.** New `game-banner.webp` (760x400 crop of `game-preview.webp`, rows 80-480, shows the sloth boss and horde) replaces `game-preview.webp` in `showStart()` and `install()`; `.start-art` is now a 1.9:1 `object-fit: cover` image. The comic-intro art/copy heights shrink with the window.
- Zombies 20% bigger and 16% slower (replaced in 7.6.2), spawn margin 30 -> 36.
- Added `.nojekyll` (README_FIRST said it was included; it was not), README_FIRST note, `game-banner.webp` added to `ASSETS`.

### 7.6.1 - `b2ba385` Joystick, Joey speed, speed pickup
- **Joystick** (`game.js`): measured from where the thumb lands (`stickOrigin`), full deflection at 28% of the pad width, dead zone .06, response curve `|v|^0.85`, touch area enlarged by a `#joystick:before` pseudo-element.
- **Joey's speed** (`engine.js`): `250` -> `212` px/s with smoothed acceleration (`p.vx`, factor `dt*16`); edge clamp 21 -> 28.
- **New pickup `speed`** (art already existed: `pickup-speed.webp`): +55% movement for 7s (`p.speedUp`), banner "SPEED UP", joystick glows (`#joystick.sped`). Drop table is now heart (when low) / grenade 48% / shield 14% / speed 14% / guns 24%.
- **Zombies start slower**: spawn speed is multiplied by `min(1, .85 + (wave-1)*.0375)` (full speed by wave 5), on top of the existing per-wave ramp.

### 7.6.2 - `91f1a6e` Bigger sprites
- Zombies: `height` x1.45, hitbox `r` x1.3, `speed` x.8 (applied once to the `ENEMIES` table in `engine.js`).
- Joey drawn 70x91 (was 54x70) in `renderer.js`, with matching shadow, shield ring, muzzle flash; zombie-contact radius `r+15` (was `+12`).
- Boss sprites drawn 20% larger (113/139 px tall, 130 wide); zombie health bar 40px wide.

### 7.6.3 - `a66e873` Gentler boss attacks (superseded by 7.7.0)
- First pass at reducing attack volume: longer gaps, fewer projectiles, ~28% slower boss shots, smaller projectile hitbox (`s.r*.75+8`, still in force), toxic zombie spit 100 -> 85 speed and every 5s.

### 7.7.0 - `9f7b6e1` Boss rework
All in `engine.js` (`bossMove`, `updateBoss`, `explodeBarrel`, `spawnBoss`, `ENEMIES`) plus small `renderer.js` changes.

**Movement (all bosses).** Bosses roam to random waypoints in x 52-291, y 80-152 (about a third of the way down), in every direction with smoothed velocity (`46 + 8*form` px/s). A guard keeps them at least `(player.y+28)/2` = 194 px from Joey (half the zombie walk, 388 px). Boss hitbox `r` 31 -> 36.

**Attacks.** Gap between attacks is 2.4-5.6 s. Aimed projectiles use speed `value*.72`; thrown handcuffs and donuts use fixed velocities.

| Boss | Form 1 | Form 2 | Form 3 |
|---|---|---|---|
| Jordan | 1 fire ember, every 2.6s | 3 embers (fan), every 3.2s | - |
| Disco Man | 2 bouncing disco balls, every 3.2s | 3 spinning cups of English tea, every 3.2s | - |
| Glowing Humanity | 2 neon glow sticks, every 3.0s | 2 spinning handcuffs thrown down and outward, bouncing off the side walls, every 3.6s | - |
| Debo | Chain with the D (unchanged, wind-up .8s), every 3.6s | Throws the spinning `prop-barrel` at Joey's line; the chain launches so it reaches full extension through the barrel at the moment it lands and the barrel explodes. Blast radius = 10% of screen width (34.3 px), hurts Joey; shooting the barrel early explodes it where it is, and if that is near Debo it damages him (9). Every 5.6s | - |
| Caffeinated Sloth | 1 coffee, every 2.4s | 3 coffees (fan), every 3.0s | - |
| Fat Amy | 1 missile at Joey, every 3.0s | single burger or donut (random) at Joey, every 2.4s | 2 donuts thrown down and outward bouncing off the sides, then she stops (1.3s), shakes with a red dashed aim line (1s), charges at Joey's position at 270 px/s, then retreats at 150 px/s; ~7s cycle |
| Dr Mantis | 1 severed arm (`bodypart`), every 3.0s | 2 venom (fan), every 2.8s | arm + 2 venom every 3.4s, plus mini Mantises (see below) |

All Fat Amy projectiles now share the same hitbox/draw size (`r` 11).
Mini Mantises: new enemy `mantismini` (art `boss-drmantis-stage3.webp`, 1 HP so any gun kills it in one shot, 150 points, ~44 px tall). During form 3 one spawns every 2.3-3.1 s (max 5 alive) from the top or the left/right edge and walks down like a normal zombie; they do not count toward the wave and are cleared when the boss dies.
New helper state on the boss object: `mode` (`idle/prep/shake/charge/retreat`), `chainIn`, `wp`, `miniIn`; thrown barrels live in `game.barrels` with `thrown:true, small:true`.

**New art** (drawn procedurally, exported as WebP): `weapon-tea.webp`, `weapon-glowstick.webp`; both added to the preload list in `renderer.js` and to `ASSETS` in `sw.js`. `weapon-missile.webp` is again used (Fat Amy form 1).
`renderer.js`: per-weapon spin speeds, thrown barrel rotates, boss shake offset, Fat Amy's dashed charge line.

### 7.8.0 - Floating joystick, deck position, fuller screen
- **Joystick** (`game.js`, `moveStick` and the pointer handlers): the whole pad (plus a 14px invisible margin) is the pick-up area. Wherever the thumb first touches becomes the centre, so pressing a side does nothing until the thumb is dragged. Full speed at a drag of 16% of the pad width (~14 px); dead zone 10% of that; response curve `|v|^0.8`. Past full deflection the centre follows the thumb, so reversing is quick. A quick flick (about 6 px within 150 ms) gives a 170 ms full-speed burst even if the thumb is lifted straight away. Uses coalesced pointer events. State: `stickOrigin`, `stickHist`, `flickDir`, `flickUntil`; `inputs()` applies the burst; `clearInput()` cancels it.
  Measured with simulated touches: press-only on either edge = 0 movement; flick right/left = about +-40..50 px; slow pull is proportional.
- **Deck position** (`game.css`, end of file): joystick `left 22 -> 28px, top 25 -> 19px`; fire button `right 21 -> 27px, top 25 -> 19px` (6 px up and 6 px towards the centre each).
- **Fuller screen** (`fit()` in `game.js`): the console scales uniformly (same proportions) to the largest size that fits; it previously also reserved the bottom safe-area inset (e.g. the iPhone home-indicator strip) and now only reserves the top inset, so it is larger on height-limited screens. On tall phones the console is width-limited and the leftover height is filled by the existing blurred skin backdrop, because stretching it would change the proportions.

### 7.8.1 - Full-screen fit under the status bar
- `fit()` in `game.js` now scales the console to the whole viewport (`min(w/375, h/667)`, same proportions, no reserved margins) and draws it under the translucent iPhone status bar (`apple-mobile-web-app-status-bar-style` was already `black-translucent`). A web page cannot hide the iOS status bar itself; this only stops wasting the space.
- If the status bar would cover the header buttons, the console is nudged down by up to ~11 px (bottom bezel edge is cropped by the same amount) and the header row is moved just below the bar (`--hs` CSS variable, `.sb-overlap` class, end of `game.css`); header buttons keep at least 26 px height. Verified at 375x667 (fills the screen exactly), 390x844 and 375x600.
- `manifest.webmanifest`: added `"display_override":["fullscreen","standalone"]` (Android installs can hide their status bar; iOS ignores it).

### 7.8.2 - No joystick slide, tougher bosses, single coloured glow sticks
- **No slide after release** (`engine.js` step, `game.js`): Joey's speed now equals the stick input immediately (the old smoothing `p.vx += (target-p.vx)*dt*16` is gone), so he stops the instant the thumb lifts; the flick burst only applies while the finger is still down (`stickId!==null`) and is cancelled on release. Measured: movement after release is just the 40 ms of sampling latency (about 7 px), none afterwards.
- **Boss difficulty**: boss health x1.4 (`spawnBoss`), aimed-shot speed factor `V` .72 -> .95, all attack gaps x0.88 (`if(b.attack<50)b.attack*=.88`), plus these per-boss changes. **Jordan**: ember speed 120 -> 150 (x`V`), gap 2.6s -> 1.7s (form 1) and 3.2s -> 2.3s (form 2). Others: Glowing form 2 gap 3.2s, Debo chain 3.3s / barrel 5.2s, Disco 2.9s, Sloth 2.1s/2.7s, Fat Amy 2.7s/2.1s, Mantis 2.7s/2.5s/3.1s (before the x0.88).
  Checked with a simulated player (flawless dodging, and a version with a 0.25 s reaction delay, pistol only, 5 runs per boss): every boss is beaten in 24-74 s with 0-1 hits, i.e. every pattern stays dodgeable and no boss is a wall; fights are about 40% longer than before. Real play will be harder than the bot.
- **Glowing Humanity form 1**: one glow stick per attack, colour different each time (never the same twice in a row) from green, pink, blue, orange, yellow, violet (`GLOW` in `engine.js`, `s.color`, drawn 1.6x). Gap 2 s. New sprites `weapon-glowstick-<colour>.webp` replace the old two-stick `weapon-glowstick.webp` (deleted); `renderer.js` preload list and `sw.js` `ASSETS` updated.

### 7.8.3 - Faster Debo chain
- Chain shots now carry their own timings (`wind`, `ext`, `hold`, `ret`; `updateShots` in `engine.js`, defaults .45/.3/.65). Debo's chain (both the form 1 attack and the form 2 barrel combo): wind-up .8 -> .55 s (barrel combo .6 -> .45 s), lunge .45 -> .26 s, hold .3 -> .2 s, retract .65 -> .4 s. Wind-up plus lunge is 0.8 s (was 1.25 s); the whole chain lasts 1.4 s (was 2.2 s). The barrel combo launch is now `T-.71` so the chain still reaches full length at the instant the barrel lands (checked: 0.00 s apart). Test bot still beats Debo (30-35 s, 0 hits).

### 7.8.4 - Faster barrel throw
- Debo form 2: barrel flight time `T` 2.3 -> 1.6 s (about 40% faster, ~160 px/s); the chain launch time follows (`T-.71`) so the chain still reaches full length at the moment the barrel lands (checked: 0.00 s apart). Test bot still beats Debo (30-34 s, 0 hits).

### 7.8.5 - Fewer special drops
- `engine.js` kill drops: a drop now happens on every 20th kill or a 2.2% chance (was every 12th or 4.5%), i.e. about 1 drop per 15 kills instead of 1 per 8.5. Drop mix when health is above 2 hearts: grenade 20% (was 48%), shield 18% (was 14%), speed-up 16% (was 14%), guns 46% (was 24%); the "heart when low on health" rule is unchanged. Measured over 1000 kills: grenade drops 55 -> 12 (about one per 83 kills instead of one per 18). Boss-down rewards (heart + DMR) unchanged.

### 7.8.6 - Muzzle flash, praying-mantis minis, control fixes
- **Muzzle flash** (`renderer.js`): the flash when Joey fires was the `prop-barrel.webp` picture (the `fx-muzzle.webp` listed in `art-bounds.json` was never in the repo). It is now drawn procedurally at the gun tip (radial glow plus three flame spikes, additive blend).
- **Mini Mantises** (`engine.js`): spawn every 1.2-1.9 s (was 2.3-3.1 s), up to 8 alive (was 5). (The drawn mantis sprite introduced here was removed in 7.8.7.)
- **Ghost "FIRE" text** on the fire button when holding it: iOS text magnifier/callout. Controls, screen and header now have `user-select:none; -webkit-touch-callout:none` and the context menu is blocked outside inputs (`game.css` end, `game.js`).
- **Hearts overlapping the weapon label**: hearts are now a compact flex row with no spaces (`game.js` `hud()`, `game.css`).

### 7.8.7 - Rendered mantis art for the minis
- The mini Mantises use the original rendered `boss-drmantis-stage3.webp` again (the flat drawn `zombie-mantismini.webp` from 7.8.6 was deleted, along with its `sw.js` entry), drawn larger (`height` 44, about 64 px on screen) so the detail reads. Spawn rate/cap from 7.8.6 kept (every 1.2-1.9 s, up to 8). Test bot still beats Dr Mantis.
- Note: `weapon-tea.webp` and `weapon-glowstick-*.webp` are still procedurally drawn (no image generator was available); replace them with rendered art of the same file names if wanted.

### 7.8.8 - Self-updating app, version label
- Cause investigated: a user screenshot showed an old layout (little arrows under the joystick, console not filling the screen) although every GitHub Pages deployment of 7.6-7.8.7 had succeeded; the phone was running a stale installed copy.
- `game.js`: the service worker is registered with `updateViaCache:'none'`, checks for a new release at start, whenever the app returns to the foreground, and every 10 min; when a new worker takes over, the page reloads itself as soon as no run is in progress (immediately at the menu/pause, otherwise on the next pause or when the app is backgrounded). Verified with a simulated release (page reloaded itself, old cache deleted).
- The start screen now ends with `NO LOGIN - ALL SKINS UNLOCKED - V<version>` (read from the `?v=` on `game.js`), so the running version is visible.
- `fit()`: on iOS home-screen apps that report a 0 top safe-area inset, assume 20 px so the header never sits under the status bar.

### 7.9.0 - Retro arcade title screen (current)
- `showStart()` in `game.js` now builds an arcade title screen instead of the banner picture: a pixel-art attract scene on a small canvas (150 px wide, scaled up with `image-rendering:pixelated`) of a red moon, city skyline and a perspective street where Joey auto-shoots zombies (the real `player-transparent` and zombie sprites drawn at low resolution, bullets, muzzle flash, pixel bursts, floating score pops; `titleScene()`); a slamming two-line logo (ZOMBIE green over SMASH red, extruded text-shadow, `slam` animation), typewriter "HOLD THE LINE", an arcade score row (`1UP <name>` / `HI <best score> <name>` from `scores.best`), a monospace framed name field, blinking "PRESS START", a CONTINUE button when a saved run exists, a scrolling ticker of the seven boss names, and the version line. CRT scanlines, vignette and a slight flicker are overlaid.
- Same ids and handlers as before (`#startForm`, `#username`, `#startButton`, `data-action="continue"`), so name validation, saved-run continue and the loading state work unchanged; the post-load text is now `PRESS START`. The scene stops itself when the title is dismissed, pauses while the tab is hidden and is static for reduced-motion users. CSS is a `/* 7.9.0 */` block at the end of `game.css`. No new image files.

---

## Current gameplay constants (for quick reference)
- World 343x412; Joey line y = 360; Joey speed 212 px/s; joystick full speed at 14 px drag (x1.55 with speed pickup for 7s); heart cap 5 (10 with cheat).
- Zombies: height x1.45, hitbox x1.3, speed x.8, spawn speed x`min(1,.85+(wave-1)*.0375)` then the old `1+min(.6,(wave-1)*.035)` ramp.
- Boss health x1.4; boss shots speed factor .95; boss gaps x0.88.
- Boss projectile hit test: distance < `r*.75 + 8` from Joey.
- Skin window fit: see `SKINS[].win` and `fitSkin()`.

## Not verified
Real-phone play (joystick feel, boss difficulty), GitHub Pages settings page (not readable from the tool used), and the admin cheat with the real admin code (tested with a mocked admin response).
