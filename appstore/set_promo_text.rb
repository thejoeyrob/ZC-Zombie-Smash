# Updates the promotional text on the LIVE App Store version (allowed at any time, no build and no review).
require 'spaceship'
text = File.read('appstore/metadata/en-GB/promotional_text.txt').strip
abort('Promotional text must be 1-170 characters') unless (1..170).cover?(text.length)
key = ENV.fetch('ASC_KEY_P8'); key = Base64.decode64(key) unless key.include?('BEGIN PRIVATE KEY')
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'), key: key, in_house: false)
app = Spaceship::ConnectAPI::App.find(ENV.fetch('BUNDLE_ID')) or abort('App not found')
live = app.get_live_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS) or abort('No live version')
puts "Live version: #{live.version_string} (#{live.app_store_state})"
live.get_app_store_version_localizations.each do |loc|
  loc.update(attributes: { promotionalText: text })
  puts "Promotional text set for #{loc.locale}"
end
after = app.get_live_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS).get_app_store_version_localizations.map { |l| "#{l.locale}: #{l.promotional_text}" }
puts after
