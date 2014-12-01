require 'test_helper'

class ApiTokenTest < ActiveSupport::TestCase
  test "Api tokens should be unique, enforced by the db" do
    token1 = FactoryGirl.create :api_token
    assert_raises ActiveRecord::RecordNotUnique do 
      token2 = FactoryGirl.create :api_token, token: token1.token
    end
  end

  test "ApiToken should generate a unique token through the factory method" do
    assert_difference 'ApiToken.count', 2 do
      token = ApiToken.create_api_token token:'aaa'
      token.save!

      token = ApiToken.create_api_token token:'aaa'
      token.save!
    end
  end

end
