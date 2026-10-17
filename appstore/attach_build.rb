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
  a = loc.attributes
  puts "Locale #{a['locale']}: description #{a['description'].to_s.length} chars, keywords #{a['keywords'].to_s.length} chars, promo #{a['promotionalText'].to_s.length} chars, support #{a['supportUrl']}"
  loc.get_app_screenshot_sets.each do |set|
    puts "  screenshots #{set.screenshot_display_type}: #{set.app_screenshots.count}"
  end
end
