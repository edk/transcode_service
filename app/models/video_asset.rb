class VideoAsset < ActiveRecord::Base

  has_one :transcode_job

  has_attached_file :asset,
    storage: :s3,
    s3_permissions: 'private',
    s3_credentials: Proc.new { |a| a.instance.s3_credentials },
    preserve_files: true,
    path: ":class/:attachment/:remote_id_partition/:style/:filename", # new interpolation key, remote_id_partition
    styles: {
      thumb:  { geometry: "300x200", format: 'jpg', convert_options: { input: {'v'=>'error'} } },
      mp4: { format: 'mp4', log: true, convert_options: { input: {'v'=>'error'} } },
      ogg: { format: 'webm', log: true, convert_options: { input: {'v'=>'error'} } },
    }, processors: [:transcoder]

  do_not_validate_attachment_file_type :asset
  serialize :asset_meta

  before_post_process :do_local_processing?

  def do_local_processing?
    true
  end

  def s3_credentials
    unless %w[S3_BUCKET S3_ACCESS_KEY S3_SECRET].all? { |key| ENV[key].present? }
      raise "Missing S3 Environment variables" 
    end

    {
      bucket: ENV['S3_BUCKET'],
      access_key_id: ENV['S3_ACCESS_KEY'],
      secret_access_key: ENV['S3_SECRET']
    }
  end

end


