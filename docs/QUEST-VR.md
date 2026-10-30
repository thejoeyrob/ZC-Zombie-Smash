# Zombie Smash VR (Meta Quest)

A native Quest app (Godot 4, OpenXR): you stand at one arcade machine in an old-school arcade. Grab the stick, push the red
FIRE button, press the blue GRENADE button and MENU. Everything else is the same game as the phone version.

## Layout
* `quest/scripts/zs_engine.gd`: the game simulation, ported line by line from `engine.js` (seeded, fixed step).
  `quest/tools/golden.mjs` runs the JavaScript engine through 12 scripted scenarios (waves, every boss, deaths) and
  `quest/tests/trace.gd` runs the port through the same ones: every digest must match. CI runs this before building.
* `quest/scripts/zs_screen.gd`: draws the 343 x 412 game world on the cabinet monitor (port of `renderer.js`).
* `quest/scripts/cabinet.gd`, `arcade_room.gd`, `vr_build.gd`: the machine, the room and shape helpers.
* `quest/scripts/zs_audio.gd`: plays the same `snd-*.wav` / `mus-*.wav` library as the phone game (effects from the machine).
* `quest/scripts/vr_main.gd`: XR set-up, grabbing the stick, pressing buttons, haptics, game flow, desktop test mode.
* `quest/tools/sync-assets.sh`: copies art and sound from the repository root into `quest/assets` (generated, not committed).

## Controls
* Grip (or trigger) near the yellow ball grabs the stick; lean it left/right to move. Spring returns it when you let go.
* Push FIRE / GRENADE / MENU with a hand, or use the assists: right trigger = fire, A = grenade, B / menu = pause,
  thumbstick = move.
* The machine is scaled to your height and placed in front of you after about a second (recentre with `recenter()`).

## Testing without a headset
`xvfb-run godot --path quest --rendering-driver opengl3 --rendering-method gl_compatibility -- --shots=/tmp/out --play`
renders screenshots from a flat camera with simulated hands; `-- --autoplay --quit_after=25` (headless) plays by itself.

## What the build proves
CI exports a debug APK with the Meta OpenXR vendors plugin (a GDExtension; enabled in the export preset with
`xr_features/enable_meta_plugin`). The run prints the APK's manifest: `android.hardware.vr.headtracking`,
`com.oculus.supportedDevices`, `com.oculus.intent.category.VR`, the Khronos OpenXR loader and `libgodotopenxrvendors.so`.
It has not been run on a headset yet; the first session will need tuning (grab distance, button feel, cabinet height).

## Building the APK
Actions -> "Quest VR build" (needs nothing but the repository). The APK is an artifact of the run; install it with Meta Quest
Developer Hub or `adb install`. Putting it on the Meta Horizon Store needs the developer account's app id and a release channel
(`ovr-platform-util`), which is a later step.
