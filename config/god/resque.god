
God.watch do |w|
  w.name = 'resque'
  w.interval = 30.seconds
  w.env = { 'RAILS_ENV' => 'production', 'QUEUE' => '*' }
  w.uid = 'deployuser'
  w.gid = 'deployuser'
  w.dir = File.expand_path(File.join(File.dirname(__FILE__),'..'))
  w.start = "bundle exec rake jobs:work"
  w.start_grace = 10.seconds
  w.log = File.expand_path(File.join(File.dirname(__FILE__), '..','log','resque-worker.log'))

  # determine the state on startup
  w.transition(:init, { true => :up, false => :start }) do |on|
    on.condition(:process_running) do |c|
      c.running = true
    end
  end

  # determine when process has finished starting
  w.transition([:start, :restart], :up) do |on|
    on.condition(:process_running) do |c|
      c.running = true
      c.interval = 5.seconds
    end

    # failsafe
    on.condition(:tries) do |c|
      c.times = 5
      c.transition = :start
      c.interval = 5.seconds
    end
  end

  # start if process is not running
  w.transition(:up, :start) do |on|
    on.condition(:process_running) do |c|
      c.running = false
    end
  end
end


