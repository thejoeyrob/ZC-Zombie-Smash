# 7.49.1 — combined smooth play and retro presentation

Cumulative update from chatgpt-pro-build d13f75e (7.47.1). Includes every code change from the unsubmitted 7.48.0 package. Do not apply the older package separately.

## Presentation
- Original developer logo now boots within the exact LCD bounds, leaving the console visible. Tap to skip; automatic exit after 2.9 seconds. Reduced-motion preference supported.
- New Retro Handheld default: plain neutral grey plastic shell, dark grey bezel and burgundy controls. Decorative seams, exposed screws and diagonal speaker stripes removed. Small vector asset uses the existing nine-slice layout; no new image decoding or runtime animation cost in play.
- Screen, HUD, arena, control deck and all touch target dimensions unchanged. New installs and previous Toxic Pop default switch once; other deliberately selected skins remain selected.
- Welcome screen uses a static arcade title, best score, labelled player name, Start, optional saved-run Continue and compact boss progress. Removed title ember loop activation and animated title effects from the welcome screen.
- Grenade tutorial no longer refers to a colour that depends on the skin.

## Included 7.48.0 work
See SMOOTH-PLAY-7.48.0.md for details: automatic rendering resolution, cached static scenery/disco decoration, prewarmed effect sprites, bounded overlapping effect audio, scheduled saves, reduced HUD work and a single curated sound/visual standard. Music/effects mix and haptics remain. Claude's recorded music/stingers and 7.47.1 save/cinematic fixes are retained.

## Validation and limits
- npm test: upgrade coverage and all five release test groups pass.
- npm run build:www: 190 assets packaged, including new SVG.
- Browser smoke: default selection, exact old/new control rectangles, simplified two-slider mix, recorded boss music, clearing effects on pause, adaptive resolution and Jordan simulation pass, no JavaScript errors.
- Welcome visually inspected at 375x667; fit checks also run at 320x568, 390x844 and 430x932.
- Physical-device frame pacing, iOS audio interruptions, safe areas and App Store submission still require TestFlight/device validation. Browser simulation is not a guarantee that the reported jitter is eliminated.
