class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods # for authenticate_or_request_with_http_token
  include ActionController::HttpAuthentication::Token
  include ActionController::MimeResponds

  before_filter :authenticate

  protected
  
  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    authenticate_with_http_token do |token, options|
      ApiToken.find_by token: token
    end
  end

  def render_unauthorized
    self.headers['WWW-Authenticate'] = 'Token realm="Application"'

    respond_to do |format|
      format.json { render json: 'Bad Credentials', status: 401}
      format.html { render html: 'Bad Credentials', status: 401}
    end

  end

end
