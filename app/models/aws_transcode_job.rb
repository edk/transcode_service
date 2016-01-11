


class AWSTranscodeJob < TranscodeJob
  @queue = :default
  
  def trigger
    Resque.enqueue(AWSTranscodeJob, self.id)
  end

  def self.perform job_id
    begin
      puts "starting background job"
      job = AWSTranscodeJob.find(job_id)
      puts "job #{job.inspect}"
      
      job.run!
      if !job.video_asset
        puts "creating new VideoAsset with #{job.build_params}"
        job.video_asset = VideoAsset.new(job.build_params)
        job.video_asset.save!
        job.save!
      end
   
      puts "processing started for #{job.id} #{job.video_asset.asset_file_name}"
      rv = aws_transcode! job
      puts "processing complete for #{job.id} #{job.video_asset.asset_file_name}"

      rv ? job.complete! : job.fail!
      
      job.save!
      # call out to webhook with update
      job.trigger_callback
    rescue
      job.params = { error: $!.to_s, backtrace: $!.backtrace }
      job.fail!
      job.save(validate: true)
      puts "Exception processing AWSTranscodeJob id #{job.id}! #{$!} #{$!.backtrace.join("\n")}"
    end
  end
  
  def self.aws_transcode! job
    source_s3        = Aws::S3::Client.new(source_options.merge(region: region))
    transcode_in_s3  = Aws::S3::Client.new(transcode_options.merge(region: region))
    transcode_out_s3 = Aws::S3::Client.new(transcode_options.merge(region: region))

    file_assets = ETFileAssets.new source: source_s3,
                            source_bucket: source_bucket,
                             transcode_in: transcode_in_s3,
                            transcode_out: transcode_out_s3,
                                local_job: job,
                        transcode_buckets: transcode_buckets

    file_assets.copy_from_source_to_ets_input # Copy Setup

    # SubmitJob
    ets = ETJob.new local_job: job
    
    if job.created? || job.canceled? || job.failed?
      ets.submit
    end

    read_resp = ets.poll(timeout: 2.hours)

    if read_resp.job.status =~ /progress/i
      job.poll_timeout!
      job.log_string "Transcode still not done!  check back later or find out why it's still in progress?"
      false
    elsif read_resp.job.status != "Complete"
      job.log_string "ERROR for job ID: #{ets.job_response.job.id} ... job => #{ets.job_response.job.inspect}"
      false
    else
      file_assets.move_from_ets_output_to_source
      true
    end
  end
    
  protected
  
  def self.list_transcode_in
    transcode_in_s3 = Aws::S3::Client.new(transcode_options.merge(region: region))
    s3_resp = transcode_in_s3.list_objects(bucket: transcode_buckets[:in])
    s3_resp.contents.map {|k| k.key }
  end
  
  def self.list_transcode_out
    transcode_out_s3 = Aws::S3::Client.new(transcode_options.merge(region: region))
    s3_resp = transcode_out_s3.list_objects(bucket: transcode_buckets[:out])
    s3_resp.contents.map {|k| k.key }
  end

  def self.clear_all_s3_transcode_objs
    delete_keys_from_output
    delete_keys_from_input
  end
  
  def self.delete_keys_from_output
    transcode_out_s3 = Aws::S3::Client.new(transcode_options.merge(region: region))
    s3_resp = transcode_out_s3.list_objects(bucket: transcode_buckets[:out])
    keys = s3_resp.contents.map {|k| k.key }
    puts "keys: #{keys.inspect}"
    transcode_out_s3.delete_objects(
      bucket: transcode_buckets[:out],
      delete: {
        objects:
          keys.map { |k| {key: k} }
        # quiet: true
      }
     )
  end

  def self.delete_keys_from_input
    transcode_in_s3 = Aws::S3::Client.new(transcode_options.merge(region: region))
    s3_resp = transcode_in_s3.list_objects(bucket: transcode_buckets[:in])
    keys = s3_resp.contents.map {|k| k.key }
    puts "keys: #{keys.inspect}"
    transcode_in_s3.delete_objects(
      bucket: transcode_buckets[:in],
      delete: {
        objects:
          keys.map { |k| {key: k} }
        # quiet: true
      }
     )
  end
  
  def self.source_options
    {
      region: region,
      access_key_id: ENV['S3_ACCESS_KEY'],
      secret_access_key: ENV['S3_SECRET']
    }
  end

  def self.source_bucket
    ENV['S3_BUCKET']
  end
  
  def self.region
    ENV['transcode_region']
  end

  def self.transcode_options
    {
      region: ENV['transcode_region'],
      access_key_id: ENV['transcode_access_key_id'],
      secret_access_key: ENV['transcode_secret_access_key'],
    }
  end
  
  def self.transcode_buckets
    {
      in: ENV['transcode_in_bucket'],
      out: ENV['transcode_out_bucket']
    }
  end
  
end

