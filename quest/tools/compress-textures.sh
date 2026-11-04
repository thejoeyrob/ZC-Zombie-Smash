#!/usr/bin/env bash
# Makes the big picture files GPU-compressed (ASTC on the Quest) instead of lossless, and gives them mipmaps. The headset downloads and loads
# roughly a fifth of the data and draws faster. Run after the first import has written the .import files; pass the art folder.
set -euo pipefail
cd "${1:-quest/assets/art}"
shopt -s nullglob
for f in pbr-*-c.jpg.import panel-*.import side-*.import marquee-*.import poster-*.import battle-*.import bezel-*.import ruin-*.import tex-*.import \
         wall-*.import playfield-*.import pin-*.import carpet.jpg.import floor90.jpg.import ceiling*.import bobble-*-atlas.jpg.import \
         boardgame*.import jukebox-front.png.import jukebox-side.png.import; do
  case "$f" in *normal*) continue;; esac
  sed -i 's/^compress\/mode=0/compress\/mode=2/' "$f"
done
echo "compressed: $(grep -l '^compress/mode=2' *.import | wc -l) pictures"
