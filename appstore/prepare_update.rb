# Prepares the editable App Store version for an update: sets the version number and "What's New", attaches the newest processed build.
# Never submits for review and never touches the released version.
require 'spaceship'

NEW_VERSION = ENV.fetch('NEW_VERSION', '1.0.1')
WHATS_NEW = <<~TXT.strip
  - A new wide Zombie Smash banner above the game on tall phones.
  - Boss music now starts as soon as the boss fight does.
  - Steadier controls and smoother story scenes.
TXT

key = ENV.fetch('ASC_KEY_P8')
key = Base64.decode64(key) unless key.include?('BEGIN PRIVATE KEY')
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'), key: key, in_house: false)

app = Spaceship::ConnectAPI::App.find(ENV.fetch('BUNDLE_ID')) or abort('App not found')
version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS) or abort('No editable version')
abort("Editable version is #{version.version_string} (#{version.app_store_state}), not safe to change") unless %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(version.app_store_state)
puts "Editable version: #{version.version_string} (#{version.app_store_state})"

if version.version_string != NEW_VERSION
  version.update(attributes: { versionString: NEW_VERSION })
  version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
  puts "Version number now #{version.version_string}"
end

version.get_app_store_version_localizations.each do |loc|
  loc.update(attributes: { whatsNew: WHATS_NEW })
  puts "Set What's New for #{loc.locale}"
end

builds = Spaceship::ConnectAPI::Build.all(app_id: app.id, processing_states: 'VALID', sort: '-uploadedDate').reject(&:expired)
abort('No processed build yet. Wait a few minutes and run again.') if builds.empty?
build = builds.first
puts "Newest processed build: #{build.version} (version #{build.app_version rescue '?'})"
version.select_build(build_id: build.id)
puts "Attached build #{build.version} to #{version.version_string}"
detail = (version.fetch_app_store_review_detail rescue nil)
puts "Review info present: #{detail ? 'yes' : 'no'}; notes #{detail&.notes.to_s.length} chars"
