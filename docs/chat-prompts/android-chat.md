# Prompt for the Android / Google Play chat

You are the Android / Google Play chat for Zombie Smash (repo thejoeyrob/ZC-Zombie-Smash). First read `CLAUDE.md`, `docs/OWNERS-GUIDE.md` and `docs/PLATFORMS.md`. Work on branch `android`, created from `main`. Never push to `main`. Do not edit shared game files (`engine.js`, `game.js`, `game-data.js`, `renderer.js`, `audio.js`, `scores.js`, art, music), the iOS workflow, `ios-assets/` or `appstore/`. Apple build 142 is in review. Ignore `quest/` and the `quest-build` branch (VR).

The game is a Capacitor-wrapped web app (`capacitor.config.json`, `scripts/build-www.mjs`, appId `com.thejoeyrob.zombiesmash`). It ships on iPhone already.

Goal: ship Zombie Smash to Google Play.
1. Add `@capacitor/android`, generate `android/`, and build from the same `www` output as iOS.
2. Hide the same web-only menu items as iOS (INSTALL, ADMIN) through the existing `nativeApp` check, using a platform flag, without changing shared behaviour for iOS.
3. Create an upload signing key and explain, step by step, how I store it as GitHub secrets (never in the repo or in chat). Keep it backed up.
4. Add a GitHub Actions workflow that builds a signed `.aab` (Android App Bundle) and uploads it as an artifact.
5. Guide me through Play Console: developer account, store listing, content rating, Data safety form, privacy policy (`https://zc2.quest/privacy`, confirm it is live), support email, and the closed-testing requirement for new personal accounts. Check Google's current rules rather than relying on memory.
Keep name, icon and version consistent with iOS. When a step needs me (accounts, payment, secrets), tell me exactly what to click. Finish by updating the Android row in `docs/PLATFORMS.md`.
