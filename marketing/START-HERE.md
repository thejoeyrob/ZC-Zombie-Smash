# Zombie Smash — launch pack

**Big personality. Simple fun.**

A launch kit built around the actual game: Joey Rob holding the line, seven eccentric bosses, retro handheld styling and one-more-go play. The revised icon follows the darker comic-book references: a snarling infected soldier, toxic-green eyes and a strong close-up silhouette. The rejected smiling icon is not included.

## Contents

| Folder | Use |
|---|---|
| 01-Video | Finished 27-second portrait social promo with music; 24-second App Preview reference edit; poster frames; Arcade audio mix preview |
| 02-App-Store-Copy | Name, subtitle, promotional text, keywords, description, press blurb and social captions; separate paste-ready text files |
| 03-Store-Screenshots | Five promotional screenshots, each in 1179×2556 and 1290×2796 sizes |
| 04-New-Icon | Opaque square 1024px primary icon and smaller web icon exports |
| 05-New-Console-Skins | Toxic Pop, Disco Fever and Pocket Arcade; 900×1600 PNG masters, WebP game textures, definitions and in-game preview |
| 06-Social-Art | Portrait launch poster and square promotional image |
| 07-Install-and-Source | Asset installer, generation prompts, production notes and validation evidence |
| 08-Game-Quality-Update | Tested 7.23.0 source update with a guarded installer |

## Install the complete quality update

Folder **08-Game-Quality-Update** contains the tested 7.23.0 update: audio, scene playback, console presentation, safe-area layout, revised icon and three new skins. It contains changed files, not another copy of the whole repository.

Extract this pack beside your game repository in Codespaces. Preview the changes:

```bash
node Zombie-Smash-Launch-Pack/08-Game-Quality-Update/apply-update.mjs /path/to/game
```

Install them:

```bash
node Zombie-Smash-Launch-Pack/08-Game-Quality-Update/apply-update.mjs /path/to/game --apply
cd /path/to/game
node scripts/sync-art.mjs
node scripts/build-www.mjs
```

The installer checks file hashes before changing anything, backs up replaced files and refuses to overwrite conflicting newer edits. If it reports a conflict, use the supplied source files to merge the listed changes into that newer revision. Re-running after a successful install changes nothing.

Rebuild your iOS app using the repository's normal TestFlight workflow. Check the installed icon, audio, touch controls and boss scenes on your iPhone before release. The 1024px icon is square and opaque; iOS supplies the corner mask. Nothing is committed, pushed or uploaded by this installer.

Existing sound preferences are preserved. Choose **Menu → Music & Sound → ARCADE** to hear the new combination; fresh installs select it by default.

The older `07-Install-and-Source/apply-release-assets.mjs` is an optional art-only installer. Use the folder 08 installer above for the complete update.

## Use the marketing material

The social promo ends with “Coming to iPhone”, so it is suitable for pre-release promotion. The copy folder also contains a launch-day post: add your actual App Store link before posting it.

The store artwork uses real locally rendered gameplay, with captions outside the game. Choose one screenshot-size set, in numerical order. Check that the screenshots match your final TestFlight build before uploading.

**The App Preview video is an edit reference, not a submission-ready device recording.** Its footage was captured from the real web game engine in a desktop browser. Apple asks for footage captured on device. Record the same scenes on an iPhone running the final build and replace the reference footage before submitting an App Preview. The social promo can be used separately from the App Store preview.

The description and metadata are ready to paste, subject to your final feature check. Your actual support URL, privacy URL, pricing, age-rating questionnaire and privacy disclosures still need to be completed in App Store Connect. No price, release date or age rating has been invented here.

## What was changed remotely?

Nothing was uploaded or pushed to GitHub. Installation and build verification were performed in a local checkout of the linked repository. This ZIP contains the assets and installer for your review and use.
