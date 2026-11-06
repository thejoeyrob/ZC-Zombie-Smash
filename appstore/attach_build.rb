# Attaches the newest processed TestFlight build to the editable App Store version and prints what the version contains.
require 'spaceship'

key = ENV.fetch('ASC_KEY_P8')
key = Base64.decode64(key) unless key.include?('BEGIN PRIVATE KEY')
token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'), key: key, in_house: false)
Spaceship::ConnectAPI.token = token

app = Spaceship::ConnectAPI::App.find(ENV.fetch('BUNDLE_ID'))
abort('App not found for that bundle id') unless app
version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
abort('No editable App Store version found') unless version
puts "Version #{version.version_string} state=#{version.app_store_state}"

builds = Spaceship::ConnectAPI::Build.all(app_id: app.id, processing_states: 'VALID', sort: '-uploadedDate')
builds = builds.reject { |b| b.expired }
abort('No processed build found yet. Wait a few minutes and run again.') if builds.empty?
build = builds.first
puts "Newest processed build: #{build.version} (uploaded #{build.uploaded_date})"
version.select_build(build_id: build.id)
puts "Attached build #{build.version} to version #{version.version_string}"

version.get_app_store_version_localizations.each do |loc|
  puts "Locale #{loc.locale}: description #{loc.description.to_s.length} chars, keywords #{loc.keywords.to_s.length} chars, promo #{loc.promotional_text.to_s.length} chars, support #{loc.support_url}"
  loc.get_app_screenshot_sets.each do |set|
    puts "  screenshots #{set.screenshot_display_type}: #{set.app_screenshots.count}"
  end
end

# Report (booleans and lengths only, never the contact details themselves) what App Review Information now holds.
begin
  detail = version.fetch_app_store_review_detail
  puts "Review information: contact first name #{detail.contact_first_name.to_s.empty? ? 'MISSING' : 'set'}, last name #{detail.contact_last_name.to_s.empty? ? 'MISSING' : 'set'}, phone #{detail.contact_phone.to_s.empty? ? 'MISSING' : 'set'}, email #{detail.contact_email.to_s.empty? ? 'MISSING' : 'set'}, notes #{detail.notes.to_s.length} chars, sign-in required: #{detail.demo_account_required}"
rescue => e
  puts "Could not read review information: #{e.message}"
end
