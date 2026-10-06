# Zombie Smash 7.6

Consolidates ZC2-Zombie-Smash main a038214 (7.3), the later 7.4 flat build,
and the refined 61-sprite transparent character pack. Adds a barrel sprite,
three original comic panels, five redesigned console skins and gameplay fixes.

## Verified

- 27 deterministic engine checks: horizontal controls, fire cooldown, swept
  collision, boosts, grenades without aim assist, rare pickups, stored ammo,
  barrel radius/chains/occlusion, save restoration, all ten enemies and all
  sixteen boss forms. Excess damage cannot skip phases.
- Five score-client checks: accepted/rejected/offline/practice runs and retry
  queue behavior. Permanent rejections cannot block later valid scores.
- Chromium browser: 320x568, 375x667, 390x844, 768x1024, 820x1180.
  Arena and console proportions stay identical. Landscape pauses with a gate.
- Real multitouch joystick + held fire, release behavior, grenade input,
  skin choices, admin-code flow, all sixteen boss selections, remembered
  username and save continuation. No browser exceptions or missing requests.
- All eight original live leaderboard name/score pairs remain present unchanged.
  This check was read-only; QA submits no scores to the live board.
- Audio decodes locally: stereo main (49.66s), boss (40.56s), disco (47.21s),
  entrance stinger (3.2s), gunfire and explosions.

Physical iPhone/iPad Safari and speakers have not been available for hands-on
validation. Automated phone/tablet checks use Chromium emulation. Portrait
orientation is requested by the manifest and enforced with an on-screen gate.

## Assets and offline release

The service worker is generated from the assets actually used by the renderer,
UI, nine skins and local audio. A content hash names each atomic cache release.
The final ZIP is flat, contains no development server/tests, and needs no build.
Source tests and reproducible packaging scripts remain in the repository.

Refined alpha sprites preserve full source figures. Display uses contain sizing;
transparent padding may be ignored for sizing, but visible pixels are retained.
Maps are backgrounds and cover the arena; character art is never cover-cropped.

## 7.6 size and pacing adjustment

Regular zombie height increases from 42 to 60 logical units (Joey remains 70).
Other classes scale to 58–98 units. Core hitboxes grow moderately rather than
using the entire silhouette; horizontal sprite margins prevent edge clipping.
Wave-one speed is 84% of its former base, with a 0.955s average spawn gap
instead of 0.816s and fewer runners. Speed rises by 0.035 per wave to a 1.6 cap;
spawn intervals shorten progressively to 0.44s. Health and points are unchanged.
Existing enemies in restored saves adopt the new scale and speed.

The full console/arena geometry is unchanged. Safari chrome naturally leaves
less available height than installed mode. Welcome artwork now uses complete
Joey/Mantis character images instead of fitting a tall gameplay screenshot into
a wide box. Autofill styling also preserves username field contrast.

Focused 7.6 browser checks cover welcome art, enlarged enemy rendering and
unchanged proportions at 320x568, 375x667, 390x844 and 768x1024. Broader boss,
multitouch and scoreboard checks above were completed for the inherited 7.5
release. Physical iOS validation remains a hands-on follow-up.
