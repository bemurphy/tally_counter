require "tally_counter/version"
require "logger"
require "redis"
require "timeout"

module TallyCounter
  class Window

    attr_reader :interval

    # @param [Integer] seconds of granularity for the window
    def initialize(interval)
      @interval = interval
    end

    # Returns the floor time for a given window.  For example,
    # if the interval is 5 minutes and it is 12:38, the floor
    # would be 12:35.  If offset is 1, the floor would be 12:30
    #
    # @param [Time] a time instance, commonly Time.now
    # @param [Integer] an offset of windows step back
    def floor(time, offset = 0)
      epoch_time = time.to_i - interval * offset
      Time.at((epoch_time / interval) * interval)
    end

  end

  class KeyGenerate
    NAME = 'tally_counter'.freeze

    # @param [Integer] a seconds interval for Window use
    # @param [String] optional app namespace
    def initialize(interval, namespace = nil)
      @window    = TallyCounter::Window.new(interval)
      @namespace = namespace
    end

    # @param [Time] time for a key, often Time.now
    # @param [Integer] offset for window to step back
    def for(time, offset = 0)
      timestamp = @window.floor(time, offset).to_i
      [@namespace, NAME, timestamp].compact.join(':')
    end
  end

  class Middleware

    # @param app - a rack compliant app
    # @param options
    # @option options :interval time in seconds for window granularity
    # @option options :logger a logger instance
    # @option options :namespace optional redis key namespace, like 'app_name'
    # @option options :redis a redis instance
    # @option options :timeout seconds before timing out a redis command
    def initialize(app, options = {})
      @app       = app
      @interval  = options[:interval] || 300
      @logger    = options[:logger] || Logger.new($stdout)
      @namespace = options[:namespace]
      @redis     = options[:redis] || Redis.current
      @timeout   = options[:timeout] || 0.007
    end

    def call(env)
      tuple = @app.call(env)

      unless tuple[1].delete('X-Tally-Counter-Skip')
        req = Rack::Request.new(env)
        track_ip(req.ip)
      end

      tuple
    end

    private

    def track_ip(ip)
      begin
        Timeout::timeout(@timeout) do
          @redis.zincrby current_key, 1, ip.to_s
        end
      rescue Timeout::Error, Redis::BaseError => e
        @logger.error "#{self.class.name} - #{e.message}"
      end
    end

    def current_key
      key_generate.for(Time.now)
    end

    def key_generate
      @key_generate ||= TallyCounter::KeyGenerate.new(@interval, @namespace)
    end

  end
end
