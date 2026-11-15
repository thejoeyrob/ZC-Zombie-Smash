# Message for the existing VR (Meta Quest) chat

The game is being separated into its own repository, `thejoeyrob/zombie-smash-game` (the "cartridge"), with the consoles in `thejoeyrob/zombie-smash-consoles`. Until those repositories are pushed, this message and the files it refers to exist only in the game chat's session; ask the owner for `docs/VR-INTEGRATION.md`.

What changes for you:
- `exports/vr/zs_data.json` and `golden.json` are now produced by the game repo from game 7.62.4 (the code behind iPhone build 142). `zs_data.json` is byte-identical to your `quest/data/zs_data.json`. Your `engine.js` and `game-data.js` are unchanged from 7.62.4.
- You can stop maintaining `quest/tools/export-data.mjs` and `quest/tools/golden.mjs`; take the exported files from the game repo instead and keep running `tests/trace.gd`.
- The cartridge's real `engine.js` has been run inside QuickJS (outside any browser) and matches the golden results. Please evaluate embedding it in Godot instead of maintaining `zs_engine.gd`: check a Godot 4 QuickJS GDExtension, Quest performance and build size. Report back; do not rip out the port until that is proven.
- Do not change shared game files. If the game needs a change, ask the owner so it is made in the game repo.
