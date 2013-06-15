require "test/unit"
require "rack/test"
require File.expand_path('../../lib/tally_counter', __FILE__)

class TallyCounterTestCase < Test::Unit::TestCase
  def self.test(name, &block)
    name = name.gsub(/\W+/, ' ').strip
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    define_method(test_name, &block)
  end
end

class TallyCounterWindowTest < TallyCounterTestCase
  test "initializing with interval seconds" do
    window = TallyCounter::Window.new(60)
    assert_equal 60, window.interval
  end

  test "calculating the floor for a given time" do
    window   = TallyCounter::Window.new(300)
    expected = Time.parse('2013-06-15 00:25:00 -0700')
    now      = Time.parse('2013-06-15 00:28:36 -0700')
    assert_equal expected, window.floor(now)
  end

  test "calculating the floor for a given time with an offset" do
    window   = TallyCounter::Window.new(300)

    expected = Time.parse('2013-06-15 00:20:00 -0700')
    now      = Time.parse('2013-06-15 00:28:36 -0700')
    assert_equal expected, window.floor(now, 1)

    expected = Time.parse('2013-06-15 00:15:00 -0700')
    now      = Time.parse('2013-06-15 00:28:36 -0700')
    assert_equal expected, window.floor(now, 2)
  end
end

class TallyCounterKeyGenerateTest < TallyCounterTestCase
  def time
    Time.parse('2013-06-15 08:52:41 -0700')
  end

  test "generating a key without a namespace" do
    key_generate = TallyCounter::KeyGenerate.new(300)
    assert_equal 'tally_counter:1371311400', key_generate.for(time)
  end

  test "generating a key with a namespace" do
    key_generate = TallyCounter::KeyGenerate.new(300, :some_app)
    assert_equal 'some_app:tally_counter:1371311400', key_generate.for(time)
  end

  test "generating a key for a given window offset" do
    key_generate = TallyCounter::KeyGenerate.new(300, :some_app)
    assert_equal 'some_app:tally_counter:1371311400', key_generate.for(time, 0)
    assert_equal 'some_app:tally_counter:1371311100', key_generate.for(time, 1)
    assert_equal 'some_app:tally_counter:1371310800', key_generate.for(time, 2)
  end
end

class TallyCounterMiddlewareTest < TallyCounterTestCase
  include Rack::Test::Methods

  def redis
    @redis ||= Redis.new :db => 14
  end

  def app_options
    options = @app_options || {}
    {:redis => redis}.merge(options)
  end

  def app_options=(options)
    @app_options = options
  end

  def app
    builder = Rack::Builder.new
    builder.use TallyCounter::Middleware, app_options
    builder.run lambda { |env|
      req = Rack::Request.new(env)
      headers = {}

      if req.params['skip']
        headers['X-Tally-Counter-Skip'] = 'true'
      end

      [200, headers, ['ok']]
    }
    builder.to_app
  end

  test "incrementing the count for the remote address" do
    window = TallyCounter::Window.new(300)
    key = "tally_counter:#{window.floor(Time.now).to_i}"
    redis.del key, "127.0.0.1"
    get "/"
    assert_equal 1.0, redis.zscore(key, "127.0.0.1")
    get "/"
    assert_equal 2.0, redis.zscore(key, "127.0.0.1")
  end

  test "providing a namespace for the keys" do
    window = TallyCounter::Window.new(300)
    key = "foobar:tally_counter:#{window.floor(Time.now).to_i}"
    redis.del key
    self.app_options = {:namespace => 'foobar'}
    get "/"
    assert_equal 1.0, redis.zscore(key, "127.0.0.1")
  end

  test "skipping incrementing when X-Skip-Tally-Counter header is present" do
    window = TallyCounter::Window.new(300)
    key = "tally_counter:#{window.floor(Time.now).to_i}"
    redis.del key, "127.0.0.1"
    get "/?skip=true"
    assert_nil redis.zscore(key, "127.0.0.1")
  end

  test "passing through to the next app in middleware chain" do
    get "/"
    assert_match "ok", last_response.body
  end

  test "tolerating a timeout error" do
    fake_redis = Object.new
    def fake_redis.zincrby(*)
      sleep 5
    end
    self.app_options = {:redis => fake_redis}

    assert_nothing_raised { get "/" }
    assert_match "ok", last_response.body
  end

  test "tolerating a redis error" do
    fake_redis = Object.new
    def fake_redis.zincrby(*)
      raise Redis::ConnectionError
    end
    self.app_options = {:redis => fake_redis}

    assert_nothing_raised { get "/" }
    assert_match "ok", last_response.body
  end
end
