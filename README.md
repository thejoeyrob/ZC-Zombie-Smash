# Zombie Smash

A portrait arcade shooter: Joey Rob against Dr Mantis and six more bosses, built as a plain HTML5 canvas game with no build step. It runs in a browser, installs as a web app, and is packaged for the iPhone with Capacitor.

## Where things live

| Path | What it is |
| --- | --- |
| `index.html`, `game.css` | Page shell and styling |
| `game.js` | Menus, input, story, saving, and the glue between everything |
| `engine.js` | Game rules: waves, enemies, bosses, weapons, scoring |
| `renderer.js` | Drawing the playfield on the canvas |
| `audio.js` | Music and sound effects |
| `scores.js` | Leaderboard client (guest only, no sign-in) and the name filter |
| `game-data.js`, `console-layout.js` | Boss, weapon, skin and layout data |
| `sw.js`, `manifest.webmanifest` | Offline support for the web version |
| `capacitor.config.json`, `scripts/`, `ios-assets/` | Packaging for the App Store |
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
