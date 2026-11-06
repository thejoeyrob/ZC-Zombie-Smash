# Rooms (multiplayer)

Up to six people share the arcade: avatars with measured hands, machine and pinball claims, the 4-seat board game, host controls (lock, remove).
Voice is not included (use a Quest party call).

## Deploy the room server (once)
1. Render.com, New, Blueprint, pick this repo and branch `quest-build`. `render.yaml` builds `server/Dockerfile` (Node 22, `ws` vendored, no keys).
   Any host that runs a Docker container and gives you a `wss://` address works the same way. Run **one** instance: rooms live in memory.
2. Copy the address it gives you, add `/shack`: `wss://NAME.onrender.com/shack`.
3. GitHub, Settings, Secrets and variables, Actions, Variables: add `SHACK_ENDPOINT` with that address.
4. Run the Quest VR build. The menu's FRIENDS page then makes and joins rooms.

Test locally: `node --test server/tests/*.test.mjs`, and the game client against the real server: `tests/lobby_client_test.gd`.
Health check: `https://HOST/health`.
