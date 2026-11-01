# Message for the existing VR (Meta Quest) chat

Read `CLAUDE.md`, `docs/OWNERS-GUIDE.md` and `docs/PLATFORMS.md` on `main`. You own `quest/` and the `quest-build` branch only. The phone game now lives on `main` at 7.62.4. Merge `main` into `quest-build` when you want the latest game changes, and do not edit shared game files; ask the game chat or the owner. Before changing any game rule in the Godot port, check whether it should be a shared-game change instead.

Open question for the owner and you: the Godot port duplicates the game rules (JavaScript on phone, GDScript in `quest/`). Propose which option in `docs/PLATFORMS.md` "How to get there", step 4, suits Quest performance (shared game in a web view on the cabinet screen, or a tested port with golden-run comparisons), and record the decision there. Also plan whether `quest/` should move to its own repo once that is settled (note the Quest signing key is in this repo's secrets).
