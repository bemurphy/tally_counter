# TallyCounter [![Code Climate](https://codeclimate.com/github/bemurphy/tally_counter.png)](https://codeclimate.com/github/bemurphy/tally_counter)

Tally web application hits with Rack & Redis sorted sets

## Installation

Add this line to your application's Gemfile:

    gem 'tally_counter'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tally_counter

## Usage

In your `config.ru` or middleware configuration:

```ruby
use TallyCounter::Middleware

# Options

# Provide a Redis instance
use TallyCounter::Middleware, :redis => $redis

# Use a 15 minute interval window
use TallyCounter::Middleware, :interval => 900

# Use a namespace prefix for keys
use TallyCounter::Middleware, :namespace => 'my_app_name'

# Timeout to Redis in 0.001 seconds
use TallyCounter::Middleware, :timeout => 0.001

# Inject a logger
use TallyCounter::Middleware, :logger => some_logger
```

It is adviseable you configure `TallyCounter::Middleware` before
your main application (so Rails, Sinatra, etc) but after your
static/cache layer.  You probably don't want to be tracking hits
against CSS, js, etc.

If you wish to avoid counting actions from further down the stack,
you may inject a response header:

```ruby
headers['X-Tally-Counter-Skip'] = 'true'
```

Note the mere presence of the header and not its value is enough
to cause a count skip.

## Redis connections

Its advisable to inject your own Redis connection as well as use
[hiredis-rb](https://github.com/pietern/hiredis-rb) for making connections
to Redis.  hiredis is faster than the redis-rb driver as it wraps the
C client.  Quickstart to get redis to connect with hiredis:

```ruby
require "redis"
require "redis/connection/hiredis"
require "tally_counter"
```

Redis connections you (or TallyCounter) create will now use the faster client.

## Keys and Scoring

The system uses Redis sorted sets for tracking application hits.
For each request, a key will be generated, and the score for the
remote request ip will be incremented by 1.

Keys are generated like 'tally_counter:1371283200' where the time
is the epoch seconds floor for the current window.  The floor for
a 5 minute interval at 12:38 would be 12:35, at 12:33 it's 12:30,
and so on.

Keys are generated using the `TallyCounter::KeyGenerate` class.
This can be used in client applications for generating keys for
Redis lookups.

```ruby
# Create a key generator for 5 minute windows with :foo namespace
key_generate = TallyCounter::KeyGenerate.new(300, :foo)
# Generate a key for the current time
key_generate.for(Time.now)
# Generate a key from 10 minutes ago
key_generate.for(Time.now, 2)
```

It is recommended to use a scheduled process to inspect tally_counter
sets past a certain age (say, 3 days) and prune them to keep your
data set small and clean.

Finding totals for a range of time can be accomplished via a Redis
zunionstore on a range of keys.  For example, if you have a a 5
minute interval and want to see the last 15 minutes, simple grab
the current window and the 2 previous and union them with equally
weighted scoring.  See `TallyCounter::Window#floor` for generating
window times and offsets.

## Reporting

In the interest of giving this gem a single responsibility, reporting
can be offloaded to other systems.  It should be easy to deploy
a separate admin application connected to the same server, and use
the `TallyCounter::Window` class for generating keys.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
