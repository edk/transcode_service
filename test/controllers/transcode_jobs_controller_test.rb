require 'test_helper'

class TranscodeJobsControllerTest < ActionController::TestCase
  setup do
    @transcode_job = transcode_jobs(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:transcode_jobs)
  end

  test "should create transcode_job" do
    assert_difference('TranscodeJob.count') do
      post :create, transcode_job: { params: @transcode_job.params, status: @transcode_job.status }
    end

    assert_response 201
  end

  test "should show transcode_job" do
    get :show, id: @transcode_job
    assert_response :success
  end

  test "should update transcode_job" do
    put :update, id: @transcode_job, transcode_job: { params: @transcode_job.params, status: @transcode_job.status }
    assert_response 204
  end

  test "should destroy transcode_job" do
    assert_difference('TranscodeJob.count', -1) do
      delete :destroy, id: @transcode_job
    end

    assert_response 204
  end
end
