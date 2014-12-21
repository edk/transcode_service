class TranscodeJob < ActiveRecord::Base
  include AASM

  aasm do
    state :created, :initial => true
    state :running
    state :completed
    state :canceled
    state :failed

    event :run, :after => :log_event do
      transitions :from => :created, :to => :running
    end

    event :complete, :after => :log_event do
      transitions :from => [:running, :completed], :to => :completed
    end

    event :fail, :after => :log_event do
      transitions :from => :running, :to => :failed
    end

    event :cancel, :after => :log_event do
      transitions :from => [:created, :running], :to => :canceled
    end
  end

  has_many :events, :class_name => 'TranscodeEvent', :dependent => :destroy

  def log_event
    self.events.build data: "entered #{aasm.current_event}"
  end

end
