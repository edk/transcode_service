
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
        puts "creating new va with #{job.build_params}"
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
  
  # rv = AWSTranscodeJob.aws_transcode! AWSTranscodeJob.find(60)
  #  AWSTranscodeJob.perform(60)
  
  MAX_RETRY_COUNT = 120
  def self.aws_transcode! job
    source_s3        = Aws::S3::Client.new(source_options.merge(region: region))
    transcode_in_s3  = Aws::S3::Client.new(transcode_options.merge(region: region))
    transcode_out_s3 = Aws::S3::Client.new(transcode_options.merge(region: region))
    
    
    #### copy from video asset to transcoder in bucket
    resp = source_s3.get_object( bucket: source_bucket, key: job.video_asset.asset.path )
    transcode_resp = transcode_in_s3.put_object( bucket: transcode_buckets[:in], key: job.video_asset.asset.path, body: resp.body )
    job.log_string "Copied #{job.video_asset.asset.path} from #{source_bucket} to #{transcode_buckets[:in]}"

    #### submit job
    input_key  = job.video_asset.asset.path
    out_key = input_key.split('.')[0..-2].join('.')
    
    elastic_transcoder, job_response = submit_job_to_et input_key, out_key
    job.log_string "Submitted job ID: #{job_response.job.id} to AWS Elastic Transcoder"
    
    done = false
    count = 0

    # TODO: move this polling loop to a method so we can check back later if we run out of time
    
    #### poll in loop.  doing this in a blocking manner to keep the same semantics as the previous transcoder
    while !done do
      sleep 30
      read_resp = elastic_transcoder.read_job(id: job_response.job.id)
      job.log_string "#{Time.now.iso8601}   count => #{count}, polling job ID #{job_response.job.id}, status => #{read_resp.job.status}"
      break unless read_resp.job.status =~ /progress/i

      count += 1
      break if count > MAX_RETRY_COUNT
    end
    
    job.log_string "polling finished job ID: #{job_response.job.id} ... status => #{read_resp.job.status}"
    
    if read_resp.job.status =~ /progress/i
      # still not done?
      job.log_string "Transcode still not done!  check back later or find out why it's still in progress?"
      false
    elsif read_resp.job.status != "Complete"
      # there was an error
      job.log_string "ERROR for job ID: #{job_response.job.id} ... job => #{job_response.job.inspect}"
      false
    else
      job.log_string "Completing job ID: #{job_response.job.id}"

      # look for all the objects
      all_objs_resp = transcode_out_s3.list_objects( bucket: ENV['transcode_out_bucket'], prefix: out_key )
      all_objs      = all_objs_resp.contents.map {|o| o.key }

      #### on success copy assets back to the right original bucket, deleting in and out bucket objects
      styles = job.video_asset.asset.styles.keys
      thumb_key, keys = styles.map {|style| job.video_asset.asset.path(style) }.partition { |k| k =~ /\.jpg$/ }
      
      # copy out of and delete from transcode out bucket
      keys.each do |target_key|
        # target key needs to look something like this:            video_assets/assets/000/000/014/mp4/my_video.mp4
        # key is missing the /:style/ in the transcode out bucket: video_assets/assets/000/000/014/my_video.mp4
        key = all_objs.detect { |o| target_key.split('/').last == o.split('/').last }
        s3_resp_source = transcode_out_s3.get_object( bucket: transcode_buckets[:out], key: key )
        s3_resp_target = source_s3.put_object( bucket: source_bucket, key: target_key, body: s3_resp_source.body )
        job.log_string "Copied from #{transcode_buckets[:out]}/#{key} to #{source_bucket}/#{target_key}"
        delete_resp = transcode_out_s3.delete_object( bucket: transcode_buckets[:out], key: key )
        job.log_string "Deleted #{key} from #{transcode_buckets[:out]} #{delete_resp.inspect}"
      end
      
      # handle thumbnails.  AWS doesn't allow a single thumbnail
      thumb_keys = all_objs.select {|o| o =~ /(png|jpg)$/ }
      
      # copy the first thumb_key, delete them all when done.
      thumb_key = thumb_keys.first
      source_thumb_key = job.video_asset.asset.path(:thumb)
      s3_resp_source = transcode_out_s3.get_object( bucket: transcode_buckets[:out], key: thumb_key )
      s3_resp_target = source_s3.put_object( bucket: source_bucket, key: source_thumb_key, body: s3_resp_source.body )
      job.log_string "Copied from #{transcode_buckets[:out]}/#{thumb_key} to #{source_bucket}/#{source_thumb_key}"
      
      delete_resp = transcode_out_s3.delete_objects( bucket: transcode_buckets[:out], delete: { objects: thumb_keys.map {|k| {key: k} } } )
      job.log_string "Deleted #{thumb_keys.count} thumbnail keys from #{transcode_buckets[:out]} #{delete_resp.inspect}"
      
      key = job.video_asset.asset.path(:original)
      delete_resp = transcode_out_s3.delete_object( bucket: transcode_buckets[:in], key: key )
      job.log_string "Deleted #{key} from #{transcode_buckets[:in]} #{delete_resp.inspect}"
      
      true
    end
  end
  
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
  
  protected
  
  # AWSTranscodeJob.clear_all_s3_transcode_objs

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
  
  def self.submit_job_to_et input_key, out_key
    job_opts = {
      pipeline_id: pipeline_id,
      input: {
        key: input_key
      },
      outputs: [
        {
          key: "#{out_key}.mp4",
          preset_id: presets[:web_preset_id],
          thumbnail_pattern: "#{out_key}-{count}", 
        },
        {
          key: "#{out_key}.webm",
          preset_id: presets[:webm_preset_id],
        }
      ],
      # user_metadata: {
      #   "String" => "",
      # }
    }
    elastictranscoder = Aws::ElasticTranscoder::Client.new(transcode_options)
    resp = elastictranscoder.create_job job_opts
    [elastictranscoder, resp]
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
  
  def self.transcode_options
    {
      region: region,
      access_key_id: ENV['transcode_access_key_id'],
      secret_access_key: ENV['transcode_secret_access_key']
    }
  end
  
  def self.presets
    { web_preset_id: ENV['web_preset_id'], webm_preset_id: ENV['webm_preset_id'] }
  end
  
  def self.region
    ENV['transcode_region']
  end
  
  def self.pipeline_id
    ENV['pipeline_id']
  end
  
  def self.transcode_buckets
    {
      in: ENV['transcode_in_bucket'],
      out: ENV['transcode_out_bucket']
    }
  end
  
end

