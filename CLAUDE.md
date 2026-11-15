# Zombie Smash: rules for every Claude chat on this repo

Zombie Smash ships on three platforms. Read `docs/PLATFORMS.md` before you start: it says which chat owns what and where each platform stands.

## One game, three delivery layers

- **The game** (rules, bosses, waves, balance, art, story, scoring) exists once. It must never be copied or re-tuned per platform.
- **A platform** only delivers the game: the screen it draws on, the sound it plays, the controls that feed it, and the store listing around it.
- A game change is made in the shared game code and reaches every platform. A platform change stays in that platform's files.

## Who owns what

| Chat | Owns | Branch |
|---|---|---|
| Game core + iPhone | Shared game files, iOS wrapper, App Store | `main` |
| Android | `android/`, Play signing, Play workflow, Play listing | `android` |
| Meta Quest VR | `quest/` (Godot app), the arcade room, VR controls | `quest-build` |

## Rules

1. Only the **game core** chat changes shared game files (`engine.js`, `game-data.js`, `game.js`, `renderer.js`, `audio.js`, `scores.js`, art, music, sfx). Other chats ask for the change or mark it platform-only.
2. Platform chats bring in game updates by merging `main` into their own branch. They never push to `main`.
3. Platform-only behaviour goes behind a flag (for example the existing `nativeApp` check in `game.js`), never into shared code paths.
4. Each platform has its own build number. The game version (`VERSION.txt`) is shared. Never change the displayed version unless the task is a game release.
5. **Never touch an App Store build that is in review** (iOS build 142 at the time of writing), its workflow, or its listing files, unless the owner says so.
6. Secrets (signing keys, API keys, `.p8` files) live in GitHub secrets only, never in the repo or in chat.
7. Do not push to a branch you do not own, and do not open pull requests unless asked.
8. When you finish work, update the status table in `docs/PLATFORMS.md`.
