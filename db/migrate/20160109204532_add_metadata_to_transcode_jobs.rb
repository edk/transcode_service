class AddMetadataToTranscodeJobs < ActiveRecord::Migration
  def change
    add_column :transcode_jobs, :job_id, :string
  end
end
