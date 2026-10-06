# Zombie Smash 7.10.0

Based on current `thejoeyrob/ZC-Zombie-Smash` main commit `954f31a` (7.9.0),
including the complete Claude improvement log. Older deleted repositories and
older flat packs were not used as the implementation baseline.

## What changed

Twelve skins share one immutable cabinet and the existing default Toxic screen
and control sizes. Artwork is adapted with CSS nine-slicing; the game never
changes geometry when a skin is selected. Three new rendered finishes:
Rustyard, Void Reactor, Warzone. Every source skin is 900×1600.

Zombies build pressure faster, with later paired attacks and tougher specials.
Bosses attack faster, selected later forms add follow-up volleys, and projectile
collision is swept. Barrels are larger; Debo's throw is 1.08 seconds with a
synchronised chain strike and a fixed landing warning. Stale thrown barrels and
follow-ups are cleared at transitions. Full details: CHANGES-SINCE-UPLOAD.md.

## Verified in this build

- 25 engine regression checks: existing sprite dimensions, immediate movement
  stop, introductory/progressive balance, spawn totals, barrel sizing/spacing/
  blast/counterplay, straight grenades, stored magazines, rare drops and speed,
  all seven bosses and 16 forms, phase gates, faster attacks, exact Debo timing,
  transition cleanup, roaming boundaries, Amy charge, rendered one-HP minis,
  saved health/progress, ten-heart practice, score boosts, follow-up cleanup,
  fast hostile collision, and unchanged legacy score/audio files.
- Six geometry/integration checks: all 12 skin slice maps occupy identical
  bounds, reference sizes preserved, all buttons/touch margins remain on deck,
  eight portrait viewport sizes preserve every relative length, skin selection
  cannot alter geometry, load order/portrait/update intent retained.
- Ten logical DOM flow checks using actual game.js/engine.js with network and
  canvas mocks: retro start, username/story/play, simultaneous joystick/fire,
  release, grenade, stored gun, all skin choices without scroll reset, admin
  gate and 16 choices, ten-heart boss jump, pause save and landscape gate.
- Production canvas renderer executed directly: 66 runtime images decode;
  arena, larger barrels, Debo combo, Mantis final form and all skin compositions
  rendered and visually inspected. No character artwork edits or cover crops.
- Five fixed-seed pistol-only simulations per boss compare 7.9 and 7.10 with
  250ms bot decisions. All 35 new-build runs can finish; this establishes basic
  solvability, not human difficulty or real-device control quality.
- Service-worker handlers tested with in-memory CacheStorage: atomic precache,
  activation/claim, old-game cache cleanup, unrelated-cache preservation,
  offline navigation/versioned modules, new skins, audio and legacy board.
- Every flat ZIP entry is verified against SHA-256; ZIP CRC validated. All
  referenced runtime assets are included. No development dependencies shipped.

## Verification limits

This environment did not provide the supported browser-preview capability.
No browser installation/server workaround was used. Logical DOM tests and
native canvas renders do not replace real Safari/Chromium layout, touch,
installed-PWA update or audio playback testing. Physical iPhone/iPad playtesting
remains necessary to judge the final difficulty and feel. No live leaderboard
writes or production database changes were made; admin responses were mocked.

## Reproduce

From the source repository root:
- `node tests/game.test.cjs`
- `node tests/layout.test.cjs`
- `node tests/ui.cjs` (requires linkedom; set ZS_LINKEDOM to its module path)
- `node tests/render.cjs` (requires @napi-rs/canvas in the primary runtime)
- `node tests/balance.cjs` (requires baseline git commit 954f31a)
- `node scripts/release.cjs`
- `node tests/offline.cjs`
- `python3 scripts/package-flat.py`

The app itself needs no build or dependencies. Source tests are excluded from
the flat PWA. Scores, player-name storage keys, saved-run keys, current admin
flow, existing music, domain configuration and portrait game mode are retained.
