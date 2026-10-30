#!/usr/bin/env bash
# Copies the game art, sounds and font from the repository root into quest/assets (generated, not committed).
set -euo pipefail
cd "$(dirname "$0")/../.."
Q=quest/assets
rm -rf "$Q"; mkdir -p "$Q/art" "$Q/audio" "$Q/fonts"
node quest/tools/export-data.mjs >/dev/null
# art: everything the screen draws
for f in arena-*.webp zombie-*.webp boss-*.webp player-*.webp bullet-*.webp pickup-*.webp weapon-*.webp prop-barrel.webp \
         title-bg.webp game-banner.webp joey-reaction-close.webp story-army.webp map-concrete.jpg; do
  [ -f "$f" ] && cp "$f" "$Q/art/"
done
cp art-bounds.json "$Q/art/art-bounds.json"
# sound: the pre-rendered effects and music
cp snd-*.wav mus-*.wav "$Q/audio/"
cp font-barlow-condensed-900.woff2 font-barlow-condensed-700.woff2 "$Q/fonts/"
echo "assets: $(ls "$Q/art" | wc -l) art files, $(ls "$Q/audio" | wc -l) audio files"
