
# Elastic Transcoder Job
class ETJob

  def initialize options
    @local_job = options[:local_job]
  end

  def submit
    input_key  = @local_job.video_asset.asset.path
    out_key = input_key.split('.')[0..-2].join('.')

    @job_response = submit_job_to_et input_key, out_key
    @local_job.log_string "Submitted job ID: #{@job_response.job.id} to AWS Elastic Transcoder"
    [elastic_transcoder, @job_response]
  end

  def submit_job_to_et input_key, out_key
    elastic_transcoder
    resp = elastic_transcoder.create_job transcode_job_options
    @local_job.update_attribute(:job_id, resp.job.id) # save the ETS job id to database
    resp
  end

  def elastic_transcoder
    @elastic_transcoder ||= Aws::ElasticTranscoder::Client.new(transcode_options)
  end

  def transcode_job_options
    {
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
  end

  def poll(options = {})
    timeout = options[:timeout] || 2.hours
    delay   = options[:delay] || 60

    begin
      elastic_transcoder.wait_until(:job_complete, id: @local_job.job_id ) { |w|
        w.max_attempts = timout / delay # two hours based on a 60 sec delay
        w.delay = delay
      }
    rescue Waiters::Errors::WaiterFailed => e
      rv = check_status

      case rv.job.status
      when /progressing/i
        @local_job.poll_timeout!
      when /completed/i
        @local_job.complete!
      when /warning/i
        @local_job.poll_timeout!
      when /error/i
        @local_job.fail!
      else
        @local_job.log_string "Unknown ETS Job status: #{rv.job.status} for job id: #{rv.job.id}"
        @local_job.fail!
      end

      return e
    end
    
    check_status
  end

  def check_status
    read_resp = elastic_transcoder.read_job(id: @local_job.job_id)
    @local_job.log_string "#{Time.now.iso8601} polling job ID #{read_resp.job.id}, status => #{read_resp.job.status}"
    read_resp
  end

  attr_reader :job_response

  protected

  def transcode_options
    AWSTranscodeJob.transcode_options
  end

  def pipeline_id
    ENV['pipeline_id']
  end

  def presets
    { web_preset_id: ENV['web_preset_id'], webm_preset_id: ENV['webm_preset_id'] }
  end

end


