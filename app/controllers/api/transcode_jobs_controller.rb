class Api::TranscodeJobsController < ApplicationController

  rescue_from StandardError, :with => :json_error_render_method
  before_action :set_default_response_format

  skip_before_filter :authenticate, :only => [:ping]

  # GET /api/transcode_jobs
  # GET /api/transcode_jobs.json
  def index
    @transcode_jobs = TranscodeJob.all

    render json: @transcode_jobs
  end

  # GET /api/transcode_jobs/1
  # GET /api/transcode_jobs/1.json
  def show
    @video_asset = VideoAsset.where(original_id: params[:id]).first
    raise ActiveRecord::RecordNotFound unless @video_asset
    @transcode_job = @video_asset.transcode_job

    render json: @transcode_job
  end

  # POST /api/transcode_jobs
  # POST /api/transcode_jobs.json
  def create
    @transcode_job = AWSTranscodeJob.new(transcode_job_params)

    if rv = @transcode_job.save
      @transcode_job.trigger
    end

    if rv
      render json: @transcode_job.as_json.merge({ location: [:api, @transcode_job] }), status: 202
    else
      render json: @transcode_job.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/transcode_jobs/1
  # PATCH/PUT /api/transcode_jobs/1.json
  def update
    @transcode_job = TranscodeJob.find(params[:id])

    if @transcode_job.update(transcode_job_params)
      head :no_content
    else
      render json: @transcode_job.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/transcode_jobs/1
  # DELETE /api/transcode_jobs/1.json
  def destroy
    @transcode_job = TranscodeJob.find(params[:id])
    @transcode_job.destroy

    head :no_content
  end

  def ping
    render :text => Time.now.iso8601.to_s
  end

  protected

  def set_default_response_format
    request.format = :json
  end

  def json_error_render_method error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  private
  
  def transcode_job_params
    params.permit(:name, :video_asset_id, :params, :asset_file_name,
                  :asset_content_type, :asset_file_size,
                  :video_asset_secret, :callback_url)
  end
end
