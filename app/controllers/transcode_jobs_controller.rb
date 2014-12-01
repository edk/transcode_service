class TranscodeJobsController < ApplicationController
  # GET /transcode_jobs
  # GET /transcode_jobs.json
  def index
    @transcode_jobs = TranscodeJob.all

    render json: @transcode_jobs
  end

  # GET /transcode_jobs/1
  # GET /transcode_jobs/1.json
  def show
    @transcode_job = TranscodeJob.find(params[:id])

    render json: @transcode_job
  end

  # POST /transcode_jobs
  # POST /transcode_jobs.json
  def create
    @transcode_job = TranscodeJob.new(transcode_job_params)

    if @transcode_job.save
      render json: @transcode_job, status: :created, location: @transcode_job
    else
      render json: @transcode_job.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /transcode_jobs/1
  # PATCH/PUT /transcode_jobs/1.json
  def update
    @transcode_job = TranscodeJob.find(params[:id])

    if @transcode_job.update(transcode_job_params)
      head :no_content
    else
      render json: @transcode_job.errors, status: :unprocessable_entity
    end
  end

  # DELETE /transcode_jobs/1
  # DELETE /transcode_jobs/1.json
  def destroy
    @transcode_job = TranscodeJob.find(params[:id])
    @transcode_job.destroy

    head :no_content
  end

  private
    
  def transcode_job_params
    params.require(:transcode_job).permit(:status, :params)
  end
end
