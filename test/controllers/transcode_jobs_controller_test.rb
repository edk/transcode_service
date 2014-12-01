require 'test_helper'

class TranscodeJobsControllerTest < ActionController::TestCase
  setup do
    @transcode_job = FactoryGirl.create(:transcode_job)
    @api_token     = FactoryGirl.create(:api_token)
    @encoded = token_header(@api_token.token)
    request.headers['Authorization'] = @encoded  # set to nil to test non-auth access
    request.headers['Accept'] = 'application/json'
  end

  test 'invalid auth token' do
    request.headers['Authorization'] = nil
    get :index, {}
    
    assert_response 401
    assert_equal response.content_type, Mime::JSON
  end

  test "should get index" do
    # or for fun manually:
    # curl -IH 'Authorization: Token token=5189dd68172f54c193eb94ffa52ad125' 127.0.0.1:3001/transcode_jobs/
    get :index, {}
    assert_response :success
    assert_not_nil assigns(:transcode_jobs)
    assert_equal response.content_type, Mime::JSON
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
