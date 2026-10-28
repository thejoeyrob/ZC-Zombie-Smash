# Lessons learned building Zombie Smash (for the next app developer)

Zombie Smash is an HTML5 canvas game wrapped with Capacitor for iPhone and shipped through GitHub Actions to TestFlight. These notes come from about forty builds with a non-technical product owner on a phone, an AI coding assistant and an AI image generator. They are rules we earned, not theory.

## 1. Working with the product owner
- **Change only what was asked.** An "improvement" to the music engine nobody requested was rolled back within a build. If you see a better idea, ship it as an option or ask.
- **One suspect per build when chasing a fault.** Keep an A/B build of the last known good commit (`test-<version>` branch) so the owner can compare on the device in minutes.
- **Never say a device test passed unless it ran on a device.** Browser harnesses cannot decode H.264, cannot reproduce touch pressure or thermal throttling and do not show iOS audio rules. Say what was measured and what still needs a phone.
- **Number everything.** Version in `VERSION.txt`, `sw.js` cache name and the `?v=` query strings; the TestFlight build number is the workflow run number. Keep `appstore/REVIEW-NOTES.md` pointing at the real build after every trigger.
- **Short replies, concrete checks.** End each message with what the owner should look at on the phone.
- **Respect immutable geometry.** The 375 x 667 cabinet, the screen window and the control hit areas are fixed; skins only change art. Every skin change was checked by diffing control rectangles across all 24 skins against an older build (a 40-line Playwright script).
- **Secrets never go in chat.** Keys, issuer IDs and database strings live in GitHub secrets only.

## 2. Performance on an iPhone WebView
- Live-synthesised music and stinger bursts caused stop/start jitter in boss fights. Pre-render them to short files and play buffers.
- Write to the DOM only when a value changes (a tiny `hudSet(key, value, apply)` cache). Per-frame text, class and width writes restyled the console 60 times a second.
- Animate `opacity` and `transform` only. `box-shadow`, `filter` and `:has()` rules repaint or restyle large areas.
- Measure before keeping an optimisation. A generic per-sprite canvas cache looked clever and was slower (95 ms vs 58 ms a frame); it was removed.
- Cap the backing-store resolution and step it down automatically when frames run slow; keep simulation speed and logical size unchanged.
- Pause, hidden pages, game over, restart and skin switching must stop every timer and animation you add.

## 3. Audio
- iPhone silences Web Audio under the ring/silent switch unless the page requests a `playback` audio session; add a keep-alive `<audio>` for older iOS.
- Only the newest music request may start (a sequence token); otherwise two tracks play over each other after fast scene changes.
- Soften loop edges (a few milliseconds of fade) to remove wrap clicks; cap voices per sound; reserve a few voices for important cues.
- Sound design for non-harsh arcade effects: pulse/triangle voices, short noise, a low-pass near 5 kHz, gentle saturation, a small room, gun peaks about -6 dBFS, match loudness classes (LUFS) to the music.
- Generate effects with numpy/scipy and encode with ffmpeg; keep the generator out of the app bundle.

## 4. Art pipeline with an AI image generator
- Treat generated sprite sheets as untrusted: check each frame's size and centre. Reject sheets where frames differ in size between states or where a lamp is cut in half.
- Extract frames by connected components (drop specks under a minimum area), crop around a fitted centre, resize with Lanczos and pack one horizontal atlas per control. Switch states with `background-position` (no flicker, no extra requests).
- Size sprites in percentages of the control element, never pixels: the control deck is scaled by the cabinet.
- Re-fit a shell to the layout with a separable piecewise warp; protect round or text features by copying them from an unwarped copy (lamps, labels, logos). Widen repeating textures by repeating a block, not by stretching it.
- Etched or engraved labels belong in the artwork. Text glyphs such as arrows render as emoji on iOS.
- Keep dormant lamp sockets in the shell and overlay lit states independently.

## 5. Input and hit areas
- Make the visible control and the tap area agree. On the retro skin the element ignores touches and a `::before` shaped like the artwork takes them.
- Do not resize an element that other code measures. The joystick's travel is `width * 0.16` of its element, so only its overlay was resized.
- Always test taps at the drawn positions, including just outside them.

## 6. Interface patterns that worked
- A dot-matrix marquee (5x7 font on a small canvas) gives context for every screen at no layout cost; it draws only while it moves.
- Separate screens beat crowded ones: home (PRESS FIRE), player entry (locked name with CHANGE, NEW GAME, CONTINUE only if a run is saved).
- Counters read best as the object they count (ten zombie faces) with colour only as a bonus.
- Lamps: dormant, steady, blink and alert states driven by one pure function (`ZSConsole.leds`) that is unit-tested; reduced-motion gets steady equivalents.

## 7. App Store review
- Guideline 2.1 replies: a screen recording from a physical iPhone, what the app does, how to use it with no account, external services (Supabase, the web host), regional differences and protected material. Use the real build number and no placeholders or instructions in the text.
- Keep an in-app privacy policy and a support URL; list every network service and what is sent.
- Removing optional in-app purchases from the iPhone build removed a whole review surface.
- Listing screenshots must match the app: retake any shot whose screen has changed.
- Tests run before packaging (`npm test` in the TestFlight workflow) so a broken build never reaches Apple.
- Time-sensitive launches: submit early and use Apple's "Request an Expedited App Review" form only for genuine deadlines.

## 8. Hunting jank: what actually found it (7.56–7.57)
- Count what the page does per second before touching art: `setTimeout/rAF` counts, a `MutationObserver` over the document, `Storage` reads/writes, audio nodes created, and a CDP `Profiler` run. A per-frame function that rewrote the same attributes cost ~190 DOM mutations a second and made the browser re-style the whole game screen every frame; a one-line "already tidy" guard cut it to 6.
- Guard every per-frame DOM writer with "did anything change?". Setting an attribute to its current value still queues a mutation and can invalidate style.
- Ship sprites at the resolution the canvas can show (backing scale x ~1.25), not at the size the art was generated. Bosses and zombies were 6-10 source pixels per game unit for a canvas that shows 2; shrinking them cut decoded sprite memory from 118 MB to about 22 MB with no visible change (compare old/new screenshots at 3x).
- Give testers a hidden per-second frame log (fps, longest gap, script ms) so a phone recording can be matched with numbers.
