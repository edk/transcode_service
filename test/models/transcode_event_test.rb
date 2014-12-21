require 'test_helper'

class TranscodeEventTest < ActiveSupport::TestCase
  test "ensure transcode job state transition creates an event" do
    job = FactoryGirl.create(:transcode_job)
    job.run
    job.save!
    assert_equal job.events.size, 1

    # if you don't save the object, the associated objects don't get saved either
    job.complete!
    job.reload
    assert_equal job.events.size, 1

    job.complete!
    job.save!
    assert_equal job.events.size, 2
  end
end
