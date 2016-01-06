class TranscodeJob < ActiveRecord::Base
  @queue = :default

  include AASM

  validates :name, :video_asset_id, :asset_file_name, :asset_content_type, :asset_file_size, presence: true
  serialize :params
  belongs_to :video_asset

  aasm do
    state :created, :initial => true
    state :running
    state :completed
    state :canceled
    state :failed

    event :run, :before => :log_event do
      transitions :from => [:created, :completed, :failed, :canceled], :to => :running
    end

    event :complete, :before => :log_event do
      transitions :from => [:running, :completed, :created], :to => :completed
    end

    event :fail, :before => :log_event do
      transitions :from => [:running, :created, :completed], :to => :failed
    end

    event :cancel, :before => :log_event do
      transitions :from => [:created, :running, :fail], :to => :canceled
    end
  end

  has_many :events, :class_name => 'TranscodeEvent', :dependent => :destroy

  def log_event
    puts "entered #{aasm.current_event}" if Rails.env.development?
    self.events.build data: "entered #{aasm.current_event}"
  end
  
  def log_string msg
    puts msg if Rails.env.development?
    self.events.build data: msg
  end

  def trigger
    Resque.enqueue(TranscodeJob, self.id)
  end

  def self.perform job_id
    begin
      job = TranscodeJob.find(job_id)

      job.run!
      if !job.video_asset
        puts "creating new va with #{job.build_params}"
        job.video_asset = VideoAsset.new(job.build_params)
        job.video_asset.save!
        job.save!
      end

      puts "processing started for #{job.id} #{job.video_asset.asset_file_name}"
      rv = nil
      job.log = output = Kernel.capture(:stderr) do
        rv = job.video_asset.asset.reprocess!
      end
      puts "processing complete for #{job.id} #{job.video_asset.asset_file_name}"
      rv ? job.complete! : job.fail!
      job.save!
      # if done, call out to webhook with update
      job.trigger_callback
    rescue
      job = TranscodeJob.find(job_id)
      job.params = { error: $!.to_s, backtrace: $!.backtrace }
      job.fail!
      job.save(validate: true)
      puts "Exception processing #{self.class} #{job.id}! #{$!} #{$!.backtrace.join("\n")}"
    end
  end

  def trigger_callback
    return unless callback_url.present?
    conn = Faraday.new do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end

    response = conn.post callback_url, {
      video_asset_secret: video_asset_secret,
      status: aasm_state_to_status,
      response: log
    }
  end

  def aasm_state_to_status
    case aasm_state
    when 'created'
      101
    when 'running'
      102
    when 'completed'
      201
    when 'canceled'
      500
    when 'failed'
      500
    end
  end

  def build_params
    [:asset_file_name, :asset_content_type, :asset_file_size].inject({}) do |m, key|
      m[key] = self.send(key)
      m
    end.merge({original_id: self.video_asset_id})
  end

end
