# App Review notes (paste into App Store Connect → App Review Information → Notes, and send as the reply to Apple's Guideline 2.1 message)

Answers to the six items in Apple's message:

1. SCREEN RECORDING
A recording from a physical iPhone, starting from launching the app, is attached to the reply. It shows: launch → enter a player name → PRESS START → the opening story → playing a wave (move, fire, grenade) → a boss scene → MENU (Music & Sound, Privacy Policy, High Scores). The app has no account registration, login or account deletion (there are no accounts), no paid content or in-app purchases, and the only user-generated content is the player name described in item 4.

2. PURPOSE AND TARGET AUDIENCE
Zombie Smash is a free, single-player, retro-style arcade shooter for iPhone. The player holds a defence line at the bottom of the screen, shoots incoming zombies, fights seven boss characters across seven arenas, and tries to set a high score. It is entertainment for casual players aged 12 and over who enjoy short arcade sessions; it has cartoon-style zombie violence only. It solves nothing beyond fun: quick, pick-up-and-play arcade action with no ads and no sign-in.

3. HOW TO USE IT (no login or sample files needed)
Type any player name (2 to 24 letters or numbers) and press PRESS START. Watch or skip the opening story (tap FIRE to bring in the next comic panel). Slide the joystick left and right to move, hold FIRE to shoot, tap the blue button to throw a grenade. Waves of zombies arrive from the top; a boss arrives every second wave. Letting 10 zombies through ends the run. MENU pauses and opens settings, console skins, the high-score list, how to play and the privacy policy.
For testing: a name beginning with BOT_ (for example BOT_Reviewer) turns on a cheat mode. MENU → CHEATS lists the codes, entered on the console after pressing MENU twice. Runs in this mode never reach the public leaderboard.

4. EXTERNAL SERVICES
- Supabase (supabase.com): hosts the online high-score list. When a run starts the app sends the player name and a random, locally generated identifier; when it ends it sends the score, kills, time and wave. The name and score may appear on the public leaderboard. Names are checked against an objectionable-words filter before use, and any name can be removed on request (support page: https://zc2.quest/support.html).
- zc2.quest (web hosting): serves only the privacy policy and support pages. The privacy policy is also inside the app (MENU → PRIVACY POLICY).
No advertising, analytics, tracking, social login, payment processor or AI service is used. No hardware or advertising identifier is read. The app is fully playable offline (scores are saved on the device and uploaded later).

5. REGIONAL DIFFERENCES
None. The app functions the same in every region, in English, with the same content.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
The app is not in a regulated industry. All characters, artwork, music and sound effects were created for this game by the developer; no licensed or third-party protected material is used.

Other: the app contains no in-app purchases. Sound plays with the silent switch on (playback audio session); settings are in MENU → MUSIC & SOUND.
