# Sets the Notes box of App Review Information from appstore/REVIEW-NOTES-NEW-APP.md and turns "Sign-in required" off
# (the app has no login). Contact details are never touched.
require 'spaceship'

key = ENV.fetch('ASC_KEY_P8')
key = Base64.decode64(key) unless key.include?('BEGIN PRIVATE KEY')
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'), key: key, in_house: false)

app = Spaceship::ConnectAPI::App.find(ENV.fetch('BUNDLE_ID'))
abort('App not found for that bundle id') unless app
version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
abort('No editable App Store version found') unless version

notes = File.read(File.join(__dir__, 'REVIEW-NOTES-NEW-APP.md')).strip
abort("Notes are #{notes.length} characters; App Store Connect allows 4000") if notes.length > 4000
detail = version.fetch_app_store_review_detail
abort('App Review Information does not exist yet: save it once in App Store Connect first') unless detail
detail.update(attributes: { notes: notes, demoAccountRequired: false })
puts "Set review notes (#{notes.length} characters) and sign-in required = false. Contact details were not touched."
