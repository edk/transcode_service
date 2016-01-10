
class ETFileAssets

  def initialize options
    @source = options[:source]
    @source_bucket = options[:source_bucket]
    @transcode_in = options[:transcode_in]
    @transcode_out = options[:transcode_out]
    @local_job = options[:local_job]
    @transcode_buckets = options[:transcode_buckets]
  end

  def copy_from_source_to_ets_input
    #### copy from video asset to transcoder in bucket
    resp           = @source.get_object( bucket: @source_bucket, key: @local_job.video_asset.asset.path )
    transcode_resp = @transcode_in.put_object( bucket: @transcode_buckets[:in], key: @local_job.video_asset.asset.path, body: resp.body )
    @local_job.log_string "Copied #{@local_job.video_asset.asset.path} from #{@source_bucket} to #{@transcode_buckets[:in]}"
    transcode_resp
  end

  def move_from_ets_output_to_source
    @local_job.log_string "Completing job ID: #{ets.job_response.job.id}"

    input_key  = @local_job.video_asset.asset.path
    out_key = input_key.split('.')[0..-2].join('.')

    # look for all the objects
    all_objs_resp = @transcode_out.list_objects( bucket: @transcode_buckets[:out], prefix: out_key )
    all_objs      = all_objs_resp.contents.map {|o| o.key }

    #### on success copy assets back to the right original bucket, deleting in and out bucket objects
    styles = @local_job.video_asset.asset.styles.keys
    thumb_keys, keys = styles.map {|style| @local_job.video_asset.asset.path(style) }.partition { |k| k =~ /\.(png|jpg)$/ }
    
    # copy out of and delete from transcode out bucket
    keys.each do |target_key|
      # target key needs to look something like this:            video_assets/assets/000/000/014/mp4/my_video.mp4
      # key is missing the /:style/ in the transcode out bucket: video_assets/assets/000/000/014/my_video.mp4
      key = all_objs.detect { |o| target_key.split('/').last == o.split('/').last }
      s3_resp_source = @transcode_out.get_object( bucket: @transcode_buckets[:out], key: key )
      s3_resp_target = @source.put_object( bucket: @source_bucket, key: target_key, body: s3_resp_source.body )
      @local_job.log_string "Copied from #{@transcode_buckets[:out]}/#{key} to #{@source_bucket}/#{target_key}"
      delete_resp = @transcode_out.delete_object( bucket: @transcode_buckets[:out], key: key )
      @local_job.log_string "Deleted #{key} from #{@transcode_buckets[:out]} #{delete_resp.inspect}"
    end
    
    # handle thumbnails.  AWS doesn't allow a single thumbnail
    thumb_keys = all_objs.select {|o| o =~ /(png|jpg)$/ }
    
    # copy the first thumb_key, delete them all when done.
    thumb_key = thumb_keys.first
    source_thumb_key = @local_job.video_asset.asset.path(:thumb)
    s3_resp_source = @transcode_out.get_object( bucket: @transcode_buckets[:out], key: thumb_key )
    s3_resp_target = @source.put_object( bucket: @source_bucket, key: source_thumb_key, body: s3_resp_source.body )
    @local_job.log_string "Copied from #{@transcode_buckets[:out]}/#{thumb_key} to #{@source_bucket}/#{source_thumb_key}"
    
    delete_resp = @transcode_out.delete_objects( bucket: @transcode_buckets[:out], delete: { objects: thumb_keys.map {|k| {key: k} } } )
    @local_job.log_string "Deleted #{thumb_keys.count} thumbnail keys from #{@transcode_buckets[:out]} #{delete_resp.inspect}"
    
    key = @local_job.video_asset.asset.path(:original)
    delete_resp = @transcode_out.delete_object( bucket: @transcode_buckets[:in], key: key )
    @local_job.log_string "Deleted #{key} from #{@transcode_buckets[:in]} #{delete_resp.inspect}"    
  end
end

class ETJob

  def initialize options
    @local_job = options[:local_job]
  end

  def submit
    input_key  = @local_job.video_asset.asset.path
    out_key = input_key.split('.')[0..-2].join('.')

    @elastic_transcoder, @job_response = submit_job_to_et input_key, out_key
    job.log_string "Submitted job ID: #{@job_response.job.id} to AWS Elastic Transcoder"
    [@elastic_transcoder, @job_response]
  end

  def submit_job_to_et input_key, out_key
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
    @local_job.update_attribute(:job_id, resp.job.id) # save the ETS job id to database
    [elastictranscoder, resp]
  end

  def poll options
    timeout = options[:timeout]
    start_time = Time.now
    done, count = false, 0

    #### poll in loop.  doing this in a blocking manner to keep the same semantics as the previous transcoder
    while !done do
      sleep 30
      read_resp = @elastic_transcoder.read_job(id: @job_response.job.id)
      job.log_string "#{Time.now.iso8601}   count => #{count}, polling job ID #{@job_response.job.id}, status => #{read_resp.job.status}"
      break unless read_resp.job.status =~ /progress/i

      count += 1

      if Time.now > (start_time + timeout)
        puts "Timeout, exiting polling loop"
        break
      end
    end
    
    job.log_string "polling finished job ID: #{@job_response.job.id} ... status => #{read_resp.job.status}"
    read_resp
  end

  attr_reader :job_response

  protected

  def transcode_options
    {
      region: ENV['transcode_region'],
      access_key_id: ENV['transcode_access_key_id'],
      secret_access_key: ENV['transcode_secret_access_key'],
    }
  end

  def pipeline_id
    ENV['pipeline_id']
  end

  def presets
    { web_preset_id: ENV['web_preset_id'], webm_preset_id: ENV['webm_preset_id'] }
  end

end

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
  
  # rv = AWSTranscodeJob.aws_transcode! AWSTranscodeJob.find(60)
  #  AWSTranscodeJob.perform(60)
  
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

    # Copy Setup
    file_assets.copy_from_source_to_ets_input

    # SubmitJob
    ets = ETJob.new local_job: job
    ets.submit
    read_resp = ets.poll(timeout: 2.hours)

    if read_resp.job.status =~ /progress/i
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
  
  # AWSTranscodeJob.clear_all_s3_transcode_objs

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
  
  
  def self.transcode_buckets
    {
      in: ENV['transcode_in_bucket'],
      out: ENV['transcode_out_bucket']
    }
  end
  
end

