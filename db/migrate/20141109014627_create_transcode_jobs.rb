class CreateTranscodeJobs < ActiveRecord::Migration
  def change
    create_table :transcode_jobs do |t|
      t.string  :aasm_state
      t.integer :video_asset_id
      t.string  :video_asset_secret
      t.string  :callback_url
      t.string  :name
      t.text    :params
      t.text    :log
      t.string  :asset_file_name
      t.string  :asset_content_type
      t.integer :asset_file_size # if the filesize gets too big, we get a mysql out of range error

      t.timestamps null: false
    end
  end
end
