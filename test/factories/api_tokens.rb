FactoryGirl.define do
  factory :api_token do
    user "admin"
    sequence :token do |s|
      "xxxxx-#{s}"
    end
  end
end
