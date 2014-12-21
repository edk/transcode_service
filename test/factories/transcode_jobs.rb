
FactoryGirl.define do
  factory :transcode_job do
    aasm_state "created"
    params {}
  end
end
