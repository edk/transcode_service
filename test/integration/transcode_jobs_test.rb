require 'test_helper'

class TranscodeJobsTest < ActionDispatch::IntegrationTest
  setup do
    @transcode_job = FactoryGirl.create(:transcode_job)
    @api_token     = FactoryGirl.create(:api_token)
    @encoded = token_header(@api_token.token)
    @default_header = { 'Authorization' => @encoded, 'Accept' => Mime::JSON }
    #@request.headers['Authorization'] = @encoded  # set to nil to test non-auth access
    #@request.headers['Accept'] = 'application/json'
  end

  test 'invalid auth token' do
    get '/api/transcode_jobs', {}
    
    assert_response 401
    #assert_equal response.content_type, Mime::JSON
  end

  test 'invalid auth token doing dangerous things' do
    delete '/api/transcode_jobs/1'
    
    assert_response 401
    #assert_equal response.content_type, Mime::JSON
  end

  test "should get index" do
    # or for fun manually:
    # curl -IH 'Authorization: Token token=5189dd68172f54c193eb94ffa52ad125' 127.0.0.1:3001/transcode_jobs/
    get '/api/transcode_jobs', {}, @default_header
    assert_response :success
    assert_not_nil assigns(:transcode_jobs)
    assert_equal response.content_type, Mime::JSON
  end

  test "should create transcode_job" do
    assert_difference('TranscodeJob.count') do
      post '/api/transcode_jobs', {transcode_job: { params: @transcode_job.params, aasm_state: @transcode_job.aasm_state }}, @default_header
    end

    assert_response 201
  end

  test "should show transcode_job" do
    get "/api/transcode_jobs/#{@transcode_job.id}", {}, @default_header
    assert_response :success
  end

  test "should update transcode_job" do
    put "/api/transcode_jobs/#{@transcode_job.id}/", {transcode_job: { params: @transcode_job.params, aasm_state: @transcode_job.aasm_state }}, @default_header
    assert_response 204
  end

  test "should destroy transcode_job" do
    assert_difference('TranscodeJob.count', -1) do
      delete "/api/transcode_jobs/#{@transcode_job.id}", {}, @default_header
    end

    assert_response 204
  end
end


