ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'debugger'
require 'factory_girl_rails'

class MiniTest::Unit::TestCase
  include FactoryGirl::Syntax::Methods
end

class ActiveSupport::TestCase
  # Add more helper methods to be used by all tests here...
  def token_header(token)
    ActionController::HttpAuthentication::Token.encode_credentials(token)
  end
end
