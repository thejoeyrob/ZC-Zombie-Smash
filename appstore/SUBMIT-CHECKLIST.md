# Sending Zombie Smash to Apple as a fresh app

1. **YOU:** App Store Connect > My Apps > Zombie Smash > App Information > Remove App (only if you are replacing the old record).
2. **YOU:** My Apps > + > New App: iOS, name Zombie Smash, English (U.K.), the existing bundle ID com.thejoeyrob.zombiesmash, a new SKU (for example zombiesmash002), full access.
3. **CLAUDE or YOU:** run GitHub Actions > "iOS TestFlight" (uploads a build). Wait until it shows as processed in TestFlight (5 to 30 minutes).
4. **CLAUDE or YOU:** run GitHub Actions > "App Store listing" (pushes text, categories and the six screenshots from `appstore/`, then attaches the newest processed build). It never submits.
5. **YOU, in App Store Connect:** age rating questionnaire, App Privacy answers, pricing (Free) and availability, App Review contact details (name, phone, email), paste `appstore/REVIEW-NOTES-NEW-APP.md` into the review Notes box, EU trader status if asked, export compliance (standard encryption only).
6. **YOU:** Add for Review, then Submit.
