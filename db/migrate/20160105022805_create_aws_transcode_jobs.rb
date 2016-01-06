class CreateAwsTranscodeJobs < ActiveRecord::Migration
  def change
    add_column :transcode_jobs, :type, :string
  end
end
