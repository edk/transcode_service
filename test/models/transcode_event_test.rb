require 'test_helper'

class TranscodeEventTest < ActiveSupport::TestCase
  test "ensure transcode job state transition creates an event" do
    job = FactoryGirl.create(:transcode_job)
    job.run
    job.save!
    job.reload
    assert_equal 1, job.events.size

    # if you don't save the object, the associated objects don't get saved either
    job.complete!
    assert_equal 2, job.events.size

    job.complete!
    job.save!
    assert_equal 3, job.events.size
  end
end
