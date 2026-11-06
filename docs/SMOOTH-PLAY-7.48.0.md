# Zombie Smash 7.48.0

Based on chatgpt-pro-build commit d13f75e4e66977b6709e384ec430cc4e86ef8e33 (7.47.1). Preserves Claude's pre-rendered boss/disco music and all earlier save and weapon-timer fixes.

Changes:
- One curated arcade soundtrack and original artwork colours. Removed sound-style and Standard/Vivid/Extra choices. Music/effects volume, haptics, mix preview and audio reset remain. Console skin collection remains.
- Default playfield backing resolution capped at 2x instead of 3x. Sustained slow frames automatically reduce it in small steps, with delayed recovery. Logical dimensions, enemy counts, collision rules and simulation speed stay unchanged.
- Prepares hit/rim variants in small batches before play. Caches only static scenery and the decorative dance-floor layer; does not copy all plain sprites into canvases. Reduces decorative particle drawing under pressure.
- Limits rendering of static menus/cinematics, avoids redundant 120 Hz draws of 60 Hz simulation poses, and queues routine autosaves outside the animation callback. Pause/pagehide saves remain immediate.
- Reserves sound-effect capacity for warnings, damage, pickups and explosions; bounds fallback audio and releases effect/synth nodes. Pausing clears active effects so old gunfire cannot spill into resumed play.
- Adds a subtle danger border and a trailing boss-health damage indicator using simple drawing primitives.
- Corrects the upstream VERSION.txt mismatch (7.47.0 versus cache/scripts 7.47.1). New version and cache are 7.48.0.

Validation:
- Existing gameplay and release tests pass; syntax and whitespace checks pass.
- iOS web package builds: 189 assets, 69.8 MiB; no new image or audio assets.
- Chromium smoke test: simplified controls, recorded Jordan music (no boss sequencer), pause cleanup, automatic resolution reduction and Jordan simulation passed; zero page errors.
- Software-browser stress rendering tested Jordan, Disco and Mantis maps with 13 enemies, boss, 30 bullets, 18 projectiles and 120 sparks. Updated draw/readback median was approximately 53/97/59 ms versus baseline 227/295/297 ms on this host. Samples and software rasterization are diagnostic, not a device FPS measurement or performance guarantee.
- Physical iPhone/TestFlight testing remains necessary, particularly Jordan while moving and firing, interruptions, music transitions and long busy waves.

No GitHub push, TestFlight upload or App Store submission was performed. Apply against 7.47.1; if the branch has advanced, merge carefully rather than overwriting newer changes.
