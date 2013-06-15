# TallyCounter

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

## Keys and Scoring

The system uses Redis sorted sets for tracking application hits.
For each request, a key will be counted, and the score for the
remote request ip will be incremented by 1.

Keys are generated like 'tally_counter:1371283200' where the time
is the epoch seconds floor for the current window.  The floor for
a 5 minute interval at 12:38 would be 12:35, at 12:33 its 12:30,
and so on.

It is recommended to use a scheduled process to inspect tally_counter
sets past a certain age (say, 3 days) and prune them to keep your
data set small and clean.

Finding totals for a range of time can be accomplished via a Redis
zunionstore on a range of keys.  For example, if you have a a 5
minute interval and want to see the last 15 minutes, simple grab
the current window and the 2 previous and union them with equally
weighted scoring.  See `TallyCounter::Window#floow` for generating
window times and offsets.

## Reporting

In the interest of giving this gem a single responsibility, reporting
can be offloaded to other systems.  It should be easy to deploy
a separate admin application conneted to the same server, and use
the `TallyCounter::Window` class for generating keys.

## Todo

Extract key generation to a utility for use by middleware and client
apps.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
