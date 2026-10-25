# App Review notes (paste into App Store Connect → App Review Information → Notes)

Zombie Smash is a single-player portrait arcade shooter. No sign-in or account is required, and there are no ads.

How to play: enter a player name, press START, then watch or skip the opening story. Move left/right with the joystick, hold FIRE to shoot and tap the grenade button to throw. A boss arrives every second wave; tapping FIRE brings in the next comic panel and moves on.

Online leaderboard: when a run starts, the game sends the chosen player name and a random, locally generated persistent identifier to our Supabase leaderboard service. When the run finishes, the score and run details (kills, elapsed time, wave) are submitted. The name and score may appear on the public leaderboard. No hardware identifier, advertising identifier or tracking is used. The privacy policy is available inside the app (MENU → PRIVACY POLICY) and at https://zc2.quest/privacy.html, including how to request deletion.

The app contains no in-app purchases.

Cheat codes: a name beginning with BOT_ (for example BOT_Reviewer) activates a cheat mode. MENU → CHEATS lists the codes, which are entered on the console after pressing MENU twice. In BOT_ mode, using a code makes the run practice-only. Outside BOT_ mode, a cheat can still be used and the leaderboard score is shown with a ✦ mark.

Settings: MENU → MUSIC & SOUND. The playback audio session lets sound play with the silent switch on.
