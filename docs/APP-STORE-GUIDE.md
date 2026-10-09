# Getting Zombie Smash into the Apple App Store

You do not need a Mac. GitHub builds and signs the app for you; you only click through Apple's websites and GitHub's settings.

Plan on about two hours of your own time, plus Apple's review (usually one to two days).

## What is already done

- The game is packaged for iPhone (portrait only, iPhone only) with an App Store icon and launch screen.
- Inside the iPhone app the "Install game" menu item and the admin-code panel are hidden. Apple rejects apps that tell people to "add to home screen" or that contain hidden tools.
- Leaderboard names are filtered for offensive words.
- A privacy policy and a support page exist, ready to link from the listing.
- A GitHub workflow (`iOS TestFlight`) builds, signs and uploads the app with one click.

## Part 1: Apple setup (one time)

1. **Check your membership.** Sign in at https://developer.apple.com/account. Under Membership details, the status must be Active. Copy the **Team ID** (ten letters and numbers).
2. **Accept agreements.** Open https://appstoreconnect.apple.com, then Business (or Agreements, Tax, and Banking). Accept anything marked as needing action. A free game only needs the Free Apps agreement.
3. **Register the bundle ID.** At https://developer.apple.com/account/resources/identifiers/list press **+**, choose App IDs, then App. Description: `Zombie Smash`. Bundle ID: choose Explicit and enter `com.thejoeyrob.zombiesmash`. Leave all capabilities off. Continue, then Register.
   The bundle ID can never be changed later. If you prefer your own, use it here and set it in Part 2 step 2.
4. **Create the app record.** In App Store Connect open Apps, press **+**, then New App.
   - Platform: iOS
   - Name: `Zombie Smash` (this must be unique on the App Store; if it is taken try `Zombie Smash: Hold the Line`)
   - Primary language: English (U.K.) or English (U.S.)
   - Bundle ID: pick the one you just registered
   - SKU: anything, for example `zombiesmash001`
   - User access: Full access
5. **Create an API key for GitHub.** In App Store Connect open Users and Access, then Integrations, then App Store Connect API, then Team Keys. Press **+**. Name it `GitHub Actions`, give it **App Manager** access (Admin also works), and generate it. Then:
   - Download the `.p8` file. Apple lets you download it only once, so keep it safe.
   - Write down the **Key ID** (shown in the table) and the **Issuer ID** (shown at the top of the page).

## Part 2: Tell GitHub

1. In the repository on GitHub open Settings, then Secrets and variables, then Actions, then the Secrets tab. Press **New repository secret** four times:

   | Name | Value |
   | --- | --- |
   | `APPLE_TEAM_ID` | Your Team ID |
   | `ASC_KEY_ID` | The Key ID |
   | `ASC_ISSUER_ID` | The Issuer ID |
   | `ASC_KEY_P8` | Open the `.p8` file in a text editor and paste everything, including the lines that begin `-----BEGIN` and `-----END` |

2. Only if you chose your own bundle ID: on the Variables tab add `IOS_BUNDLE_ID` with that value.
   Optional: `IOS_APP_VERSION` sets the version shown on the App Store (default `1.0.0`).
3. Never paste these values into chat, issues or code.

## Part 3: Build and upload

1. In the repository open the **Actions** tab, choose **iOS TestFlight**, press **Run workflow**, then the green button.
2. Wait about 10 to 20 minutes. A green tick means Apple has received the build.
3. In App Store Connect open your app, then TestFlight. The build shows as Processing for 5 to 30 minutes, then becomes ready.

If the workflow fails, open the red step and match it here:

| What it says | What to do |
| --- | --- |
| Missing repository secrets | A secret name is wrong or empty. Re-check Part 2. |
| Provisioning profile, no profiles found, or cloud signing permission | The API key needs App Manager or Admin access. Make a new key. |
| Bundle identifier not found, or no app record | Finish Part 1 steps 3 and 4 with exactly the same bundle ID. |
| Authentication failed | Key ID, Issuer ID or the `.p8` contents are wrong. |
| SDK or Xcode version too old | Re-run the workflow later; it always picks the newest stable Xcode available on GitHub. |

## Part 4: Test on your iPhone

1. Install **TestFlight** from the App Store on your iPhone.
2. In App Store Connect open Users and Access and make sure your Apple ID is listed. In your app open TestFlight, then Internal Testing, press **+**, create a group and add yourself.
3. Open TestFlight on the phone, install Zombie Smash and play for a few minutes. Check:
   - Sound plays after your first tap, and the silent switch behaves as you expect.
   - Nothing important is hidden behind the notch or the home bar.
   - A score appears on the leaderboard.
   - Locking the phone and coming back resumes the game.
   - There is no "Install game" or admin item in the menu.
4. Take your screenshots now (press the side button and volume up together).

## Part 5: Fill in the App Store page

In App Store Connect open your app, then the iOS version (1.0.0). Here is suggested wording; change it freely.

- **Subtitle (30 characters):** `Hold the line. Seven bosses.`
- **Promotional text:** `Seven bosses. One last stand. Beat your friends to the top of the leaderboard.`
- **Description:**

  > Hold the line.
  >
  > Joey Rob stands between the horde and the base. Zombies march down the screen, bosses roll in at the end of every stage, and every kill builds your boost.
  >
  > • Seven boss fights, from Jordan to Dr Mantis
  > • Pistols, SMGs, a DMR and wild pick-up weapons
  > • Grenades, boosts and combo multipliers
  > • Unlock-everything console skins, no purchases
  > • Global leaderboard with no sign-up
  > • Plays in portrait, one thumb for movement and one for fire
  >
  > No ads. No in-app purchases. No account.
- **Keywords (100 characters, commas, no spaces):** `zombie,shooter,arcade,boss,survival,retro,portrait,action,leaderboard,pixel`
- **Support URL:** `https://joeyrob.github.io/ZC-Zombie-Smash/support.html`
- **Privacy Policy URL:** `https://joeyrob.github.io/ZC-Zombie-Smash/privacy.html`
- **Category:** Games, then Action. Secondary: Arcade.
- **Copyright:** `2026 Joey Rob` (use your legal name).
- **Screenshots:** upload at least three from the TestFlight build. Apple currently asks for 6.9-inch iPhone screenshots (1320 × 2868); the page tells you the exact sizes it will accept.
- **Build:** under Build press **+** and pick the processed build.
- **Pricing and availability:** Free, all countries.

### App Privacy (the "nutrition label")

Open App Privacy and answer truthfully. For this game:

- Do you collect data? **Yes**.
- Data types:
  - Identifiers, Device ID: the random code the game makes on the phone. Purpose: App Functionality. Linked to the user: Yes. Used for tracking: No.
  - User Content, Gameplay Content: your score and player name on the leaderboard. Purpose: App Functionality. Linked to the user: Yes. Used for tracking: No.
- Nothing else is collected. There are no ads, no analytics and no third-party SDKs.

If you ever add ads, analytics or accounts, update this and the privacy policy.

### Age rating

Answer the questionnaire honestly. The game has frequent cartoon and fantasy violence (shooting zombies, blood splatter), no gambling, no real-money purchases and no web access. Expect 12+ or higher depending on how you rate the violence.

### App Review information

- Fill in your contact name, phone number and email so Apple can reach you.
- Sign-in required: **No**.
- Notes for the reviewer:

  > Zombie Smash is a portrait arcade game. No account or login is needed. Players type a display name, which is shown on a public leaderboard and filtered for offensive words. Scores are sent to our Supabase backend. The game works offline and sends scores later.

### Export compliance

The app already declares that it uses only standard encryption (HTTPS), so you should not be asked. If Apple asks anyway, answer that it uses only exempt encryption.

## Part 6: Submit

1. Check every red warning on the version page is gone.
2. Press **Add for Review**, then **Submit to App Review**.
3. Review usually takes one to two days. You get an email when the status changes. Choose automatic release or manual release when you submit.

### If Apple rejects it

Apple explains the reason in Resolution Center. Common ones for a game like this:

- **Not enough in the app (4.2):** unlikely here, it is a full game. Reply with a short description of the game modes.
- **Intellectual property (5.2):** you must have the right to use all art, music, sound effects, and the names or likenesses of real people (the boss names). If any of it belongs to someone else, get their permission or replace it before submitting.
- **User-generated content (1.2):** the leaderboard shows player-typed names. The name filter and the support page address this; mention them in your reply.
- **Crash or bug:** reply with details. Fix the code, run the workflow again, add the new build to the version and resubmit.

## Releasing an update later

1. Change the game and push to `main`.
2. For the web version, raise the `?v=` numbers and the `CACHE` name in `sw.js` (see the README).
3. Raise `IOS_APP_VERSION` (for example to `1.0.1`) under Settings, then Secrets and variables, then Actions, then Variables.
4. Run the **iOS TestFlight** workflow. Every run gets a higher build number automatically.
5. In App Store Connect press **+** next to the iOS App version to create the new version, pick the new build, describe what changed, and submit.
