class CreateTranscodeEvents < ActiveRecord::Migration
  def change
    create_table :transcode_events do |t|
      t.references :transcode_job
      t.string     :data

      t.timestamps
    end
  end
end
