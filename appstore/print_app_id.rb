# Prints the app's Apple ID (the number in its App Store link) so the public link can be checked. Read-only.
require 'spaceship'
key = ENV.fetch('ASC_KEY_P8'); key = Base64.decode64(key) unless key.include?('BEGIN PRIVATE KEY')
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'), key: key, in_house: false)
app = Spaceship::ConnectAPI::App.find(ENV.fetch('BUNDLE_ID')) or abort('App not found')
puts "APP_APPLE_ID=#{app.id} NAME=#{app.name} BUNDLE=#{app.bundle_id}"
app.get_app_store_versions(filter: { platform: 'IOS' }).each { |v| puts "VERSION #{v.version_string} = #{v.app_store_state}" }
