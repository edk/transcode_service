class TranscodeEvent < ActiveRecord::Base
  belongs_to :transcode_job
end
