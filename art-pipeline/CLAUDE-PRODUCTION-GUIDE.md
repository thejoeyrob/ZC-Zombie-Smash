# Zombie Smash — Original Artwork Production Contract

**Status: preparation / production specification. NOT a finished artwork or media pack.**

This is a 30-scene original illustration order and a production pipeline for Claude. The previous composited reveal assets and AI montage sheets were **not** accepted as final character art. Do not substitute the montage for original full-resolution illustrations.

## Exact production scope

- Seven bosses in the original order: Jordan (wave 2); Glowing Humanity (4); Debo (6); Caffeinated Sloth (8); Disco Man (10); Fat Amy (12); Dr Mantis (14)
- Each boss: intro/reveal, form 2 mutation, boss down, Joey down
- Additional form 3 mutation only for Fat Amy and Dr Mantis
- Total: **7 × 4 + 2 = 30 animated scenes**
- Eight console skins: JoeyRob plus seven bosses, **not gameplay character costumes**

## New artwork mandatory

Paint original scenes at full scene resolution. Use the supplied PDF solely to verify each character's identity, costume, weapons, form progression and IN GAME dialogue. **Do not cut, scale, trace, reuse, recolour or paste character assets from the PDF or other examples as final output.** Every new illustration requires visual approval before release.

## Layer contract for EVERY scene

```
art/<boss-id>/<scene-id-suffix>/
  background.webp       # fully opaque, bleed past screen edges
  midground.png         # new art: the correct boss + form, RGBA, opaque within silhouette
  foreground.png        # new art: Joey Rob as near-camera observer, RGBA, opaque within silhouette
```

Layer order: BG -> boss -> Joey -> comic speech bubbles. Illustration must depict a unified situational environment as in the attached perspective example; not side-by-side standing character cards. Preserve distinct depth planes; nothing semi-transparent inside solid people or objects. Avoid oversized foreground props blocking the boss or text.

Animate a subtle continuous horizontal slide in **ONE direction**: background 28 px, boss 48 px, Joey 75 px (over the scene duration). No sinusoidal easing, reversing, zooming, or looping snap. Ensure source art has enough overscan to prevent blank edge reveals. The script must not use 2D layer opacity tricks to simulate depth.

## Dimensions and compatibility

- Animated story plate: **720 × 960** to match previously approved story movies; fit/cover into the game panel with a configurable safe crop.
- Original brief's scene plate reference was **686 × 900**. The actual console skin's window is **748 × 1059 pixels** within the 900 × 1600 skin. These have **different aspect ratios**. Claude must validate how the current game fits its scene overlay rather than assuming 1:1 dimension correspondence.
- Console skin: **900 × 1600 WebP**, flat window exactly x76–824, y102–1161; do not paint a joystick, FIRE button, grenade button, title wordmark or GAME SCREEN overlay. Game renders UI.
- Control sockets: joystick (198,1371), diameter217; fire (704,1371), diameter217; grenade (450,1303), diameter106; menu centered (450,1455), 167×72. Keep at least 14px clear socket margin.
- Use one `console-<id>.webp` per boss plus `console-joeyrob.webp`, with `accent`, `fire`, `grenade`, `stick`, `bleed`, `win` settings.

## Character-identity traps to catch in QA

- Jordan is an axe-bearing firefighter wearing a red helmet and reflective turnout coat, **not** a generic zombie.
- Glowing Humanity has rainbow dreadlocks, peace tie-dye and neon slime, **not** a golden skeleton.
- Debo has a backwards cap, gold chain and white tee beneath black jacket, **not** a masked barrel-wielding soldier.
- Caffeinated Sloth is an **animal sloth on all fours**, not a humanoid with a coffee cup.
- Disco Man is an older silver-haired man in a purple sequinned flared suit; **not** an afro-haired zombie.
- Fat Amy has three exact stages: ponytailed soldier -> claw-arm mutant -> bigger final mutation.
- Dr Mantis has three exact stages: regal human with staff -> mantis hybrid with wings -> full giant mantis. **Not** an undead hooded skeleton.
- Joey Rob is the same UK soldier in every scene: olive combat kit, green helmet and headset, tan chest rig, gloves, kneepads, and rifle.

## Text and animation

Dialogue from the **IN GAME** lines is set in `CUTSCENE-MANIFEST.json`. Do not replace it with speculative new jokes. Speech balloons must point to correct speaker, avoid faces, have dark outlines, and use legible typewriter font. Render captions separately from painted scene art to allow editing and localisation. Every subtitle must be fully visible and remain inside the safe rectangle. Include CONTINUE/skip support using the game's existing UI, not baked artwork.

## Packaging / acceptance criteria

Group scene outputs by boss into seven ZIP files and distribute eight console frames in one ZIP. Keep each compressed ZIP under 10 MB. Prefer H.264 high-quality MP4 over GIF for iPhone PWA/App Store. Do not include old test frames, composites or redundant intermediate renders. Confirm all assets are correctly named, contain the expected characters, have no transparency-through-body defects, play for declared duration, and do not alter current scoring, controls, phase triggers or game geometry.

Use `validate_assets.py` to check missing original art before claiming readiness. A passing file-count test alone is not proof of visual quality.
