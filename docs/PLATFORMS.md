# Platforms: status and plan

Last updated 2026-11-01 (game core chat).

## Status

| Platform | Chat / branch | Game version | Build | State |
|---|---|---|---|---|
| Web (zc2.quest, Vercel project `zc2`) | game core / `main` | **7.22.7 live (stale)**; 7.62.4 exists but is not on `main` yet | n/a | Needs `main` brought up to 7.62.4 (see Open items 1) |
| iPhone (App Store) | game core / built from `quest-build` at `6cd17bc` | 7.62.4 | 142 | In App Review since resubmission; do not touch |
| Android (Google Play) | android / `android` | n/a | n/a | Not started |
| Meta Quest (VR arcade) | VR chat / `quest-build` | Godot port of the engine | own build numbers | In development |

## What was found on 2026-11-01

- The shipped iPhone game (7.23 to 7.62.4, builds 104 to 142) was developed on `quest-build`. `main` stopped at 7.22.7. That is why zc2.quest shows an old build: Vercel production deploys `main`.
- `quest-build` is `main` plus 161 commits: the phone game updates, App Store listing workflows (`appstore/`, `Deliverfile`) and then the VR app (`quest/`, Godot 4, workflow `quest-build.yml`).
- The Quest app is **not** the web game inside a headset. It is a Godot project with the engine **ported by hand** ("tick-for-tick", commit `c78f2df`). Game rules therefore exist twice (JavaScript in the phone game, GDScript in `quest/`). That is the reason the VR version does not play quite the same.
- The Vercel project `zc2` also builds `quest-build` as previews. They do not affect production.

## Target design

One game, many delivery layers.

```
shared game core (rules, data, waves, bosses, scoring)   <- written once
        |
        |  small interface: draw a frame, play a sound, read controls
        |
  +-----+------------------+---------------------+
  | Phone (web/iOS/Android) |     Meta Quest      |
  | canvas, touch controls  | arcade room, screen |
  | Capacitor shells        | on the cabinet,     |
  |                         | hand/controller in  |
  +-------------------------+---------------------+
```

- A platform supplies: the **screen** the game draws onto, the **sound output**, and the **controls** that feed the game. It also owns store listing, signing and packaging.
- The game supplies everything else.
- For VR the cabinet screen shows the game; the room, hands, props and menus are the VR chat's job.

### How to get there (in order)

1. **Make `main` the true phone game.** Bring `main` to 7.62.4 (`6cd17bc`) so web, iOS and Android all start from the same code. VR keeps working on `quest-build`.
2. **Write down the interface.** The game core exposes: advance by one fixed step, read what to draw (entities, positions, effects), read sound cues, accept input state (move x/y, fire, grenade, menu). Name it in `docs/GAME-INTERFACE.md`.
3. **Check the phone game already obeys it.** Separate rules from DOM and canvas code where they are mixed (`game.js` mixes UI and logic).
4. **Replace the Godot port with the shared core.** Options, to be decided by the owner and VR chat:
   - run the shared game in an offscreen web view and show it as the cabinet screen texture (one game, minimal drift; cost: web view performance on Quest);
   - keep the GDScript port but generate it from, or test it against, the shared game (golden-run tests: same inputs must give the same score and state).
5. Until step 4 is done, every game change must be mirrored in `quest/` by the VR chat, using golden-run comparison to confirm.

## Open items

1. Fast-forward `main` to `6cd17bc`, which deploys 7.62.4 to zc2.quest. Needs owner approval. It is website-only and does not change the iOS build.
2. Support email: `support@zc2.quest` forwarding to the owner's inbox. Needs a forwarding service and MX records in Vercel DNS, then `support.html` updated.
3. Landing page on zc2.quest with links to the App Store, Google Play and Meta Store (links go live as each store approves). The playable web game would move to a path such as `/play`.
4. Moderation for leaderboard names (report and block path, stricter server-side filtering).
5. Android project, signing and Play listing (Android chat).
