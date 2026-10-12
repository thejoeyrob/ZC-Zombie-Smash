# Zombie Smash

A portrait arcade shooter: Joey Rob against Dr Mantis and six more bosses, built as a plain HTML5 canvas game with no build step. It runs in a browser, installs as a web app, and is packaged for the iPhone with Capacitor.

## Where things live

| Path | What it is |
| --- | --- |
| `index.html`, `game.css` | Page shell and styling |
| `game.js` | Menus, input, story, saving, and the glue between everything |
| `engine.js` | Game rules: waves, enemies, bosses, weapons, scoring |
| `renderer.js` | Drawing the playfield on the canvas |
| `audio.js` | Music and sound effects (new synthesized set plus the original recorded set) |
| `haptics.js` | Phone vibration for gunfire, hits, damage and boss scenes |
| `scores.js` | Leaderboard client (guest only, no sign-in) and the name filter |
| `game-data.js`, `console-layout.js` | Boss, weapon, skin and layout data |
| `sw.js`, `manifest.webmanifest` | Offline support for the web version |
| `capacitor.config.json`, `scripts/`, `ios-assets/` | Packaging for the App Store |
| `art-pipeline/` | The brief, manifests and tools for the 30 boss scene clips and the 8 extra console skins |
| `scene-clips.json`, `skins-extra.json` | Lists of finished scene clips and extra skins (written by `scripts/sync-art.mjs`) |
| `.github/workflows/ios-testflight.yml` | Cloud build that signs the app and uploads it to TestFlight |
| `privacy.html`, `support.html` | Pages the App Store listing links to |
| `docs/` | The App Store guide and older build notes |

## Run it locally

```
python3 -m http.server 8000
```

Then open http://localhost:8000.

## Releasing a new web version

1. Change the code.
2. Raise the `?v=` number in `index.html` and `manifest.webmanifest`, and change the `CACHE` name at the top of `sw.js`, so players get the new files.
3. Update `VERSION.txt`.

## Releasing a new iPhone version

Follow `docs/APP-STORE-GUIDE.md`.

## Cheat mode (BOT_)

Type `BOT_` before a player name (for example `BOT_Joey`) to switch on cheat mode. `BOT_` is never shown in the name. It unlocks the secret console skins (marked `secret: true` in `game-data.js`) and adds a **Cheats** entry to the menu that lists every cheat code. Codes are entered during play using only the console controls: joystick pushed fully left or right, FIRE taps and grenade taps. Using any cheat makes the run practice-only, so it never reaches the leaderboard.

## Adding finished boss scene clips and console skins

The game has a hook for 30 finished boss scene clips and 8 extra console skins. Until the artwork exists the game uses its built-in scenes and the original 12 skins.

1. Put the finished files in the project folder:
   - Scene clips, H.264 MP4, 720 × 960, named `scene-<boss>-<scene>.mp4`. The boss is `jordan`, `glowinghumanity`, `debo`, `caffeinatedsloth`, `discoman`, `fatamy` or `drmantis`. The scene is `intro`, `form2`, `form3` (Fat Amy and Dr Mantis only), `bossdown` or `joeydown`.
   - Console skins, 900 × 1600 WebP, named `console-<id>.webp`, with the ids `joeyrob`, `jordan`, `glowinghumanity`, `debo`, `caffeinatedsloth`, `discoman`, `fatamy` and `drmantis`. Their colours and window numbers are already in `art-pipeline/CONSOLE-DESIGN-MANIFEST.json`.
2. Run `node scripts/sync-art.mjs`. The iOS workflow runs it automatically before every build.
3. A clip that is missing, or fails to play, falls back to the built-in scene. The `intro` clip covers both the "Joey reacts" and "boss reveal" panels. Each scene lasts as long as its clip.

`art-pipeline/validate_assets.py` checks the layered source artwork, and `art-pipeline/render_parallax_scene.py` renders the clips from it.
