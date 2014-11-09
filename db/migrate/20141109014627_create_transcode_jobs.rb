class CreateTranscodeJobs < ActiveRecord::Migration
  def change
    create_table :transcode_jobs do |t|
      t.string :status
      t.text :params

      t.timestamps null: false
    end
  end
end
