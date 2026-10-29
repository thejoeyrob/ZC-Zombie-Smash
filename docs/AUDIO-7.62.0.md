# Audio rebuild (7.62.0)

The whole sound system was replaced. Nothing is synthesised while you play any more.

## Why the old one misbehaved
Music was a live synthesiser driven by a JavaScript timer (it stuttered whenever the page was busy and could stop when the
timer was throttled), several code paths (recorded loops, live loops, stingers, hold timers, rebuilds) could each decide what
should be playing, and effects were decoded the first time they were used. There was no single source of truth.

## How it works now
* **Everything is pre-rendered** by `art-pipeline/audio/` (Python/numpy, 32 kHz) into WAV files in the repository root:
  `snd-*.wav` (41 effects), `mus-*.wav` (10 loops, 4 one-shots, the boot sequence). Re-render with
  `python3 art-pipeline/audio/render.py .` (about 30 s).
* **One engine** (`audio.js`): one `AudioContext`, effects decoded once at start-up, music decoded on demand with the next
  likely tracks prefetched and an LRU of six kept. Playing a sound is one buffer player: the cost of a sound is almost nothing.
* **One source of truth for music:** `wantTrack`. `playMusic()` records what is wanted; the engine plays it as soon as it can
  (after the engine wakes, after a sting finishes, after the power-on sequence). A watchdog every 2.5 s restarts missing music.
* **Reliability:** the context is resumed on every touch/key/focus/state change; a closed context is rebuilt; a plain
  `<audio>` fallback takes over if Web Audio refuses to run; problems are listed on the CHEATS page (BOT_ name) under AUDIO.
* **Sync:** effects start on the next audio block in the same event that fires the haptic buzz. The power-on sound is started
  at the animation's own elapsed time (`Animation.currentTime`), so it lines up with the lamp, the CRT flash and the logo
  even if decoding finishes late.
* **Fades everywhere music ends:** cross-fades between tracks (0.6-1.1 s), 0.25 s before a sting, 0.35 s if the power-on is
  skipped, and a short muffled dip (battle music only) while a menu is open over the game.

## Which sound plays where
| Moment | Sound |
| --- | --- |
| Power-on | `mus-boot` (hum, lamp relay ticks, CRT zip and thump, logo swell, four soft chimes timed to the colour blocks) |
| Home Screen, player entry | `mus-home` |
| Opening story | `mus-story` |
| Waves 1-3 / 4-8 / 9+ | `mus-wave1` / `wave2` / `wave3` |
| Boss arrival comic | `mus-warning` + `snd-alarm` |
| Boss fight | `mus-boss` (Disco Man `mus-disco`, Dr Mantis `mus-finale`) + `snd-doom` |
| Boss down / Joey down | `mus-victory` / `mus-defeat`, then the music resumes or the results tune `mus-over` |
| New wave | `mus-wavestart` over the music |

Effects: pistol, smg, shotgun, dmr, burst and one per special weapon; hit, kill, boss hit, ricochet, arena target, throw,
explosion, hurt, breach, pickup, heart, gold heart, three kill-chain boosts, power-up, weapon switch, wave clear, comic page,
boss mutation, boss attack warning, and the menu sounds (click, chime, back, toggle).

## Joystick topper
`art-pipeline/make-stick-toppers.py` recolours the ball in `retro-stick.png` (5 colours, 6 funky designs). The choice is stored
as `zs7-topper`; CSS selects the matching atlas with `body[data-topper]`.
