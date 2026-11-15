# Submits the editable App Store version for review, after checking it is the 1.0.1 update with the new build.
# The owner asked for this submission explicitly. Refuses to run if anything looks off. Never touches the released version.
require 'spaceship'

NEW_VERSION = ENV.fetch('NEW_VERSION', '1.0.1')
key = ENV.fetch('ASC_KEY_P8')
key = Base64.decode64(key) unless key.include?('BEGIN PRIVATE KEY')
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('ASC_KEY_ID'), issuer_id: ENV.fetch('ASC_ISSUER_ID'), key: key, in_house: false)

app = Spaceship::ConnectAPI::App.find(ENV.fetch('BUNDLE_ID')) or abort('App not found')
version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS) or abort('No editable version')
puts "Editable version: #{version.version_string} (#{version.app_store_state}), release type #{version.release_type}"
abort('Not the expected state or version, refusing to submit') unless version.app_store_state == 'PREPARE_FOR_SUBMISSION' && version.version_string == NEW_VERSION

full = Spaceship::ConnectAPI::AppStoreVersion.get(app_store_version_id: version.id, includes: 'build')
build = full.build
abort('No build attached, refusing to submit') unless build
puts "Attached build: #{build.version}"
abort('Attached build is not from the new pipeline, refusing to submit') unless build.version.to_i > 200

detail = (version.fetch_app_store_review_detail rescue nil)
abort('No App Review information, refusing to submit') unless detail && !detail.contact_email.to_s.empty? && !detail.contact_phone.to_s.empty?
puts "Review info: contact set, notes #{detail.notes.to_s.length} chars"

submission = app.create_review_submission(platform: Spaceship::ConnectAPI::Platform::IOS)
submission.add_app_store_version_to_review_items(app_store_version_id: version.id)
submission.submit_for_review
puts "Submitted for review: #{NEW_VERSION} build #{build.version}"
sleep 5
after = app.get_app_store_versions(filter: { platform: 'IOS' }).map { |v| "#{v.version_string}=#{v.app_store_state}" }
puts "Versions now: #{after.join(', ')}"
