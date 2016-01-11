
# Elastic Transcoder Job
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


