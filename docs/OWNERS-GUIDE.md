# Owner's guide: how Zombie Smash is organised

Plain English. If you only read one file, read this one.

## The idea

There is **one game**. It is delivered to players in three ways:

| Where players get it | Who looks after it (which chat) | Git branch |
|---|---|---|
| **iPhone** (App Store) and the **website** (zc2.quest) | Chat 1: Game + iPhone | `main` |
| **Android** (Google Play) | Chat 2: Android | `android` |
| **Meta Quest** (VR arcade) | Chat 3: VR | `quest-build` |

Chat 1 is the only chat that changes how the game itself plays (bosses, balance, art, music). The other two only change how the game is *delivered* on their device: the screen, the sound, the controls, the store page.

## What lives where

- **Game files** (`engine.js`, `game.js`, `game-data.js`, `renderer.js`, `audio.js`, art, music): the shared game. Chat 1 only.
- **`ios-assets/`, `appstore/`, `.github/workflows/ios-testflight.yml`**: iPhone and App Store. Chat 1.
- **`android/`** (will be created): Android. Chat 2.
- **`quest/`**: the VR app. Chat 3.
- **`CLAUDE.md`**: the rules every chat reads automatically.
- **`docs/PLATFORMS.md`**: live status of each platform. Every chat updates it when it finishes work.

## Everyday jobs: which chat do I open?

| I want to... | Open |
|---|---|
| Change a boss, weapon, map, difficulty, music or art (all platforms get it) | Chat 1 |
| Fix an iPhone / App Store problem, answer Apple, ship an iPhone update | Chat 1 |
| Update the website, support page or email | Chat 1 |
| Get the game on Google Play or fix an Android-only problem | Chat 2 |
| Change the VR room, hands, controls or the Meta Store listing | Chat 3 |
| Bring a game update into Android or VR | Tell that chat: "merge the latest main" |

## When the game changes

1. Chat 1 makes the change and finishes it on `main`.
2. Chat 1 adds a line to `docs/PLATFORMS.md` ("game now at 7.63.0").
3. You tell Chat 2 and Chat 3: "merge the latest main". Each tests it on its own device and ships it when ready.

A platform-only problem (for example a button too small on Android) is fixed in that platform's chat and never touches the game files, so it cannot break the other two.

## Version numbers

- **Game version** (e.g. 7.62.4): one number for the game, shown on the menu. Only Chat 1 changes it.
- **Build numbers**: each store has its own (iPhone build 142, Android versionCode, Quest build). They go up whenever that store gets a new file.

## Safety rules

- iPhone build 142 is in App Review. Nothing in this repo that goes into the app (game files, `ios-assets/`, the iOS workflow) is changed until Apple finishes. Website and documentation changes are fine.
- Secrets (Apple keys, signing keys) are stored in GitHub Settings > Secrets only. Never paste them into a chat.
- `main` still holds an old copy of the game (7.22.7), which is why zc2.quest looks old. It is waiting for the owner's approval to be replaced by the real current game (7.62.4). Vercel keeps a rollback of the earlier deployment if anything looks wrong.

## Why one repository, not three

The iPhone and Android apps are built from the same files with the same tool (Capacitor), so splitting them would just mean copying files and forgetting to copy updates. VR is different (Godot app, big art files, its own signing key), so it may move to its own repository later, but only once the shared game is separated cleanly (see `docs/PLATFORMS.md`, "How to get there"). Moving it now would break its signing secrets and interrupt the VR chat mid-work.
