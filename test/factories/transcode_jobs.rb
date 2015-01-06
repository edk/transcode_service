
FactoryGirl.define do
  factory :transcode_job do
    aasm_state "created"
    params {}
    sequence(:video_asset_id) { |n| n }
    video_asset_secret { SecureRandom.hex }
    callback_url "http://127.0.0.1:3000"
    sequence(:name) { |n| "name #{n}" }
    asset_file_name "filename.mov"
    asset_content_type "video/quicktime"
    asset_file_size 1.megabyte
  end
end
